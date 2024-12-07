local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ValueObject = require(ReplicatedStorage.Packages.ValueObject)

local TeamComponent = require(ReplicatedStorage.Component.Team)
local RoundProgressSummary = require(ReplicatedStorage.Types.RoundProgressSummary)

local Round = Component.new {
    Tag = "Round",
    Ancestors = { workspace },
}

Round.IdCounter = 1

function Round.Get()
    return Round:GetAll()[1]
end

function Round:Construct()
    self.MapName = self.Instance.Name
    self.Id = Round.IdCounter
    Round.IdCounter += 1

    self._nodes = ValueObject.Value.new({})
    self._trove = Trove.new()
end

function Round:RegisterNode(node)
    local nodes = self._nodes:Get()
    for _, existingNode in nodes do
        if existingNode.Id == node.Id then return end
    end

    table.insert(nodes, node)
    self._nodes:Set(nodes)
end

function Round:GetProgressSummary(): RoundProgressSummary.RoundProgressSummary
    -- Count the number of nodes each team owns
    local nodeTallies = {}
    for _, node in self._nodes:Get() do
        nodeTallies[node.Owner:Get().Name] = (nodeTallies[node.Owner:Get().Name] or 0) + 1
    end
    -- Create the RoundProgressSummary object
    local summary = RoundProgressSummary.new()
    for teamName, count in nodeTallies do
        summary:AddTeam(TeamComponent.FromName(teamName), count)
    end
    return summary
end

return Round