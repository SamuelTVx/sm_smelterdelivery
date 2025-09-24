--============================================================--
--=               Smelter Component Delivery Job             =--
--=           Collect → Smelt → Craft → Deliver               =--
--============================================================--

-- Main vars
local mainPed, deliveryPed, deliveryBlip, currentDelivery, deliveryTimer = nil, nil, nil, nil, nil
local timeRemaining = 0

--============================================================--
--=                       BLIPS                               =--
--============================================================--

-- Smelter blip
CreateThread(function()
    local blip = AddBlipForCoord(1111.0, -2000.0, 30.0)
    SetBlipSprite(blip, 436)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.5)
    SetBlipColour(blip, 5)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Smelter")
    EndTextCommandSetBlipName(blip)
end)

--============================================================--
--=                  MAIN NPC (Customers)                     =--
--============================================================--

-- Spawn main NPC
CreateThread(function()
    local model = joaat(Config.MainNPC.model)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end

    local coords = Config.MainNPC.coords
    mainPed = CreatePed(0, model, coords.x, coords.y, coords.z - 1, coords.heading, false, true)
    SetEntityInvincible(mainPed, true)
    SetBlockingOfNonTemporaryEvents(mainPed, true)
    FreezeEntityPosition(mainPed, true)

    -- ox_target zone
    exports.ox_target:addBoxZone({
        coords = vector3(coords.x, coords.y, coords.z),
        size = vec3(1.0, 1.0, 2.0),
        rotation = coords.heading,
        debug = false,
        options = {{
            event = "myDelivery:openCustomerMenu",
            icon = "fa-solid fa-user",
            label = "Customers"
        }}
    })
end)

-- Open menu
RegisterNetEvent("myDelivery:openCustomerMenu", function()
    TriggerServerEvent("myDelivery:getCustomers")
end)

-- Customers menu
RegisterNetEvent("myDelivery:sendCustomers", function(customers)
    local options = {}
    for _, c in ipairs(customers) do
        table.insert(options, {
            title = c.name,
            description = "Level: "..c.level.." | Time: "..c.timeLimit.." min",
            icon = "fa-solid fa-truck",
            onSelect = function()
                TriggerServerEvent("myDelivery:startDelivery", c.name)
            end
        })
    end

    lib.registerContext({ id = "customer_menu", title = "Customers", options = options })
    lib.showContext("customer_menu")
end)

--============================================================--
--=                    DELIVERY SYSTEM                        =--
--============================================================--

-- Spawn delivery ped + blip + timer
RegisterNetEvent("myDelivery:spawnDelivery", function(coords, name, timeLimit, reward, deliveryId, level, requiredComps)
    currentDelivery = {name = name, reward = reward, id = deliveryId, level = level, required = requiredComps}
    timeRemaining = (tonumber(timeLimit) or 5) * 60

    if DoesBlipExist(deliveryBlip) then RemoveBlip(deliveryBlip) end
    deliveryBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(deliveryBlip, 1)
    SetBlipColour(deliveryBlip, 2)
    SetBlipScale(deliveryBlip, 0.8)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Delivery: "..name.." ("..level..")")
    EndTextCommandSetBlipName(deliveryBlip)
    SetNewWaypoint(coords.x, coords.y)

    local model = `a_m_m_business_01`
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end
    deliveryPed = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, 0.0, false, true)
    SetEntityInvincible(deliveryPed, true)
    SetBlockingOfNonTemporaryEvents(deliveryPed, true)
    FreezeEntityPosition(deliveryPed, true)

    exports.ox_target:addBoxZone({
        coords = vector3(coords.x, coords.y, coords.z),
        size = vec3(1.0, 1.0, 2.0),
        rotation = 0.0,
        debug = false,
        options = {{
            event = "myDelivery:deliverPackage",
            icon = "fa-solid fa-box",
            label = "Deliver Package"
        }}
    })

    lib.notify({
        title = "Delivery Started",
        position = 'bottom',
        description = "Customer "..name.." needs "..requiredComps.."x Component. Reward: $"..reward,
        type = "inform"
    })

    StartDeliveryTimer()
end)

-- Deliver package
RegisterNetEvent("myDelivery:deliverPackage", function()
    if currentDelivery then
        lib.progressCircle({
            duration = 3000,
            position = 'bottom',
            label = "Delivering package...",
            useWhileDead = false,
            canCancel = false,
            disable = {car = true, move = true},
            anim = {dict = 'misscarsteal4@actor', clip = 'actor_berating_loop'},
        })
        TriggerServerEvent("myDelivery:completeDelivery", currentDelivery.id)
        Wait(500)
        if DoesEntityExist(deliveryPed) then DeleteEntity(deliveryPed) end
        if DoesBlipExist(deliveryBlip) then RemoveBlip(deliveryBlip) end
        currentDelivery = nil
        KillTimer()
    end
end)

-- Timer HUD
function StartDeliveryTimer()
    if deliveryTimer then TerminateThread(deliveryTimer) end
    deliveryTimer = CreateThread(function()
        while timeRemaining > 0 do
            Wait(1000)
            timeRemaining -= 1
        end
        if currentDelivery then
            lib.notify({description = "Time expired!", type = "error"})
            if DoesEntityExist(deliveryPed) then DeleteEntity(deliveryPed) end
            if DoesBlipExist(deliveryBlip) then RemoveBlip(deliveryBlip) end
            currentDelivery = nil
        end
    end)
