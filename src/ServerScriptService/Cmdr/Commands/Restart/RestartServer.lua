local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")

local RoundComponent = require(ServerScriptService.Component.Gameplay.Round)

return function()
    local roundInstance = CollectionService:GetTagged(RoundComponent.Tag)[1]
    if roundInstance == nil then
        return "No round is currently active."
    end
    RoundComponent:FromInstance(roundInstance):Reset()
end