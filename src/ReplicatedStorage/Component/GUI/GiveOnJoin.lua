local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Component = require(ReplicatedStorage.Packages.Component)
local Observers = require(ReplicatedStorage.Packages.Observers)
local Trove = require(ReplicatedStorage.Packages.Trove)

local GiveOnJoin = Component.new {
    Tag = "GiveOnJoin",
    Ancestors = { StarterGui },
}

function GiveOnJoin:Construct()
    self._trove = Trove.new()
end

function GiveOnJoin:Start()
    self._trove:Add(Observers.observePlayer(function(player: Player)
        local gui = self.Instance:Clone()
        gui:RemoveTag(self.Tag)
        gui.Parent = player.PlayerGui
    end))
end

function GiveOnJoin:Stop()
    self._trove:Clean()
end

return GiveOnJoin