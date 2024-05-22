-- Initialize global state variables
local GameData = GameData or {}
local TaskInProgress = TaskInProgress or false
local LogRecords = LogRecords or {}

-- Console color codes
local colorCodes = {
    scarlet = "\27[31m", lime = "\27[32m", cerulean = "\27[34m",
    amber = "\27[33m", violet = "\27[35m", neutral = "\27[0m"
}

-- Logging function
function logMessage(category, message)
    LogRecords[category] = LogRecords[category] or {}
    table.insert(LogRecords[category], message)
end

-- Check proximity of two points
function isWithinRange(x1, y1, x2, y2, distance)
    return math.abs(x1 - x2) <= distance and math.abs(y1 - y2) <= distance
end

-- Locate the opponent with the least health
function findMostVulnerableOpponent()
    local weakest, minHealth = nil, math.huge
    for id, state in pairs(GameData.Players) do
        if id ~= ao.id and state.health < minHealth then
            weakest, minHealth = state, state.health
        end
    end
    return weakest
end

-- Attack the most vulnerable opponent
function strikeWeakestOpponent()
    local target = findMostVulnerableOpponent()
    if target then
        local attackPower = GameData.Players[ao.id].energy * 0.5
        print(colorCodes.scarlet .. "Engaging weakest opponent with energy: " .. attackPower .. colorCodes.neutral)
        ao.send({ Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(attackPower) })
        TaskInProgress = false
        return true
    end
    return false
end

-- Move randomly
function randomMovement()
    local directions = {"North", "South", "East", "West"}
    local chosenDirection = directions[math.random(#directions)]
    print(colorCodes.cerulean .. "Moving randomly towards: " .. chosenDirection .. colorCodes.neutral)
    ao.send({ Target = Game, Action = "Move", Direction = chosenDirection })
end

-- Heal if health is below threshold
function performHealing()
    local self = GameData.Players[ao.id]
    if self.health < 0.4 then
        print(colorCodes.lime .. "Health is low, initiating heal..." .. colorCodes.neutral)
        ao.send({ Target = Game, Action = "Heal", Player = ao.id })
    end
end

-- Determine next action
function determineNextMove()
    if not strikeWeakestOpponent() then
        randomMovement()
    end
end

-- Handle game notifications and updates
Handlers.add("HandleAnnouncements", Handlers.utils.hasMatchingTag("Action", "Announcement"), function(msg)
    if msg.Event == "Started-Waiting-Period" then
        ao.send({ Target = ao.id, Action = "AutoPay" })
    elseif (msg.Event == "Tick" or msg.Event == "Started-Game") and not TaskInProgress then
        TaskInProgress = true
        ao.send({ Target = Game, Action = "GetGameState" })
    end
    print(colorCodes.lime .. msg.Event .. ": " .. msg.Data .. colorCodes.neutral)
end)

-- Trigger game state updates
Handlers.add("UpdateStateOnTick", Handlers.utils.hasMatchingTag("Action", "Tick"), function()
    if not TaskInProgress then
        TaskInProgress = true
        print(colorCodes.charcoal .. "Requesting game state..." .. colorCodes.neutral)
        ao.send({ Target = Game, Action = "GetGameState" })
    end
end)

-- Refresh game state on receiving update
Handlers.add("RefreshGameState", Handlers.utils.hasMatchingTag("Action", "GameState"), function(msg)
    local json = require("json")
    GameData = json.decode(msg.Data)
    ao.send({ Target = ao.id, Action = "UpdatedGameState" })
    print("Game state refreshed. Type 'GameData' to see details.")
end)

-- Determine next action
Handlers.add("DetermineNextMove", Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"), function()
    if GameData.GameMode ~= "Playing" then
        TaskInProgress = false
        return
    end
    performHealing()
    determineNextMove()
    ao.send({ Target = ao.id, Action = "Tick" })
end)

-- Auto-attack when hit
Handlers.add("AutoCounterAttack", Handlers.utils.hasMatchingTag("Action", "Hit"), function(msg)
    if not TaskInProgress then
        TaskInProgress = true
        local energy = GameData.Players[ao.id].energy
        if energy and energy > 0 then
            print(colorCodes.scarlet .. "Counterattacking." .. colorCodes.neutral)
            ao.send({ Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(energy) })
        end
        TaskInProgress = false
        ao.send({ Target = ao.id, Action = "Tick" })
    end
end)
