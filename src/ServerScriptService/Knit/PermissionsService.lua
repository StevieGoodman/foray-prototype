local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

export type PermissionLevel = {
    Name: string,
    Check: (player: Player) -> boolean,
}

local PermissionsService = Knit.CreateService {
    Name = "Permissions",
    Client = {},
}

PermissionsService.PermissionLevels = {
    Player = {
        Check = function(_: Player)
            return true
        end,
    },
    Developer = {
        Check = function(player: Player)
            return player.UserId == game.CreatorId
        end
    }
}

function PermissionsService.Client:Check(player: Player, permissionLevelName: string)
    return self.Server.PermissionLevels[permissionLevelName].Check(player)
end

return PermissionsService