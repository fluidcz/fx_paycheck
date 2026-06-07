local ESX = exports["es_extended"]:getSharedObject()

CreateThread(function()
    local version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0)
    PerformHttpRequest('https://api.github.com/repos/fluidcz/fx_paycheck/releases/latest', function(err, text, headers)
        if err ~= 200 then
            print('^1[fx_paycheck] Could not check for new version.^7')
            return
        end

        local data = json.decode(text)
        if data.tag_name == version then
            print('^6[fx_paycheck] You are running the latest version.^7')
        else
            print('^1-------------------------------------------------')
            print('^4New Version Released for fx_paycheck\n')
            print('^7Your Version: ^1' .. version)
            print('^7Newest Version: ^4' .. data.tag_name .. '\n')
            print('^4Changelog:^7')
            print(data.body .. '\n')
            print('Get the updated version: https://github.com/fluidcz/fx_paycheck/archive/refs/tags/' .. data.tag_name .. '.zip')
            print('^1-------------------------------------------------^7')
        end
    end, 'GET')
end)

local lastpos = {}
local lastmove = {}

AddEventHandler('playerDropped', function()
    local src = source
    lastpos[src] = nil
    lastmove[src] = nil
end)

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS fx_paychecks (
            id INT AUTO_INCREMENT PRIMARY KEY,
            identifier VARCHAR(60) NOT NULL,
            job VARCHAR(50) NOT NULL,
            amount INT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
    pcall(function()
        MySQL.query.await("ALTER TABLE fx_paychecks ADD COLUMN job VARCHAR(50) NOT NULL DEFAULT 'unemployed'")
    end)
    pcall(function()
        MySQL.query.await("ALTER TABLE fx_paychecks ADD COLUMN id INT AUTO_INCREMENT PRIMARY KEY")
    end)
    pcall(function()
        MySQL.query.await("ALTER TABLE fx_paychecks ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP")
    end)
end)

local function getphoneresource()
    if GetResourceState('lb-phone') == 'started' then
        return 'lb-phone'
    elseif GetResourceState('lb_phone') == 'started' then
        return 'lb_phone'
    end
    return nil
end

local function getnotifysystem()
    if fd.notifysystem == 'lb-phone' then
        local phoneres = getphoneresource()
        if phoneres then
            return phoneres
        else
            return 'ox_lib'
        end
    end
    return fd.notifysystem
end

-- e1
local function deductfromsociety(jobname, amount)
    local p = promise.new()
    local resolved = false

    TriggerEvent('esx_addonaccount:getSharedAccount', 'society_' .. jobname, function(account)
        if resolved then return end
        resolved = true
        if account then
            if account.money >= amount then
                account.removeMoney(amount)
                p:resolve(true)
            else
                p:resolve(false)
            end
        else
            p:resolve(false)
        end
    end)

    SetTimeout(2000, function()
        if not resolved then
            resolved = true
            p:resolve(false)
        end
    end)

    return Citizen.Await(p)
end

local function addtosociety(jobname, amount)
    TriggerEvent('esx_addonaccount:getSharedAccount', 'society_' .. jobname, function(account)
        if account then
            account.addMoney(amount)
        end
    end)
end

