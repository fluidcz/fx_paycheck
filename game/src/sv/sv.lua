ESX = exports["es_extended"]:getSharedObject()

if GetCurrentResourceName() ~= 'fx_paycheck' then
    CreateThread(function()
        while true do
            print('^1[FX_PAYCHECK] This resource must be named "fx_paycheck" to remain functioning!^7')
            print('^1Current name: "' .. GetCurrentResourceName() .. '" - Please rename it to "fx_paycheck".^7')
            Wait(60000)
        end
    end)
    return
end

local version = '1.2'

CreateThread(function()
    PerformHttpRequest('https://api.github.com/repos/fusefivem/fx_paycheck/releases/latest', function(err, text, headers)
        if err ~= 200 then
            print('^1[fx_paycheck] Could not check for new version.^7')
            return
        end

        local data = json.decode(text)
        if data.tag_name == version then
            print('^6[fx_paycheck] You are running the latest version.^7')
        else
            print('^1-------------------------------------------------')
            print('^6New Version Released for fx_paycheck\n')
            print('^7Your Version: ^1'..version)
            print('^7Newest Version: ^6'..data.tag_name..'\n')
            print('^6Changelog:^7')
            print(data.body..'\n')
            print('Get the updated version: https://github.com/fusefivem/fx_paycheck/archive/refs/tags/'..data.tag_name..'.zip')
            print('^1-------------------------------------------------^7')
        end
    end, 'GET')
end)

CreateThread(function()
    while true do
        local interval = fx.paycheckinterval
        if interval < 1 then interval = 15 end
        Wait(interval * 60000)

        for _, playerid in ipairs(GetPlayers()) do
            local xplayer = ESX.GetPlayerFromId(playerid)

            if xplayer then
                local playerjob = xplayer.getJob().name
                local playergrade = xplayer.getJob().grade
                local basesalary = fx.defaultpay

                if fx.usedatabase then
                    if MySQL then
                        local query = 'SELECT salary FROM job_grades WHERE job_name = ? AND grade = ?'
                        local salary = MySQL.scalar.await(query, {playerjob, playergrade})
                        if salary then
                            basesalary = salary
                        end
                    end
                elseif fx.jobs[playerjob] then
                    local jobconfig = fx.jobs[playerjob]
                    
                    if type(jobconfig) == 'table' then
                        basesalary = jobconfig[playergrade] or jobconfig[0] or fx.defaultpay
                    else
                        basesalary = jobconfig
                    end
                end

                local taxamount = 0
                local finalamount = basesalary

                -- tax
                if fx.enabletaxes then
                    taxamount = (finalamount / 100) * fx.taxrate
                    finalamount = finalamount - taxamount
                end

                finalamount = math.floor(finalamount)
                taxamount = math.floor(taxamount)

                if finalamount > 0 then
                    if fx.paymentmethod == 'bank' then
                        xplayer.addAccountMoney('bank', finalamount)
                    elseif fx.paymentmethod == 'cash' then
                        xplayer.addMoney(finalamount)
                    elseif fx.paymentmethod == 'item' then
                        xplayer.addInventoryItem(fx.itemname, finalamount)
                    end
                end

                TriggerClientEvent('fx:paycheck:notify', playerid, basesalary, taxamount, fx.taxrate, finalamount, fx.paymentmethod, fx.itemname)
            end
        end
    end
end)
