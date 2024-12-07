local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Comm = require(ReplicatedStorage.Packages.Comm)
local Component = require(ReplicatedStorage.Packages.Component)
local ComponentExtensions = require(ReplicatedStorage.Packages.ComponentExtensions)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ValueObject = require(ReplicatedStorage.Packages.ValueObject)
local Waiter = require(ReplicatedStorage.Packages.Waiter)

local UnitGroupComponent = require(ServerScriptService.Component.Gameplay.UnitGroup)
local RoundComponent = require(ServerScriptService.Component.Gameplay.Round)
local TeamComponent = require(ServerScriptService.Component.Gameplay.Team)

local EMPTY_MESH_ID = 130968899561152
local EMPTY_MESH_DIMENSIONS = Vector3.new(1, 0.1, 1)
local STARTING_UNIT_COUNTS = {
    Neutral = 25,
    Red = 1_000,
    Blue = 1_000,
    Green = 1_000,
    Yellow = 1_000,
}

export type UpgradeType = {
    Name: string,
    Component: table,
    Cost: number,
    MeshId: number,
    MeshDimensions: number,
    MeshScale: number?,
}

local Node = Component.new {
    Tag = "Node",
    Ancestors = { workspace },
    Extensions = {
        ComponentExtensions.IsClass("BasePart"),
        ComponentExtensions.RequiresComponent(RoundComponent, Waiter.ancestors),
        ComponentExtensions.RequiresInstance("UnitCounter", Waiter.descendants, Waiter.matchTag),
        ComponentExtensions.RequiresInstance("Attachment", Waiter.descendants, Waiter.matchClassName),
    },
}

Node.IdCounter = 1
Node.UpgradeTypes = {}

function Node.RegisterUpgradeType(upgradeType: UpgradeType)
    Node.UpgradeTypes[upgradeType.Name] = upgradeType
    if upgradeType.MeshId == nil then
        warn(`Upgrade type "{upgradeType.Name}" does not have a MeshId.`)
    end
end

function Node.FromId(id: number)
    local nodes = Node:GetAll()
    for _, node in nodes do
        if node.Id ~= id then continue end
        return node
    end
end

function Node:Construct()
    setmetatable(self, Node)
    self.Id = Node.IdCounter
    Node.IdCounter += 1
    self.Instance.Name = `Node {self.Id}`
    self.Edges = ValueObject.Value.new({})
    self.Owner = ValueObject.Value.new(TeamComponent.FromName(self.Instance:GetAttribute("DefaultOwner") or "Neutral"))
    self.Round = self._components.Round
    self.UpgradeType = ValueObject.Value.new(nil)
    self.UpgradeComponent = ValueObject.Value.new(nil)

    self._comm = Comm.ServerComm.new(self.Instance, self.Tag)
    self._comm:BindFunction("SendUnitsTo", function(player, nodeId, unitCount)
        if not self:OwnedBy(player) and not player:HasTag("BypassesEnabled") then return end
        local node = Node.FromId(nodeId)
        if node == nil then return end
        self:SendUnitsTo(node, unitCount)
    end)
    self._comm:BindFunction("Upgrade", function(player, upgradeName)
        if upgradeName == nil then return end
        if not self:OwnedBy(player) and not player:HasTag("BypassesEnabled") then return end
        self:Upgrade(upgradeName)
    end)

    self._properties = {
        Id = self._comm:CreateProperty("Id", self.Id),
        Owner = self._comm:CreateProperty("Owner", if self.Owner:Get() == nil then nil else self.Owner:Get().Name),
    }

    self._trove = Trove.new()
    self:_setUpUnitCounts()
    self.Round:RegisterNode(self)
end

function Node:Start()
    self:GiveUnits(STARTING_UNIT_COUNTS[self.Owner:Get().Name], self.Owner:Get())
    self:_updateColor()
    self._trove:Add(self.Owner.Changed:Connect(function(newOwner)
        self._properties.Owner:Set(if newOwner ~= nil then newOwner.Name else nil)
    end))
    self._trove:Add(self.UpgradeType.Changed:Connect(function(newUpgradeType)
        if newUpgradeType == nil then return end
        local mesh = Waiter.getFirst(Waiter.descendants(self.Instance), Waiter.matchClassName("SpecialMesh")) :: SpecialMesh
        if mesh == nil then return end
        mesh.MeshId = `rbxassetid://{newUpgradeType.MeshId or EMPTY_MESH_ID}`
        mesh.Scale = Vector3.one * (newUpgradeType.MeshScale or 1)
        self.Instance.Size = (newUpgradeType.MeshDimensions or EMPTY_MESH_DIMENSIONS) * (newUpgradeType.MeshScale or 1)
        self.Instance.Position = Vector3.new(self.Instance.Position.X, self.Instance.Size.Y / 2, self.Instance.Position.Z)
        self.Instance.PivotOffset = CFrame.new(0, -self.Instance.Size.Y / 2, 0)
        self._instances.Attachment.WorldCFrame = CFrame.new(self.Instance.Position.X, EMPTY_MESH_DIMENSIONS.Y / 2, self.Instance.Position.Z)
    end))