local paycheckinterval = fd.paycheckcron
if not paycheckinterval or paycheckinterval < 1 then paycheckinterval = 30 end
local paycheckcronpattern = '*/' .. paycheckinterval .. ' * * * *'
-- e2
lib.cron.new(paycheckcronpattern, function()
    local players = GetPlayers()
    
    for _, playerid in ipairs(players) do
        CreateThread(function()
            local xply = ESX.GetPlayerFromId(playerid)
            if not xply then return end

            local identifier = xply.getIdentifier()
            local jobname = xply.getJob().name
            local jobgrade = xply.getJob().grade
            local joblabel = xply.getJob().label

            if fd.antiafk then
                local plyped = GetPlayerPed(playerid)
                if plyped and plyped ~= 0 then
                    local currpos = GetEntityCoords(plyped)
                    if currpos and #(currpos) > 1.0 then
                        local now = os.time()
                        if not lastpos[playerid] then
                            lastpos[playerid] = currpos
                            lastmove[playerid] = now
                        else
                            local dist = #(currpos - lastpos[playerid])
                            if dist >= fd.afkdistance then
                                lastpos[playerid] = currpos
                                lastmove[playerid] = now
                            else
                                local duration = now - lastmove[playerid]
                                local maxafktime = (fd.afktime or 20) * 60
                                if duration >= maxafktime then
                                    TriggerClientEvent('fd:paycheck:notifySimple', playerid, Locales[fd.locale]['afk_skipped'], 'error')
                                    return
                                end
                            end
                        end
                    end
                end
            end

            local basesalary = 0
            local customtax = nil
            local customlabel = nil
            local found = false

            if fd.usedatabase then
                local query = 'SELECT salary FROM job_grades WHERE job_name = ? AND grade = ?'
                local salary = MySQL.scalar.await(query, {jobname, jobgrade})
                if salary then
                    basesalary = salary
                    found = true
                end
            end

            local lowerjob = string.lower(jobname)
            if fd.jobs[lowerjob] then
                local jobconfig = fd.jobs[lowerjob]
                if type(jobconfig) == 'table' then
                    local numericgrade = tonumber(jobgrade)
                    local gradeconfig = (numericgrade and jobconfig[numericgrade]) or jobconfig[jobgrade] or jobconfig[0]
                    if gradeconfig then
                        if type(gradeconfig) == 'table' then
                            customtax = gradeconfig.tax
                            customlabel = gradeconfig.label
                            if not found then
                                basesalary = gradeconfig.pay or fd.defaultpay
                                found = true
                            end
                        else
                            if not found then
                                basesalary = gradeconfig
                                found = true
                            end
                        end
                    end
                else
                    if not found then
                        basesalary = jobconfig
                        found = true
                    end
                end
            end

            if not found then
                basesalary = fd.defaultpay
            end



            if basesalary <= 0 then return end

            local taxamount = 0
            local finalamount = basesalary
            local taxrate = customtax or fd.basetax

            if fd.enabletaxes and taxrate and taxrate > 0 then
                taxamount = math.floor((finalamount / 100) * taxrate)
                finalamount = finalamount - taxamount
            end

            finalamount = math.floor(finalamount)
            taxamount = math.floor(taxamount)
            local shoulddeduct = fd.deductfromsociety
            if shoulddeduct and fd.societybypass then
                for _, bypassedjob in ipairs(fd.societybypass) do
                    if bypassedjob == jobname then
                        shoulddeduct = false
                        break
                    end
                end
            end

            if shoulddeduct then
                local deducted = deductfromsociety(jobname, finalamount)
                if not deducted then
                    TriggerClientEvent('fd:paycheck:notifySimple', playerid, Locales[fd.locale]['employer_broke'], 'error')
                    return
                end
            end

            if fd.paymentmethod == 'bank' then
                xply.addAccountMoney('bank', finalamount)
                
                local notifysys = getnotifysystem()
                if notifysys == 'lb-phone' or notifysys == 'lb_phone' then
                    local phonenum = exports[notifysys]:GetEquippedPhoneNumber(tonumber(playerid))
                    if phonenum then
                        local strings = Locales[fd.locale]
                        local title = string.format(strings['wallet_title'], customlabel or joblabel)
                        local content = string.format(strings['wallet_content'], finalamount)

                        exports[notifysys]:AddTransaction(phonenum, finalamount, title)
                        exports[notifysys]:SendNotification(playerid, {
                            app = 'Wallet',
                            title = title,
                            content = content
                        })
                    else
                        local paylabel = customlabel or (fd.locale == 'cs' and 'Výplata' or 'Paycheck')
                        local showtax = fd.enabletaxes and not fd.hidetax and taxamount > 0
                        local text = fd.locale == 'cs' and 
                            (showtax and string.format("Obdržel jsi %s ve výši $%s (Daň %s%%: -$%s).", paylabel, finalamount, taxrate, taxamount) or string.format("Obdržel jsi %s ve výši $%s.", paylabel, finalamount)) or
                            (showtax and string.format("You received your %s of $%s (Tax %s%%: -$%s).", paylabel, finalamount, taxrate, taxamount) or string.format("You received your %s of $%s.", paylabel, finalamount))
                        TriggerClientEvent('fd:paycheck:notifySimple', playerid, text, 'success', customlabel or (fd.locale == 'cs' and 'Výplata' or 'Paycheck'))
                    end
                else
                    local paylabel = customlabel or (fd.locale == 'cs' and 'Výplata' or 'Paycheck')
                    local showtax = fd.enabletaxes and not fd.hidetax and taxamount > 0
                    local text = fd.locale == 'cs' and 
                        (showtax and string.format("Obdržel jsi %s ve výši $%s (Daň %s%%: -$%s).", paylabel, finalamount, taxrate, taxamount) or string.format("Obdržel jsi %s ve výši $%s.", paylabel, finalamount)) or
                        (showtax and string.format("You received your %s of $%s (Tax %s%%: -$%s).", paylabel, finalamount, taxrate, taxamount) or string.format("You received your %s of $%s.", paylabel, finalamount))
                    TriggerClientEvent('fd:paycheck:notifySimple', playerid, text, 'success', customlabel or (fd.locale == 'cs' and 'Výplata' or 'Paycheck'))
                end

            elseif fd.paymentmethod == 'pickup' then
                local insertquery = 'INSERT INTO fx_paychecks (identifier, job, amount) VALUES (?, ?, ?)'
                MySQL.query.await(insertquery, {identifier, jobname, finalamount})
                local paylabel = customlabel or (fd.locale == 'cs' and 'Výplata' or 'Paycheck')
                local showtax = fd.enabletaxes and not fd.hidetax and taxamount > 0
                local text = fd.locale == 'cs' and 
                    (showtax and string.format("Tvoje %s ve výši $%s (Daň %s%%: -$%s) byla odeslána na místo vyzvednutí.", paylabel, finalamount, taxrate, taxamount) or string.format("Tvoje %s ve výši $%s byla odeslána na místo vyzvednutí.", paylabel, finalamount)) or
                    (showtax and string.format("Your %s of $%s (Tax %s%%: -$%s) was sent to the pickup location.", paylabel, finalamount, taxrate, taxamount) or string.format("Your %s of $%s was sent to the pickup location.", paylabel, finalamount))
                TriggerClientEvent('fd:paycheck:notifySimple', playerid, text, 'info', customlabel or (fd.locale == 'cs' and 'Výplata' or 'Paycheck'))
            end
        end)
    end
end)

