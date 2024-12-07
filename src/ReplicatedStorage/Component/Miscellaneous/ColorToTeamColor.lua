local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)

local TeamComponent = require(ReplicatedStorage.Component.Gameplay.Team)

local ColorToTeamColor = Component.new {
    Tag = "ColorToTeamColor",
    Ancestors = { game },
}

function ColorToTeamColor:Construct()
    self._trove = Trove.new()
end

function ColorToTeamColor:SteppedUpdate()
    local team = Players.LocalPlayer.Team
    if team == nil then return end
    team = TeamComponent:FromInstance(team)
    if self.Instance:IsA("Frame") then
        self.Instance.BackgroundColor3 = team.Color
    else
        warn(`Cannot color {self.Instance.ClassName} to a team color! Is the {self.Instance.ClassName} class missing an implementation?`)
    end
end

function ColorToTeamColor:Stop()
    self._trove:Clean()
end

return ColorToTeamColor