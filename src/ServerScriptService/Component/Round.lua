local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ValueObject = require(ReplicatedStorage.Packages.ValueObject)
local Waiter = require(ReplicatedStorage.Packages.Waiter)

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

    self._nodes = ValueObject.new({})
    self._folders = ValueObject.new({})
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

    self._trove:Add(node.Owner.Changed:Connect(function()
        self:_checkForRoundEnd()
    end))
end

function Round:GetNodeTallies(): {[string]: number}
    local nodeTallies = {}
    for _, node in self._nodes:Get() do
        nodeTallies[node.Owner:Get().Name] = (nodeTallies[node.Owner:Get().Name] or 0) + 1
    end
    return nodeTallies
end

function Round:GetOwnershipPercentages(): {[string]: number}
    local nodeTallies = self:GetNodeTallies()
    local totalNodes = 0
    for _, count in nodeTallies do
        totalNodes += count
    end
    local ownershipPercentages = {}
    for teamName, count in nodeTallies do
        ownershipPercentages[teamName] = count / totalNodes
    end
    return ownershipPercentages
end

function Round:_checkForRoundEnd()
    local ownershipPercentages = self:GetOwnershipPercentages()
    for teamName, percentage in ownershipPercentages do
        if teamName == "Neutral" then continue end
        if percentage < GAME_END_THRESHOLD then continue end
        print(`{teamName} team has won the round!`)
        self:Reset()
    end
end

Round.new("Testing Map")

return Round