local claiming = {}

-- e3
lib.callback.register('fd:paycheck:getDetails', function(src)
    local xply = ESX.GetPlayerFromId(src)
    if not xply then return nil end

    local identifier = xply.getIdentifier()
    local expirationdays = tonumber(fd.expirationtime) or 7
    local query = string.format([[
        SELECT 
            id,
            job,
            amount,
            created_at,
            TIMESTAMPDIFF(SECOND, NOW(), DATE_ADD(created_at, INTERVAL %d DAY)) AS remaining 
        FROM fx_paychecks 
        WHERE identifier = ?
        ORDER BY created_at ASC
    ]], expirationdays)
    
    local rows = MySQL.query.await(query, {identifier})
    
    if not rows or #rows == 0 then
        return {}
    end

    local paychecks = {}
    for _, row in ipairs(rows) do
        local remaining = tonumber(row.remaining) or 0
        local expires_in = nil

        if fd.enableexpiration and remaining > 0 then
            local days = math.floor(remaining / 86400)
            local hours = math.floor((remaining % 86400) / 3600)
            if days > 0 then
                expires_in = string.format('%sd %sh', days, hours)
            else
                local minutes = math.floor((remaining % 3600) / 60)
                expires_in = string.format('%sh %sm', hours, minutes)
            end
        elseif fd.enableexpiration then
            expires_in = 'Expired'
        end

        local customlabel = nil
        local lowerjob = string.lower(row.job)
        if fd.jobs[lowerjob] then
            local jobconfig = fd.jobs[lowerjob]
            if type(jobconfig) == 'table' then
                local gradeconfig = jobconfig[0]
                if gradeconfig then
                    if type(gradeconfig) == 'table' then
                        customlabel = gradeconfig.label
                    end
                end
            end
        end

        local paylabel = customlabel or (fd.locale == 'cs' and 'Výplata' or 'Paycheck')

        table.insert(paychecks, {
            id = row.id,
            label = paylabel,
            amount = row.amount,
            expires_in = expires_in
        })
    end

    return paychecks
end)

