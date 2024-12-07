local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TeamComponent = require(ReplicatedStorage.Component.Team)

export type RoundProgressSummary = {
    AddTeam: (self: RoundProgressSummary, team: TeamComponent.Team, number: number) -> RoundProgressSummary,
    TotalNodeCount: number,
    Summary: {
        [TeamComponent.Team]: TeamProgressSummary,
    }
}

export type TeamProgressSummary = {
    NodeCount: number,
}

local RoundProgressSummary = {}

function RoundProgressSummary.new()
    local self = {
        TotalNodeCount = 0,
        Summary = {}
    }
    setmetatable(self, RoundProgressSummary)
    return self
end

function RoundProgressSummary:AddTeam(team: TeamComponent.Team, nodeCount: number): RoundProgressSummary
    assert(self.Summary[team] == nil, "Team already exists in this RoundProgressSummary object!")
    self.Summary[team] = {
        NodeCount = nodeCount,
    }
    self.TotalNodeCount += nodeCount
    return self
end

function RoundProgressSummary:__iter()
    return next, self.Summary
end

RoundProgressSummary.__index = RoundProgressSummary

return RoundProgressSummary