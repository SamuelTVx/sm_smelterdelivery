ESX = exports['es_extended']:getSharedObject()

local ActiveCustomers = {}
local ActiveDeliveries = {}

-- reset customers
local function ResetCustomers()
    ActiveCustomers = {}
    ActiveDeliveries = {}
    for i, c in ipairs(Config.Customers) do
        table.insert(ActiveCustomers, c)
    end

    for _, playerId in ipairs(GetPlayers()) do
        TriggerClientEvent('ox_lib:notify', playerId, {
            description = "New customers are available!",
            type = "success",
            duration = 8000
        })
    end
    print("[Delivery] Customers reset.")
end

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    ResetCustomers()
end)

-- reset every hour
CreateThread(function()
    while true do
        Wait(3600000) -- 1 hour
        ResetCustomers()
    end
end)

-- client requests customers
RegisterNetEvent("myDelivery:getCustomers")
AddEventHandler("myDelivery:getCustomers", function()
    local src = source
    TriggerClientEvent("myDelivery:sendCustomers", src, ActiveCustomers)
end)

-- start delivery
RegisterNetEvent("myDelivery:startDelivery")
AddEventHandler("myDelivery:startDelivery", function(customerName)
    local src = source
    local selectedCustomer = nil
    local index = nil

    for i, c in ipairs(ActiveCustomers) do
        if c.name == customerName then
            selectedCustomer = c
            index = i
            break
        end
    end

    if not selectedCustomer then
        TriggerClientEvent('ox_lib:notify', src, {description="This customer is no longer available!", type="error"})
        return
    end

    table.remove(ActiveCustomers, index)

    -- unique delivery ID
    local deliveryId = math.random(100000,999999)

    -- requirements by level
    local minComp, maxComp
    if selectedCustomer.level == "Easy" then
        minComp, maxComp = 1, 3
    elseif selectedCustomer.level == "Medium" then
        minComp, maxComp = 3, 8
    elseif selectedCustomer.level == "Hard" then
        minComp, maxComp = 8, 12
    end
    local requiredComps = math.random(minComp, maxComp)

    -- reward per component (config)
    local moneyPerComp = Config.MoneyPerComponent or 1000
    local rewardAmount = requiredComps * moneyPerComp

    -- store delivery server-side
    ActiveDeliveries[deliveryId] = {
        player = src,
        required = requiredComps,
        reward = rewardAmount,
        completed = false
    }
    -- send all info to client
    TriggerClientEvent("myDelivery:spawnDelivery", src, selectedCustomer.coords, selectedCustomer.name, selectedCustomer.timeLimit, rewardAmount, deliveryId, selectedCustomer.level, requiredComps)
end)

-- complete delivery
RegisterNetEvent("myDelivery:completeDelivery")
AddEventHandler("myDelivery:completeDelivery", function(deliveryId)
    local src = source
    local delivery = ActiveDeliveries[deliveryId]

    if not delivery then
        TriggerClientEvent('ox_lib:notify', src, {description="Invalid delivery!", type="error"})
        return
    end
    if delivery.player ~= src then
        TriggerClientEvent('ox_lib:notify', src, {description="This delivery doesn't belong to you!", type="error"})
        return
    end
    if delivery.completed then
        TriggerClientEvent('ox_lib:notify', src, {description="This delivery was already completed!", type="error"})
        return
    end

    local Inventory = exports.ox_inventory:Inventory()
    if Inventory.GetItem(src, "component", false, true) >= delivery.required then
        Inventory.RemoveItem(src, "component", delivery.required)
        exports.ox_inventory:AddItem(src, 'money', delivery.reward)
        Wait(100)
        TriggerClientEvent('ox_lib:notify', src, {
            title="Delivery",
            description="You delivered "..delivery.required.."x Component and earned $"..delivery.reward,
            type="success"
        })
        Wait(100)
        delivery.completed = true
        ActiveDeliveries[deliveryId] = nil
    else
        TriggerClientEvent('ox_lib:notify', src, {description="You don't have enough components!", type="error"})
    end
end)

-- ================= COLLECTING =================

lib.callback.register('myDelivery:collectIron', function()
    local src = source
    local Inventory = exports.ox_inventory:Inventory()
    local xPlayer = ESX.GetPlayerFromId(src)

    if Inventory.CanCarryItem(src, "iron_ore", 3) then
        Inventory.AddItem(src, "iron_ore", 3)
    else
        TriggerClientEvent('ox_lib:notify', src, { title = 'Delivery System', icon= 'ban', position = 'top', description = "Not enough space in your inventory!"})
    end
end)

lib.callback.register('myDelivery:collectDust', function()
    local src = source
    local Inventory = exports.ox_inventory:Inventory()
    local xPlayer = ESX.GetPlayerFromId(src)

    if Inventory.CanCarryItem(src, "steel_ore", 2) then
        Inventory.AddItem(src, "steel_ore", 2)
    else
        TriggerClientEvent('ox_lib:notify', src, { title = 'Delivery System', icon= 'ban', position = 'top', description = "Not enough space in your inventory!"})
    end
end)

-- ================= SMELTING =================

lib.callback.register('myDelivery:smeltIron', function(source)
    local src = source
    local Inventory = exports.ox_inventory:Inventory()
    local xPlayer = ESX.GetPlayerFromId(src)

    if Inventory.GetItem(src, "iron_ore", 1).count > 2 then
        Inventory.RemoveItem(src, "iron_ore", 3)
        Inventory.AddItem(src, "iron", 1)
    else
        TriggerClientEvent('ox_lib:notify', src, { title = 'Delivery System', icon= 'ban', position = 'top', description = "Not enough resources in your inventory!"})
    end
end)

lib.callback.register('myDelivery:smeltDust', function(source)
    local src = source
    local Inventory = exports.ox_inventory:Inventory()
    local xPlayer = ESX.GetPlayerFromId(src)

    if Inventory.GetItem(src, "steel_ore", 1).count > 1 then
        Inventory.RemoveItem(src, "steel_ore", 2)
        Inventory.AddItem(src, "steel", 1)
    else
        TriggerClientEvent('ox_lib:notify', src, { title = 'Delivery System', icon= 'ban', position = 'top', description = "Not enough resources in your inventory!"})
    end
end)

-- ================= COMPONENT CRAFTING =================

lib.callback.register('myDelivery:makeComp', function(source)
    local src = source
    local Inventory = exports.ox_inventory:Inventory()
    local xPlayer = ESX.GetPlayerFromId(src)
    if Inventory.GetItem(src, "iron", 1).count > 1 and Inventory.GetItem(src, "steel", 1).count > 0 then
        Inventory.RemoveItem(src, "iron", 2)
        Inventory.RemoveItem(src, "steel", 1)
        Inventory.AddItem(src, "component", 1)
    else
        TriggerClientEvent('ox_lib:notify', src, { title = 'Delivery System', icon= 'ban', position = 'top', description = "Not enough resources in your inventory!"})
    end
end)