end

function Node:Stop()
    self._trove:Clean()
end

function Node:CalculatePath(to)
    local distances = {}
    distances[self.Id] = 0
    for _, connectedNode in self:GetAllConnectedNodes() do
        distances[connectedNode.Id] = math.huge
    end

    -- Calculate path using Dijkstra's algorithm
    local predecessors = {}
    local queue = self:GetAllConnectedNodes()
    table.insert(queue, self)

    while #queue ~= 0 do
        local currentNode = TableUtil.Reduce(queue, function(a, b)
            return if distances[a.Id] < distances[b.Id] then a else b
        end, queue[1])
        local index = table.find(queue, currentNode)
        table.remove(queue, index)
        local currentDistanceTravelled = distances[currentNode.Id]
        local edges = currentNode.Edges:Get()
        for _, edge in edges do
            local connectedNode = edge:GetConnectedNode(currentNode)
            local newDistance = currentDistanceTravelled + edge.Length
            if newDistance >= distances[connectedNode.Id] then continue end
            distances[connectedNode.Id] = newDistance
            predecessors[connectedNode.Id] = currentNode
        end
    end

    -- Reconstruct path
    local path = {}
    local currentNode = to
    while currentNode ~= self do
        table.insert(path, currentNode)
        currentNode = predecessors[currentNode.Id]
    end
    path = TableUtil.Reverse(path)

    return path
end

function Node:GetDirectlyConnectedNodes()
    local visitedNodeIds = {}
    local connectedNodes = {}
    for _, edge in self.Edges:Get() do
        local connectedNode = edge:GetConnectedNode(self)
        if table.find(visitedNodeIds, connectedNode.Id) ~= nil then continue end
        table.insert(visitedNodeIds, connectedNode.Id)
        table.insert(connectedNodes, connectedNode)
    end
    return connectedNodes
end

function Node:GetAllConnectedNodes(connectedNodes: table?, visitedNodeIds: table?)
    visitedNodeIds = visitedNodeIds or {}
    connectedNodes = connectedNodes or {}
    table.insert(visitedNodeIds, self.Id)
    for _, connectedNode in self:GetDirectlyConnectedNodes() do
        if table.find(visitedNodeIds, connectedNode.Id) ~= nil then continue end
        table.insert(connectedNodes, connectedNode)
        connectedNode:GetAllConnectedNodes(connectedNodes, visitedNodeIds)
    end
    return connectedNodes
end

function Node:IsDirectlyConnectedTo(node)
    return table.find(self:GetDirectlyConnectedNodes(), node) ~= nil
end

function Node:IsConnectedTo(node)
    return table.find(self:GetAllConnectedNodes(), node) ~= nil
end

function Node:GetEdgeTo(node)
    for _, edge in self.Edges:Get() do
        if edge:GetConnectedNode(self).Id ~= node.Id then continue end
        return edge
    end
end

function Node:GetPivot()
    return self.Instance:GetPivot()
end

function Node:SendUnitsTo(node, unitCount: number)
    if self.Id == node.Id then return end
    unitCount = self:TakeUnits(unitCount, self.Owner:Get(), true)
    if unitCount <= 1 then
        self:GiveUnits(unitCount, self.Owner:Get())
        return
    end
    unitCount = math.floor(unitCount)
    UnitGroupComponent.new(self, node, unitCount)
end

function Node:OwnedBy(player: Player)
    if self.Owner:Get() == nil then return false end
    return self.Owner:Get():IsMember(player)
end

function Node:GetUnitCount(team): number
    return self._unitCounts[team.Name]
end

function Node:SetUnitCount(newUnitCount: number, team): number
    newUnitCount = math.max(newUnitCount, 0)
    local unitCount = self:GetUnitCount(team)
    unitCount:Set(newUnitCount)
    return unitCount:Get()
end

function Node:TakeUnits(amount: number, team, protectOwnership: boolean): number
    amount = math.max(amount, 0)
    local unitCount = self:GetUnitCount(team)
    local taken = math.min(if protectOwnership then unitCount:Get() - 1 else unitCount:Get(), amount)
    self:SetUnitCount(unitCount:Get() - taken, team)
    return taken
