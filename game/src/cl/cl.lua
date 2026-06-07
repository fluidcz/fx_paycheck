local ESX = exports["es_extended"]:getSharedObject()
local spawnedped = nil

local function showmsg(msg, type, title)
    local strings = Locales[fd.locale]
    local notifytitle = title or strings['lib_title']
    if fd.notifysystem == 'ox_lib' then
        exports.ox_lib:notify({
            id = 'paychecknotif',
            title = notifytitle,
            description = msg,
            type = type or 'success',
            icon = 'money-bill-wave',
            duration = 7000
        })
    elseif fd.notifysystem == 'esx' then
        if title then
            ESX.ShowNotification(title .. '~n~' .. msg)
        else
            ESX.ShowNotification(msg)
        end
    elseif fd.notifysystem == 'lb-phone' then
        local phoneres = GetResourceState('lb-phone') == 'started' and 'lb-phone' or (GetResourceState('lb_phone') == 'started' and 'lb_phone' or nil)
        if phoneres then
            exports[phoneres]:SendNotification({
                app = 'Wallet',
                title = notifytitle or 'Paycheck',
                content = msg
            })
        else
            exports.ox_lib:notify({
                id = 'paychecknotif',
                title = notifytitle,
                description = msg,
                type = type or 'success',
                icon = 'money-bill-wave',
                duration = 7000
            })
        end
    else
        exports.ox_lib:notify({
            id = 'paychecknotif',
            title = notifytitle,
            description = msg,
            type = type or 'success',
            icon = 'money-bill-wave',
            duration = 7000
        })
    end
end

RegisterNetEvent('fd:paycheck:notify', function(basesalary, taxamount, taxrate, finalamount, paymentmethod, itemname, title)
    local strings = Locales[fd.locale]
    local finaltext = ''

    if paymentmethod == 'bank' then
        finaltext = string.format(strings['lib_received_bank'], finalamount)
    elseif paymentmethod == 'cash' then
        finaltext = string.format(strings['lib_received_cash'], finalamount)
    elseif paymentmethod == 'item' then
        finaltext = string.format(strings['lib_received_item'], finalamount)
    end
    
    local text = finaltext:gsub("^%s+", "")
    if fd.enabletaxes and not fd.hidetax and taxamount > 0 then
        text = text .. string.format(strings['lib_tax'], taxrate, taxamount)
    end

    showmsg(text, 'success', title)
end)

RegisterNetEvent('fd:paycheck:notifySimple', function(msg, type, title)
    showmsg(msg, type, title)
end)

local function showpaycheckcontext()
    local strings = Locales[fd.locale]
    local paychecks = lib.callback.await('fd:paycheck:getDetails') or {}

    local options = {}

    if #paychecks > 0 then
        local totalsum = 0
        for _, pc in ipairs(paychecks) do
            totalsum = totalsum + pc.amount
        end

        options[#options + 1] = {
            title = strings['claim_all'],
            description = string.format(strings['banker_collected'], totalsum),
            icon = 'money-bill-transfer',
            onSelect = function()
                TriggerServerEvent('fd:paycheck:claimPaycheck', 'all')
                SetTimeout(500, function()
                    showpaycheckcontext()
                end)
            end
        }

        for _, pc in ipairs(paychecks) do
            local desc = string.format(strings['banker_collected'], pc.amount)
            if pc.expires_in then
                desc = desc .. string.format(strings['banker_expires'], pc.expires_in)
            end

            options[#options + 1] = {
                title = pc.label,
                description = desc,
                icon = 'hand-holding-dollar',
                onSelect = function()
                    TriggerServerEvent('fd:paycheck:claimPaycheck', pc.id)
                    SetTimeout(500, function()
                        showpaycheckcontext()
                    end)
                end
            }
        end
    else
        options[#options + 1] = {
            title = strings['banker_no_paychecks'],
            description = strings['banker_no_paychecks_desc'],
            icon = 'ban',
            disabled = true
        }
    end

    lib.registerContext({
        id = 'bankerpaycheckmenu',
        title = strings['banker_title'],
        options = options
    })

    lib.showContext('bankerpaycheckmenu')
end

local function claimmenu()
    local strings = Locales[fd.locale]

    if lib.progressBar({
        duration = 3000,
        label = strings['banker_progress'],
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true,
        },
        anim = {
            dict = 'misscarsteal4@actor',
            clip = 'actor_berating_loop'
        },
    }) then
        showpaycheckcontext()
    end
end

CreateThread(function()
    if fd.paymentmethod ~= 'pickup' then return end

    -- blip
    if fd.enableblip then
        local blip = AddBlipForCoord(fd.pickuplocation.x, fd.pickuplocation.y, fd.pickuplocation.z)
        SetBlipSprite(blip, fd.blipsprite or 408)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.8)
        SetBlipColour(blip, fd.blipcolor or 2)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(fd.blipname or "Paycheck Pickup")
        EndTextCommandSetBlipName(blip)
    end

    local model = GetHashKey(fd.pedmodel or 's_m_m_postal_01')
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(50)
    end

    spawnedped = CreatePed(4, model, fd.pickuplocation.x, fd.pickuplocation.y, fd.pickuplocation.z - 1.0, fd.pickuplocationheading or 161.14, false, false)
    FreezeEntityPosition(spawnedped, true)
    SetEntityInvincible(spawnedped, true)
    SetBlockingOfNonTemporaryEvents(spawnedped, true)

    if fd.interaction == 'target' and GetResourceState('ox_target') == 'started' then
        exports.ox_target:addLocalEntity(spawnedped, {
            {
                name = 'claimpaycheck',
                event = 'fd:paycheck:client:claim',
                icon = 'fas fa-hand-holding-usd',
                label = Locales[fd.locale]['target_label']
            }
        })
    else
        local point = lib.points.new({
            coords = fd.pickuplocation,
            distance = 3.0
        })

        local isinrange = false

        function point:nearby()
            if self.currentDistance < 2.0 then
                if not isinrange then
                    lib.showTextUI(Locales[fd.locale]['talk_to_banker'])
                    isinrange = true
                end
                if IsControlJustReleased(0, 38) then
                    claimmenu()
                    Wait(1000)
                end
            else
                if isinrange then
                    lib.hideTextUI()
                    isinrange = false
                end
            end
        end

        function point:onExit()
            if isinrange then
                lib.hideTextUI()
                isinrange = false
            end
        end
    end
end)

RegisterNetEvent('fd:paycheck:client:claim', function()
    claimmenu()
end)

AddEventHandler('onResourceStop', function(resourcename)
    if resourcename == GetCurrentResourceName() then
        if spawnedped and DoesEntityExist(spawnedped) then
            DeletePed(spawnedped)
        end
    end
end)

