local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)

function hook(commandContext)
    local permissionsLevelName = commandContext.Group or "Player"
    local player = commandContext.Executor
    local permissionsService = Knit.GetService("Permissions")
    if RunService:IsServer() then
        local permissionLevel = permissionsService.PermissionLevels[permissionsLevelName]
        if not permissionLevel.Check(player) then
            return `You must be a {permissionsLevelName} to run the "{commandContext.Name}" command.`
        end
    elseif RunService:IsClient() then
        local success, result = permissionsService.Check(player, permissionsLevelName):await()
        if not success then
            return `Failed to check permissions: {result}`
        end
        local hasPermission = result
        if not hasPermission then
            return `You must be a {permissionsLevelName} to run the "{commandContext.Name}" command.`
        end
    end
end

function register(registry)
    registry:RegisterHook("BeforeRun", hook)
end

return register