end

function Node:GiveUnits(amount: number, team): number
    amount = math.max(amount, 0)
    local unitCount = self:GetUnitCount(team)
    self:SetUnitCount(unitCount:Get() + amount, team)
    return amount
end

function Node:RemoveUpgrades()
    for _, upgrade in Node.UpgradeTypes do
        self.Instance:RemoveTag(upgrade.Component.Tag)
    end
    self.UpgradeType:Set(nil)
    self.UpgradeComponent:Set(nil)
end

function Node:Upgrade(upgradeName: string)
    local upgrade = Node.UpgradeTypes[upgradeName]
    assert(upgrade ~= nil, `Upgrade "{upgradeName}" is not a valid upgrade name.`)
    local upgradeComponent = Node.UpgradeTypes[upgradeName].Component
    if self.Instance:HasTag(upgrade.Component.Tag) then return end
    if self:GetUnitCount(self.Owner:Get()):Get() <= upgrade.Cost then return end
    self:TakeUnits(upgrade.Cost, self.Owner:Get(), false)
    self:RemoveUpgrades()
    self.Instance:AddTag(upgradeComponent.Tag)
    self.UpgradeType:Set(upgrade)
    upgradeComponent:WaitForInstance(self.Instance)
    :andThen(function(component)
        if self.UpgradeType:Get() ~= nil and self.UpgradeType:Get().Name ~= upgradeName then return end
        self.UpgradeComponent:Set(component)
    end)
end

function Node:_setUpUnitCounts()
    self._unitCounts = {}
    for _, team in TeamComponent.Teams:Get() do
        self:_setUpUnitCount(team)
    end

    self._trove:Add(TeamComponent.Teams.Changed:Connect(function(teams)
        for _, team in teams do
            self:_setUpUnitCount(team)
        end
    end))
end

function Node:_setUpUnitCount(team)
    if self._unitCounts[team.Name] ~= nil then return end
    self._unitCounts[team.Name] = ValueObject.Value.new(0)
    self._trove:Add(self._unitCounts[team.Name])

    self._trove:Add(self._unitCounts[team.Name].Changed:Connect(function(_: number)
        self:_updateColor()
        self:_updateUnitCounter()
        self:_updateOwner()

        local teamsPresent = #TableUtil.Keys(TableUtil.Filter(self._unitCounts, function(unitCount, _)
            return unitCount:Get() > 0
        end))
        if teamsPresent > 1 then
            self.Instance:AddTag("Battle")
        else
            self.Instance:RemoveTag("Battle")
        end
    end))
end

function Node:_updateColor()
    local colorValues = {
        Red = 0,
        Green = 0,
        Blue = 0,
    }
    local totalUnitCount = 0
    for teamName, unitCount in self._unitCounts do
        totalUnitCount += unitCount:Get()
        local team = TeamComponent.FromName(teamName)
        local color = team.Color
        colorValues.Red += color.R * unitCount:Get()
        colorValues.Green += color.G * unitCount:Get()
        colorValues.Blue += color.B * unitCount:Get()
    end
    colorValues = {
        Red = colorValues.Red / totalUnitCount,
        Green = colorValues.Green / totalUnitCount,
        Blue = colorValues.Blue / totalUnitCount,
    }
    self.Instance.Color = Color3.new(colorValues.Red, colorValues.Green, colorValues.Blue)
end

function Node:_updateOwner()
    local presentUnitCounts = TableUtil.Filter(self._unitCounts, function(unitCount, _)
        return unitCount:Get() > 0
    end)
    local presentTeamCount = #TableUtil.Keys(presentUnitCounts)
    if presentTeamCount == 0 then
        self.Owner:Set(nil)
        return
    elseif presentTeamCount == 1 then
        for teamName, _ in presentUnitCounts do
            if self.Owner:Get() ~= nil and self.Owner:Get().Name == teamName then return end
            self.Owner:Set(TeamComponent.FromName(teamName))
            return
        end
        return
    end
end

function Node:_updateUnitCounter()
    local text = ""
    for teamName, unitCount in self._unitCounts do
        if unitCount:Get() < 1 then continue end
        local team = TeamComponent.FromName(teamName)
        text ..= `<font color="#{team.Color:ToHex()}">{math.floor(unitCount:Get())}</font>`
        text ..= " v "
    end
    text = string.sub(text, 1, -4)
    self._instances.UnitCounter.Text = text
end

function Node:__eq(other)
    return self.Id == other.Id
end

return Node