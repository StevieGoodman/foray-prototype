local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Comm = require(ReplicatedStorage.Packages.Comm)
local Component = require(ReplicatedStorage.Packages.Component)
local ComponentExtensions = require(ReplicatedStorage.Packages.ComponentExtensions)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ValueObject = require(ReplicatedStorage.Packages.ValueObject)
local Waiter = require(ReplicatedStorage.Packages.Waiter)

local UnitGroupComponent = require(ServerScriptService.Component.UnitGroup)
local RoundComponent = require(ServerScriptService.Component.Round)
local TeamComponent = require(ServerScriptService.Component.Team)

local Node = Component.new {
    Tag = "Node",
    Ancestors = { workspace },
    Extensions = {
        ComponentExtensions.IsClass("BasePart"),
        ComponentExtensions.RequiresComponent(RoundComponent, Waiter.ancestors),
        ComponentExtensions.RequiresInstance("UnitCounter", Waiter.descendants, Waiter.matchTag),
    },
}

Node.IdCounter = 1

function Node.FromId(id: number)
    local nodes = Node:GetAll()
    for _, node in nodes do
        if node.Id ~= id then continue end
        return node
    end
end

function Node:Construct()
    self.Id = Node.IdCounter
    Node.IdCounter += 1
    self.Instance.Name = `Node {self.Id}`
    self.ProductionRate = ValueObject.new(1)
    self.UnitCount = ValueObject.new(0)
    self.Edges = ValueObject.new({})
    self.Round = self._components.Round
    self.Owner = ValueObject.new(TeamComponent.FromName(self.Instance:GetAttribute("DefaultOwner")))

    self._comm = Comm.ServerComm.new(self.Instance, self.Tag)
    self._comm:BindFunction("SendUnitsTo", function(player, nodeId, unitCount)
        if not self:OwnedBy(player) then return end
        local node = Node.FromId(nodeId)
        if node == nil then return end
        self:SendUnitsTo(node, unitCount)
    end)
    self._properties = {
        Id = self._comm:CreateProperty("Id", self.Id),
        UnitCount = self._comm:CreateProperty("UnitCount", self.UnitCount:Get()),
        Owner = self._comm:CreateProperty("Owner", if self.Owner:Get() == nil then nil else self.Owner:Get().Name),
    }

    self._trove = Trove.new()
    self._trove:Add(self.UnitCount)
end

function Node:Start()
    self._trove:Add(self.UnitCount.Changed:Connect(function(newUnitCount)
        self._properties.UnitCount:Set(newUnitCount)
        self:_updateUnitCounter()
    end))
    self:_updateColor()
    self._trove:Add(self.Owner.Changed:Connect(function(newOwner)
        self._properties.Owner:Set(newOwner.Name)
        self:_updateColor()
    end))
end

function Node:SteppedUpdate(deltaTime: number)
    self:_produceUnits(deltaTime)
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

function Node:GetPivot()
    return self.Instance:GetPivot()
end

function Node:SendUnitsTo(node, unitCount: number)
    unitCount = math.min(unitCount, self.UnitCount:Get())
    unitCount = math.floor(unitCount)
    UnitGroupComponent.new(self, node, unitCount)
    self.UnitCount:Set(self.UnitCount:Get() - unitCount)
end

function Node:OwnedBy(player: Player)
    if self.Owner:Get() == nil then return false end
    return self.Owner:Get():IsMember(player)
end

function Node:_updateColor()
    self.Instance.Color =
        if self.Owner:Get() == nil
        then BrickColor.new("Dark stone grey").Color
        else self.Owner:Get().Color
end

function Node:_produceUnits(deltaTime: number)
    local newUnits = self.ProductionRate:Get() * deltaTime
    self.UnitCount:Set(self.UnitCount:Get() + newUnits)
end

function Node:_updateUnitCounter()
    self._instances.UnitCounter.Text = math.floor(self.UnitCount:Get())
end

return Node