-- e4
RegisterNetEvent('fd:paycheck:claimPaycheck', function(paycheckid)
    local src = source
    local xply = ESX.GetPlayerFromId(src)
    if not xply then return end

    if not paycheckid then return end

    local playerped = GetPlayerPed(src)
    if not playerped or playerped == 0 then return end
    
    local coords = GetEntityCoords(playerped)
    local dist = #(coords - fd.pickuplocation)
    if dist > 10.0 then
        return
    end

    local identifier = xply.getIdentifier()
    local lockkey = identifier .. ':' .. tostring(paycheckid)
    if claiming[lockkey] then return end
    claiming[lockkey] = true

    local ok, err = pcall(function()
        if paycheckid == 'all' then
            local query = 'SELECT SUM(amount) AS total FROM fx_paychecks WHERE identifier = ?'
            local result = MySQL.single.await(query, {identifier})
            local amount = result and tonumber(result.total) or 0

            if amount > 0 then
                if fd.pickupaccount == 'cash' then
                    xply.addMoney(amount)
                else
                    xply.addAccountMoney('bank', amount)
                end

                local deletequery = 'DELETE FROM fx_paychecks WHERE identifier = ?'
                MySQL.query.await(deletequery, {identifier})

                local notifysys = getnotifysystem()
                if notifysys == 'lb-phone' or notifysys == 'lb_phone' then
                    if fd.pickupaccount == 'bank' then
                        local phonenum = exports[notifysys]:GetEquippedPhoneNumber(tonumber(src))
                        if phonenum then
                            local strings = Locales[fd.locale]
                            local title = string.format(strings['wallet_title'], 'Claim All')
                            local content = string.format(strings['wallet_content'], amount)

                            exports[notifysys]:AddTransaction(phonenum, amount, title)
                            exports[notifysys]:SendNotification(src, {
                                app = 'Wallet',
                                title = title,
                                content = content
                            })
                        end
                    end
                else
                    local msg = string.format(Locales[fd.locale]['paycheck_claimed'], amount)
                    TriggerClientEvent('fd:paycheck:notifySimple', src, msg, 'success')
                end
            else
                TriggerClientEvent('fd:paycheck:notifySimple', src, Locales[fd.locale]['no_pending'], 'error')
            end
        else
            local query = 'SELECT amount, job FROM fx_paychecks WHERE id = ? AND identifier = ?'
            local result = MySQL.single.await(query, {paycheckid, identifier})
            
            if result then
                local amount = tonumber(result.amount) or 0

                if amount > 0 then
                    if fd.pickupaccount == 'cash' then
                        xply.addMoney(amount)
                    else
                        xply.addAccountMoney('bank', amount)
                    end

                    local deletequery = 'DELETE FROM fx_paychecks WHERE id = ? AND identifier = ?'
                    MySQL.query.await(deletequery, {paycheckid, identifier})

                    local notifysys = getnotifysystem()
                    if notifysys == 'lb-phone' or notifysys == 'lb_phone' then
                        if fd.pickupaccount == 'bank' then
                            local phonenum = exports[notifysys]:GetEquippedPhoneNumber(tonumber(src))
                            if phonenum then
                                local strings = Locales[fd.locale]
                                local title = string.format(strings['wallet_title'], 'Received')
                                local content = string.format(strings['wallet_content'], amount)

                                exports[notifysys]:AddTransaction(phonenum, amount, title)
                                exports[notifysys]:SendNotification(src, {
                                    app = 'Wallet',
                                    title = title,
                                    content = content
                                })
                            end
                        end
                    else
                        local msg = string.format(Locales[fd.locale]['paycheck_claimed'], amount)
                        TriggerClientEvent('fd:paycheck:notifySimple', src, msg, 'success')
                    end
                else
                    TriggerClientEvent('fd:paycheck:notifySimple', src, Locales[fd.locale]['no_pending'], 'error')
                end
            else
                TriggerClientEvent('fd:paycheck:notifySimple', src, Locales[fd.locale]['no_pending'], 'error')
            end
        end
    end)

    claiming[lockkey] = nil
end)

-- daily
if fd.enableexpiration then
    lib.cron.new('0 0 * * *', function()
        local query = 'SELECT id, job, amount FROM fx_paychecks WHERE created_at < DATE_SUB(NOW(), INTERVAL ? DAY)'
        local expired = MySQL.query.await(query, {fd.expirationtime})
        if expired and #expired > 0 then
            for _, row in ipairs(expired) do
                if fd.expirationaction == 'return' then
                    addtosociety(row.job, row.amount)
                end
                MySQL.query.await('DELETE FROM fx_paychecks WHERE id = ?', {row.id})
            end
        end
    end)
end

