local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local RoundComponent = require(ServerScriptService.Component.Round)

local RoundService = Knit.CreateService {
    Name = "Round",
}

function RoundService:KnitInit()
end

function RoundService:KnitStart()
    self:StartRound()
end

function RoundService:StartRound()
    return RoundComponent.new("Testing Map")
end

function RoundService:EndRound()

end

return RoundService