end

-- Draw timer text
CreateThread(function()
    while true do
        Wait(0)
        if currentDelivery and timeRemaining > 0 then
            SetTextFont(0)
            SetTextProportional(1)
            SetTextScale(0.4, 0.4)
            SetTextColour(255, 255, 255, 255)
            SetTextOutline()
            SetTextEntry("STRING")
            AddTextComponentString("Delivery time: "..math.floor(timeRemaining/60)..":"..string.format("%02d", timeRemaining % 60).." | Level: "..currentDelivery.level)
            DrawText(0.85, 0.95)
        end
    end
end)

function KillTimer()
    if deliveryTimer then
        TerminateThread(deliveryTimer)
        deliveryTimer, timeRemaining = nil, 0
    end
end


--============================================================--
--=                COLLECTING RESOURCES                       =--
--============================================================--

for _, spot in ipairs(Config.IronMineSpots) do
    exports.ox_target:addBoxZone({
        coords = spot,
        size = vec3(1.5, 1.5, 1.0),
        rotation = 0,
        range = "2",
        debug = false,
        options = {{
            event = "myDelivery:mine",
            icon = "fa-solid fa-mountain",
            label = "Collect resources"
        }}
    })
end

RegisterNetEvent("myDelivery:mine", function()
    lib.registerContext({
        id = 'collect_menu',
        title = 'Collecting Menu',
        options = {
            {
                title = "Iron Ore",
                icon = 'fa-solid fa-hand',
                onSelect = function()
                    lib.progressCircle({
                        duration = 10000,
                        position = 'bottom',
                        label = "Collecting Iron Ore...",
                        canCancel = false,
                        disable = {car = true, move = true},
                        anim = {dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer'},
                    })
                    lib.callback.await('myDelivery:collectIron')
                    lib.notify({description = "Collected Iron Ore", type = "success"})
                end,
            },
            {
                title = "Steel Ore",
                icon = 'fa-solid fa-hand',
                onSelect = function()
                    lib.progressCircle({
                        duration = 10000,
                        position = 'bottom',
                        label = "Collecting Steel Ore...",
                        canCancel = false,
                        disable = {car = true, move = true},
                        anim = {dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer'},
                    })
                    lib.callback.await('myDelivery:collectDust')
                    lib.notify({description = "Collected Steel Ore", type = "success"})
                end,
            }
        }
    })
    lib.showContext('collect_menu')
end)

--============================================================--
--=                     SMELTER MENU                          =--
--============================================================--

exports.ox_target:addBoxZone({
    coords = Config.Smelter.coords,
    size = vec3(2.0, 2.0, 1.0),
    rotation = 0,
    range = "2",
    debug = false,
    options = {{
        event = "myDelivery:smeltMenu",
        icon = "fa-solid fa-industry",
        label = "Open Smelting Menu"
    }}
})

RegisterNetEvent("myDelivery:smeltMenu", function()
    lib.registerContext({
        id = 'smelt_menu',
        title = 'Smelting Menu',
        options = {
            {
                title = "Iron Ingot",
                icon = 'fa-solid fa-fire',
                description = '3x Iron Ore',
                onSelect = function()
                    lib.progressCircle({
                        duration = 6500,
                        position = 'bottom',
                        label = "Smelting Iron Ore...",
                        canCancel = false,
                        disable = {car = true, move = true},
                        anim = {dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer'},
                    })
                    lib.callback.await('myDelivery:smeltIron')
                    lib.notify({description = "Iron Ingot crafted", type = "success"})
                end,
            },
            {
                title = "Steel",
                icon = 'fa-solid fa-fire',
                description = '2x Steel Ore',
                onSelect = function()
                    lib.progressCircle({
                        duration = 6500,
                        position = 'bottom',
                        label = "Smelting Steel Ore...",
                        canCancel = false,
                        disable = {car = true, move = true},
                        anim = {dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer'},
                    })
                    lib.callback.await('myDelivery:smeltDust')
                    lib.notify({description = "Steel crafted", type = "success"})
                end,
            }
        }
    })
    lib.showContext('smelt_menu')
end)

--============================================================--
--=                   COMPONENTS MENU                         =--
--============================================================--

for _, spot in ipairs(Config.Component) do
    exports.ox_target:addBoxZone({
        coords = spot,
        size = vec3(1.5, 1.5, 1.0),
        rotation = 0,
        range = "5",
        debug = false,
        options = {{
            event = "myDelivery:makeComp",
            icon = "fa-solid fa-gears",
            label = "Open Component Menu"
        }}
    })
end

RegisterNetEvent("myDelivery:makeComp", function()
    lib.registerContext({
        id = 'component_menu',
        title = 'Component Menu',
        options = {{
            title = "Craft Component",
            icon = 'fa-solid fa-gears',
            description = '2x Iron, 1x Steel',
            onSelect = function()
                lib.progressCircle({
                    duration = 6500,
                    position = 'bottom',
                    label = "Crafting Component...",
                    canCancel = false,
                    disable = {car = true, move = true},
                    anim = {dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer'},
                })
                lib.callback.await('myDelivery:makeComp')
                lib.notify({description = "Component crafted", type = "success"})
            end,
        }}
    })
    lib.showContext('component_menu')
end)
