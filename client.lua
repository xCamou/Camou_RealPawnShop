local ESX = exports["es_extended"]:getSharedObject()
lib.locale()

CreateThread(function()
    local blip = AddBlipForCoord(Config.PawnPed.coords.x, Config.PawnPed.coords.y, Config.PawnPed.coords.z)
    SetBlipSprite(blip, 605) 
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.8)
    SetBlipColour(blip, 46) 
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(locale('pawn_main_title'))
    EndTextCommandSetBlipName(blip)
end)

CreateThread(function()
    while true do
        local sleep = 1500
        local playerPed = PlayerPedId() 
        local playerCoords = GetEntityCoords(playerPed)
        
        local distDrop = #(playerCoords - Config.VehicleZones.DropOff.coords)
        if distDrop < 15.0 then
            sleep = 0
            DrawMarker(1, Config.VehicleZones.DropOff.coords.x, Config.VehicleZones.DropOff.coords.y, Config.VehicleZones.DropOff.coords.z - 1.0, 0, 0, 0, 0, 0, 0, Config.VehicleZones.DropOff.radius * 2.0, Config.VehicleZones.DropOff.radius * 2.0, 1.0, 255, 255, 0, 100, false, false, 2, false, nil, nil, false)
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    local model = Config.PawnPed.model
    lib.requestModel(model)
    
    local ped = CreatePed(4, model, Config.PawnPed.coords.x, Config.PawnPed.coords.y, Config.PawnPed.coords.z - 1.0, Config.PawnPed.coords.w, false, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    exports.ox_target:addLocalEntity(ped, {
        {
            label = locale('pawn_talk'),
            icon = 'fa-solid fa-comments-dollar',
            onSelect = function() OpenMainPawnMenu() end
        }
    })
end)

local function GetVehicleLabel(model)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    local label = GetLabelText(GetDisplayNameFromVehicleModel(hash))
    if label == "NULL" then label = GetDisplayNameFromVehicleModel(hash) end
    return label
end

function OpenMainPawnMenu()
    lib.registerContext({
        id = 'pawn_main',
        title = locale('pawn_main_title'),
        options = {
            { 
                title = locale('pawn_item'), 
                description = locale('pawn_item_desc'),
                icon = 'box', 
                onSelect = function() OpenItemPawnMenu() end 
            },
            { 
                title = locale('pawn_vehicle'), 
                description = locale('pawn_vehicle_desc'),
                icon = 'car', 
                onSelect = function() OpenVehiclePawnMenu() end 
            },
            { 
                title = locale('pawn_recover'), 
                description = locale('pawn_recover_desc'),
                icon = 'retweet', 
                onSelect = function() OpenRecoveryMenu() end 
            },
            { 
                title = locale('pawn_shop'), 
                description = locale('pawn_shop_desc'),
                icon = 'shop', 
                onSelect = function() OpenPublicShop() end 
            },
        }
    })
    lib.showContext('pawn_main')
end

function OpenVehiclePawnMenu()
    local coords = Config.VehicleZones.DropOff.coords
    local vehicle = lib.getClosestVehicle(coords, Config.VehicleZones.DropOff.radius, false)
    local options = {}

    if vehicle and vehicle ~= 0 then
        local model = GetEntityModel(vehicle)
        local plate = GetVehicleNumberPlateText(vehicle)
        local vehicleLabel = GetVehicleLabel(model)
        
        local baseValue = Config.VehicleValues[model] or Config.VehicleDefaultValue
        local payout = math.floor(baseValue * Config.PayoutRate)

        table.insert(options, {
            title = ('%s (%s)'):format(vehicleLabel, plate),
            icon = 'car-side',
            description = locale('vehicle_payout_desc'):format(payout, Config.MaxPawnTime),
            onSelect = function()
                ProcessVehiclePawn(vehicle, payout)
            end
        })
    else
        table.insert(options, {
            title = locale('no_veh_found'),
            description = locale('no_veh_found_desc'),
            disabled = true
        })
    end

    lib.registerContext({
        id = 'pawn_vehicle_list',
        title = locale('available_vehicles'),
        menu = 'pawn_main',
        options = options
    })
    lib.showContext('pawn_vehicle_list')
end

function ProcessVehiclePawn(vehicle, payout)
    local props = lib.getVehicleProperties(vehicle)
    
    local input = lib.inputDialog(locale('confirm_header'), {
        {
            type = 'slider', 
            label = locale('pawn_duration'), 
            min = 1, 
            max = Config.MaxPawnTime, 
            default = 7,
            icon = 'calendar-days'
        },
        {
            type = 'select', 
            label = locale('payout_method'), 
            options = {
                {value = 'money', label = locale('payout_cash'), icon = 'money-bill-wave'},
                {value = 'bank', label = locale('payout_bank'), icon = 'building-columns'}
            }, 
            default = 'money',
            icon = 'wallet'
        }
    })

    if not input then return end

    local duration = input[1]
    local payAccount = input[2]
    local methodLabel = (payAccount == 'money' and locale('payout_cash') or locale('payout_bank'))

    local confirm = lib.alertDialog({
        header = locale('confirm_header'),
        content = locale('confirm_content'):format(GetVehicleLabel(props.model), payout, methodLabel, duration),
        centered = true,
        cancel = true
    })

    if confirm ~= 'confirm' then return end

    lib.callback('pawnshop:pawnVehicle', false, function(success, msg)
        if success then
            ESX.Game.DeleteVehicle(vehicle)
            lib.notify({type = 'success', description = msg})
        else
            lib.notify({type = 'error', description = msg})
        end
    end, props, duration, payAccount)
end

function OpenItemPawnMenu()
    local options = {}

    for itemName, itemData in pairs(Config.AllowedItems) do
        local count = exports.ox_inventory:GetItemCount(itemName)
        
        if count > 0 then
            table.insert(options, {
                title = itemData.label,
                description = ('%s: %s | %s: $%s'):format(locale('type_label'), itemData.category, locale('price_label'), itemData.value),
                icon = itemData.icon or 'box',
                metadata = {
                    {label = locale('type_label'), value = itemData.category}, 
                    {label = locale('amount_label'), value = count .. 'x'}
                },
                onSelect = function()
                    local dialogTitle = locale('item_pawn_title'):format(itemData.label)
                    
                    local input = lib.inputDialog(dialogTitle, {
                        {
                            type = 'number', 
                            label = locale('item_amount'), 
                            default = 1, min = 1, max = count,
                            icon = 'hashtag'
                        },
                        {
                            type = 'slider', 
                            label = locale('pawn_duration'), 
                            min = 1, max = Config.MaxPawnTime, default = 7,
                            icon = 'calendar-day'
                        },
                        {
                            type = 'select', 
                            label = locale('payout_method'), 
                            options = {
                                {value = 'money', label = locale('payout_cash'), icon = 'money-bill-wave'},
                                {value = 'bank', label = locale('payout_bank'), icon = 'building-columns'}
                            }, 
                            default = 'money',
                            icon = 'wallet'
                        }
                    })

                    if not input then return end

                    lib.callback('pawnshop:pawnItem', false, function(success, msg)
                        if success then
                            lib.notify({type = 'success', description = msg})
                        else
                            lib.notify({type = 'error', description = msg})
                        end
                    end, itemName, input[1], input[2], input[3])
                end
            })
        end
    end

    if #options == 0 then
        table.insert(options, {title = locale('no_items'), disabled = true})
    end

    lib.registerContext({
        id = 'pawn_item_list',
        title = locale('pawn_item'),
        menu = 'pawn_main',
        options = options
    })
    lib.showContext('pawn_item_list')
end

function OpenRecoveryMenu()
    lib.callback('pawnshop:getMyItems', false, function(results)
        local options = {}
        
        if not results or #results == 0 then 
            return lib.notify({
                type = 'inform',
                description = locale('no_contracts')
            }) 
        end

        for _, data in ipairs(results) do
            local cost = math.floor(data.price * Config.InterestRate)
            
            table.insert(options, {
                title = data.label,
                description = locale('buyback_desc'):format(cost),
                icon = (data.type == 'vehicle' and 'car' or 'box'),
                metadata = {
                    {label = locale('price_label'), value = '$' .. cost},
                    {label = locale('expiry_label'), value = data.expiry}
                },
                onSelect = function()
                    local confirm = lib.alertDialog({
                        header = locale('pawn_recover'),
                        content = ('Möchtest du %s für **$%s** wirklich auslösen?'):format(data.label, cost),
                        centered = true,
                        cancel = true
                    })

                    if confirm == 'confirm' then
                        TriggerServerEvent('pawnshop:buyBack', data.id)
                    else
                        OpenRecoveryMenu()
                    end
                end
            })
        end

        lib.registerContext({
            id = 'pawn_recovery', 
            title = locale('pawn_recover'), 
            menu = 'pawn_main',
            options = options
        })
        lib.showContext('pawn_recovery')
    end)
end

function OpenPublicShop()
    lib.callback('pawnshop:getPublicItems', false, function(items)
        local options = {}
        if not items or #items == 0 then 
            return lib.notify({description = locale('no_shop_items')}) 
        end

        for _, v in ipairs(items) do
            local price = math.floor(v.price * Config.InterestRate * 1.1)
            local data = json.decode(v.data)
            local itemMetadata = {}

            if v.type == 'vehicle' then
                local brandName = GetLabelText(GetMakeNameFromVehicleModel(data.model))
                local modelName = GetLabelText(GetDisplayNameFromVehicleModel(data.model))
                
                if brandName == "NULL" then brandName = locale('import_veh') end
                if modelName == "NULL" then modelName = locale('unknown_veh') end

                table.insert(itemMetadata, {label = locale('type_label'), value = locale('type_veh')})
                table.insert(itemMetadata, {label = locale('brand_label'), value = brandName})
                table.insert(itemMetadata, {label = locale('model_label'), value = modelName})
            else
                table.insert(itemMetadata, {label = locale('type_label'), value = locale('type_item')})
                table.insert(itemMetadata, {label = locale('amount_label'), value = data.amount or 1})
            end

            table.insert(options, {
                title = v.label,
                description = locale('price_display'):format(price),
                icon = (v.type == 'vehicle' and 'car' or 'box'),
                metadata = itemMetadata,
                onSelect = function()
                    local subOptions = {
                        {
                            title = locale('buy_cash'),
                            description = locale('buy_cash_desc'):format(price),
                            icon = 'money-bill-wave',
                            onSelect = function() TriggerServerEvent('pawnshop:buyPublic', v.id, 'money') end
                        },
                        {
                            title = locale('buy_card'),
                            description = locale('buy_card_desc'):format(price),
                            icon = 'credit-card',
                            onSelect = function() TriggerServerEvent('pawnshop:buyPublic', v.id, 'bank') end
                        }
                    }

                    if v.type == 'vehicle' then
                        table.insert(subOptions, 1, {
                            title = locale('vehicle_preview'),
                            description = locale('vehicle_preview_desc'),
                            icon = 'camera',
                            onSelect = function() ShowVehiclePreview(data) end
                        })
                    end

                    lib.registerContext({
                        id = 'pawn_buy_detail',
                        title = v.label,
                        menu = 'pawn_public',
                        options = subOptions
                    })
                    lib.showContext('pawn_buy_detail')
                end
            })
        end

        lib.registerContext({
            id = 'pawn_public',
            title = locale('pawn_shop'),
            menu = 'pawn_main',
            options = options
        })
        lib.showContext('pawn_public')
    end)
end

function ShowVehiclePreview(props)
    local playerPed = PlayerPedId()
    local isPreviewing = true
    
    lib.hideContext()
    FreezeEntityPosition(playerPed, true)
    SetEntityVisible(playerPed, false, false)
    SetEntityInvincible(playerPed, true)

    local model = props.model
    lib.requestModel(model)
    local pCoords = Config.Preview.coords
    
    local previewVehicle = CreateVehicle(model, pCoords.x, pCoords.y, pCoords.z, pCoords.w, false, false)
    lib.setVehicleProperties(previewVehicle, props)
    FreezeEntityPosition(previewVehicle, true)
    SetEntityInvincible(previewVehicle, true)

    local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    RenderScriptCams(true, true, 1000, true, true)
    local angle = 0.0
    
    lib.showTextUI(locale('preview_msg'), {
        position = "bottom",
        icon = 'backward'
    })

    CreateThread(function()
        local startTime = GetGameTimer()
        while isPreviewing and GetGameTimer() < startTime + 15000 do
            Wait(0)
            angle = angle + Config.Preview.rotationSpeed
            local offX = Config.Preview.camRadius * math.cos(math.rad(angle))
            local offY = Config.Preview.camRadius * math.sin(math.rad(angle))
            SetCamCoord(cam, pCoords.x + offX, pCoords.y + offY, pCoords.z + Config.Preview.camHeight)
            PointCamAtEntity(cam, previewVehicle, 0.0, 0.0, 0.0, true)

            if IsControlJustReleased(0, 177) then isPreviewing = false end
        end

        lib.hideTextUI()
        RenderScriptCams(false, true, 1000, true, true)
        DestroyCam(cam, false)
        if DoesEntityExist(previewVehicle) then DeleteEntity(previewVehicle) end
        SetEntityVisible(playerPed, true, false)
        FreezeEntityPosition(playerPed, false)
        SetEntityInvincible(playerPed, false)
        OpenPublicShop()
    end)
end

RegisterNetEvent('pawnshop:spawnReturnedVehicle', function(props)
    local spawn = Config.VehicleZones.Spawn
    ESX.Game.SpawnVehicle(props.model, spawn.coords, spawn.heading, function(veh)
        lib.setVehicleProperties(veh, props)
        SetVehicleNumberPlateText(veh, props.plate)
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
        lib.notify({type = 'success', description = locale('pawn_success_spawn')})
    end)
end)