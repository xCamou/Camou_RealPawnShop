local ESX = exports["es_extended"]:getSharedObject()
lib.locale()

MySQL.ready(function()
    print("[Camou_RealPawnShop] " .. locale('db_connected'))
end)

local function updateVehicleOwner(plate, newOwner)
    MySQL.update('UPDATE owned_vehicles SET owner = ? WHERE plate = ?', {newOwner, plate})
end

CreateThread(function()
    while true do
        Wait(30 * 60 * 1000) -- sec = Wait(10 * 1000) 
        MySQL.update('UPDATE pawn_shop SET is_public = 1 WHERE expiry < NOW() AND is_public = 0')
    end
end)

lib.callback.register('pawnshop:pawnVehicle', function(source, props, duration, payAccount)
    local xPlayer = ESX.GetPlayerFromId(source)
    local plate = props.plate
    
    local owned = MySQL.single.await('SELECT * FROM owned_vehicles WHERE plate = ? AND owner = ?', {plate, xPlayer.identifier})
    if not owned then return false, locale('not_your_veh') end

    local modelValue = Config.VehicleValues[props.model] or Config.VehicleDefaultValue
    local payout = math.floor(modelValue * Config.PayoutRate)
    local buybackPrice = math.floor(payout * Config.InterestRate)
    
    local expiryDate = os.date('%Y-%m-%d %H:%M:%S', os.time() + (duration * 24 * 60 * 60)) -- in minutes = local expiryDate = os.date('%Y-%m-%d %H:%M:%S', os.time() + (duration * 60))

    local insertId = MySQL.insert.await('INSERT INTO pawn_shop (identifier, type, name, label, data, price, expiry) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        xPlayer.identifier, 'vehicle', tostring(props.model), ("Fahrzeug (%s)"):format(plate), json.encode(props), payout, expiryDate
    })

    if insertId then
        updateVehicleOwner(plate, 'PAWN_SHOP')
        
        local methodLabel = (payAccount == 'bank' and locale('payout_bank') or locale('payout_cash'))
        xPlayer.addAccountMoney(payAccount, payout)

        local contractMetadata = {
            label = locale('contract_label') .. insertId,
            type = locale('contract_type_veh'),
            plate = plate,
            buyback = buybackPrice,
            expiry = expiryDate,
            description = locale('contract_desc'):format(tostring(props.model), plate, methodLabel, buybackPrice, expiryDate),
            pawnId = insertId
        }
        exports.ox_inventory:AddItem(source, 'pawn_contract', 1, contractMetadata)

        return true, locale('pawn_success'):format(payout, methodLabel)
    end
    
    return false, locale('sql_error')
end)

lib.callback.register('pawnshop:pawnItem', function(source, itemName, amount, duration, payAccount)
    local xPlayer = ESX.GetPlayerFromId(source)
    local itemCfg = Config.AllowedItems[itemName]
    if not itemCfg then return false, locale('item_not_allowed') end

    amount = tonumber(amount) or 1
    if exports.ox_inventory:GetItemCount(source, itemName) < amount then 
        return false, locale('not_enough_items') 
    end

    local payout = math.floor((itemCfg.value * amount) * Config.PayoutRate)
    local buybackPrice = math.floor(payout * Config.InterestRate)
    local expiryDate = os.date('%Y-%m-%d %H:%M:%S', os.time() + (duration * 24 * 60 * 60)) -- in minutes = local expiryDate = os.date('%Y-%m-%d %H:%M:%S', os.time() + (duration * 60))

    local insertId = MySQL.insert.await('INSERT INTO pawn_shop (identifier, type, name, label, data, price, expiry) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        xPlayer.identifier, 'item', itemName, itemCfg.label .. " x" .. amount, json.encode({amount = amount}), payout, expiryDate
    })

    if insertId then
        exports.ox_inventory:RemoveItem(source, itemName, amount)
        
        local methodLabel = (payAccount == 'bank' and locale('payout_bank') or locale('payout_cash'))
        xPlayer.addAccountMoney(payAccount, payout)

        local contractMetadata = {
            label = locale('contract_label') .. insertId,
            type = locale('contract_type_item'),
            item = itemCfg.label,
            amount = amount,
            buyback = buybackPrice,
            expiry = expiryDate,
            description = locale('contract_desc'):format(itemCfg.label, "N/A", methodLabel, buybackPrice, expiryDate),
            pawnId = insertId
        }
        exports.ox_inventory:AddItem(source, 'pawn_contract', 1, contractMetadata)

        return true, locale('pawn_success'):format(payout, methodLabel)
    end
    
    return false, locale('sql_error')
end)

