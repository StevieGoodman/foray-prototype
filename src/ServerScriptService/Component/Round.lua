local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Component = require(ReplicatedStorage.Packages.Component)
local Knit = require(ReplicatedStorage.Packages.Knit)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ValueObject = require(ReplicatedStorage.Packages.ValueObject)
local Waiter = require(ReplicatedStorage.Packages.Waiter)

local NotificationService = Knit.GetService("Notification")
local TeamComponent = require(ServerScriptService.Component.Team)
local RoundProgressSummary = require(ReplicatedStorage.Types.RoundProgressSummary)

local GAME_END_THRESHOLD = 0.8

local Round = Component.new {
    Tag = "Round",
    Ancestors = { workspace },
}

Round.IdCounter = 1

function Round.new(mapName: string)
    local mapTemplate =
        Waiter.getFirst(
            Waiter.descendants(ServerStorage.Maps),
            Waiter.matchQuery({
                Name = mapName,
                Tag = "Map",
            }))
    assert(mapTemplate ~= nil, `Map template "{mapName}" not found`)
    local self = mapTemplate:Clone()
    self:RemoveTag("Map")
    self:AddTag(Round.Tag)
    self.Parent = workspace
    return Round:WaitForInstance(self)
end

function Round:Construct()
    self.MapName = self.Instance.Name
    self.Id = Round.IdCounter
    Round.IdCounter += 1
    self.Instance.Name = `Round {self.Id} ({self.MapName})`

    self._nodes = ValueObject.Value.new({})
    self._folders = ValueObject.Value.new({})
    self._trove = Trove.new()
end

function Round:End()
    self.Instance:Destroy()
end

function Round:Reset()
    self:End()
    return Round.new(self.Name)
end

function Round:GetFolder(name)
    local folders = self._folders:Get()
    local folder = folders[name]
    if folder == nil then
        folder = Instance.new("Folder")
        folder.Name = name
        folder.Parent = self.Instance
        folders[name] = folder
    end
    return folder
end

function Round:RegisterNode(node)
    local nodes = self._nodes:Get()
    for _, existingNode in nodes do
        if existingNode.Id == node.Id then return end
    end

    table.insert(nodes, node)
    self._nodes:Set(nodes)
    self._trove:Add(node.Owner.Changed:Connect(function(newOwner)
        self:_checkForRoundEnd(newOwner)
    end))
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

function Round:_checkForRoundEnd(team: TeamComponent.Team)
    if team.Name == "Neutral" then return end
    local progressSummary = self:GetProgressSummary()
    local teamSummary = progressSummary.Summary[team]
    local ownershipPercentage = teamSummary.NodeCount / progressSummary.TotalNodeCount
    if ownershipPercentage < GAME_END_THRESHOLD then return end
    NotificationService:NotifyAll(`<font color="#{team.Color:ToHex()}">{team.Name}</font> team has won the round!`)
    self:Reset()
end

Round.new("Testing Map")

return Round