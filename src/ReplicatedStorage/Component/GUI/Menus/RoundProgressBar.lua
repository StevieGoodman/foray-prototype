local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Component = require(ReplicatedStorage.Packages.Component)
local ComponentExtensions = require(ReplicatedStorage.Packages.ComponentExtensions)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Waiter = require(ReplicatedStorage.Packages.Waiter)

local RoundProgressSummary = require(ReplicatedStorage.Types.RoundProgressSummary)
local RoundComponent = require(ReplicatedStorage.Component.Round)

local RoundProgressBar = Component.new {
    Tag = "RoundProgressBar",
    Ancestors = { Players.LocalPlayer.PlayerGui },
    Extensions = {
        ComponentExtensions.RequiresInstance("BarTemplate", Waiter.descendants, Waiter.matchTag),
    },
}

function RoundProgressBar:Construct()
    self._trove = Trove.new()
    self._instances.BarTemplate.LayoutOrder = math.huge
end

function RoundProgressBar:SteppedUpdate()
    local round = RoundComponent.Get()
    if round == nil then return end
    self:Update(round:GetProgressSummary())
end

function RoundProgressBar:Stop()
    self._trove:Clean()
end

function RoundProgressBar:Update(summary: RoundProgressSummary.RoundProgressSummary)
    self._trove:Clean()
    for team, teamSummary in summary do
        if team.Name == "Neutral" then continue end
        local percentage01 = teamSummary.NodeCount / summary.TotalNodeCount
        local percentageString = string.format("%.0f", percentage01 * 100)
        local bar = self._instances.BarTemplate:Clone()
        bar.Parent = self._instances.BarTemplate.Parent
        bar.Size = UDim2.new(percentage01, 0, 1, 0)
        bar.BackgroundColor3 = team.Color
        bar.Text = `{percentageString}%`
        bar.LayoutOrder -= teamSummary.NodeCount
        bar.Name = team.Name
        self._trove:Add(bar)
    end
end

return RoundProgressBar