lib.callback.register('pawnshop:getMyItems', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    local results = MySQL.query.await('SELECT * FROM pawn_shop WHERE identifier = ? AND is_public = 0', {xPlayer.identifier})
    
    for i=1, #results do
        if results[i].expiry then
            results[i].expiry = os.date('%d.%m.%Y %H:%M', math.floor(results[i].expiry / 1000))
        end
    end
    return results
end)

lib.callback.register('pawnshop:getPublicItems', function(source)
    return MySQL.query.await('SELECT * FROM pawn_shop WHERE is_public = 1', {})
end)

RegisterNetEvent('pawnshop:buyBack', function(dbId)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    
    local item = MySQL.single.await('SELECT * FROM pawn_shop WHERE id = ?', {dbId})
    if not item or item.is_public == 1 then return end
    
    local inventoryItems = exports.ox_inventory:Search(_source, 'slots', 'pawn_contract')
    local foundContract, contractSlot = false, nil

    if inventoryItems then
        for _, slotData in pairs(inventoryItems) do
            if slotData.metadata and slotData.metadata.pawnId == dbId then
                foundContract, contractSlot = true, slotData.slot
                break
            end
        end
    end

    if not foundContract and item.identifier ~= xPlayer.identifier then
        return TriggerClientEvent('ox_lib:notify', _source, {type = 'error', description = locale('no_contract_error')})
    elseif not foundContract then
        TriggerClientEvent('ox_lib:notify', _source, {type = 'inform', description = locale('legacy_warning')})
    end

    local cost = math.floor(item.price * Config.InterestRate)
    if xPlayer.getMoney() < cost then 
        return TriggerClientEvent('ox_lib:notify', _source, {type='error', description = locale('no_money_cash')}) 
    end

    xPlayer.removeMoney(cost)
    if contractSlot then exports.ox_inventory:RemoveItem(_source, 'pawn_contract', 1, nil, contractSlot) end

    if item.type == 'item' then
        local data = json.decode(item.data)
        exports.ox_inventory:AddItem(_source, item.name, data.amount or 1)
    elseif item.type == 'vehicle' then
        local props = json.decode(item.data)
        updateVehicleOwner(props.plate, xPlayer.identifier)
        TriggerClientEvent('pawnshop:spawnReturnedVehicle', _source, props)
    end

    MySQL.query.await('DELETE FROM pawn_shop WHERE id = ?', {dbId})
    TriggerClientEvent('ox_lib:notify', _source, {type = 'success', description = locale('buyback_success')})
end)

RegisterNetEvent('pawnshop:buyPublic', function(dbId, payMethod)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    local item = MySQL.single.await('SELECT * FROM pawn_shop WHERE id = ? AND is_public = 1', {dbId})
    if not item then return TriggerClientEvent('ox_lib:notify', _source, {type = 'error', description = locale('not_available')}) end

    local price = math.floor(item.price * Config.InterestRate * 1.1)
    local account = (payMethod == 'bank' and 'bank' or 'money')

    if xPlayer.getAccount(account).money >= price then
        xPlayer.removeAccountMoney(account, price)

        if item.type == 'item' then
            local data = json.decode(item.data)
            exports.ox_inventory:AddItem(_source, item.name, data.amount or 1)
        elseif item.type == 'vehicle' then
            local props = json.decode(item.data)
            updateVehicleOwner(props.plate, xPlayer.identifier)
            TriggerClientEvent('pawnshop:spawnReturnedVehicle', _source, props)
        end

        MySQL.query.await('DELETE FROM pawn_shop WHERE id = ?', {dbId})
        TriggerClientEvent('ox_lib:notify', _source, {
            type = 'success', 
            description = locale('buy_success'):format(item.label, price, (payMethod == 'bank' and locale('buy_card') or locale('buy_cash')))
        })
    else
        TriggerClientEvent('ox_lib:notify', _source, {type = 'error', description = locale('no_money')})
    end
end)

ESX.RegisterCommand('pawn_releaseall', 'admin', function(xPlayer, args, showError)
    local affectedRows = MySQL.update.await('UPDATE pawn_shop SET is_public = 1 WHERE is_public = 0', {})
    
    if affectedRows > 0 then
        TriggerClientEvent('ox_lib:notify', xPlayer.source, {
            type = 'success', 
            description = ('Erfolgreich %s Gegenstände in den Gebrauchtmarkt verschoben.'):format(affectedRows)
        })
        print(('[Camou_RealPawnShop] Admin %s hat %s Items freigegeben.'):format(xPlayer.getName(), affectedRows))
    else
        TriggerClientEvent('ox_lib:notify', xPlayer.source, {
            type = 'inform', 
            description = 'Es gab keine aktiven Verträge zum Freigeben.'
        })
    end
end, false, {help = 'Alle Pfandgegenstände sofort in den Gebrauchtmarkt verschieben'})