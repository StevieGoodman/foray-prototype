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

local Node = Component.new {
    Tag = "Node",
    Ancestors = { workspace },
    Extensions = {
        ComponentExtensions.IsClass("BasePart"),
        ComponentExtensions.RequiresInstance("UnitCounter", Waiter.descendants, Waiter.matchTag)
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

    self._comm = Comm.ServerComm.new(self.Instance, self.Tag)
    self._comm:BindFunction("SendUnitsTo", function(_, nodeId, unitCount)
        local node = Node.FromId(nodeId)
        if node == nil then return end
        self:SendUnitsTo(node, unitCount)
    end)
    self._properties = {
        Id = self._comm:CreateProperty("Id", self.Id),
        UnitCount = self._comm:CreateProperty("UnitCount", self.UnitCount),
    }

    self._trove = Trove.new()
    self._trove:Add(self.UnitCount)
end

function Node:Start()
    self._trove:Add(self.UnitCount.Changed:Connect(function(newUnitCount)
        self._properties.UnitCount:Set(newUnitCount)
        self:_updateUnitCounter()
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
    local queue = table.clone(distances)
    while #queue ~= 0 do
        local currentNodeId = TableUtil.Reduce(TableUtil.Keys(queue), function(a, b)
            return if distances[a] < distances[b] then a else b
        end)
        local currentNode = Node.FromId(currentNodeId)
        queue[currentNodeId] = nil
        local currentDistanceTravelled = distances[currentNodeId]
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

function Node:_produceUnits(deltaTime: number)
    local newUnits = self.ProductionRate:Get() * deltaTime
    self.UnitCount:Set(self.UnitCount:Get() + newUnits)
end

function Node:_updateUnitCounter()
    self._instances.UnitCounter.Text = math.floor(self.UnitCount:Get())
end

return Node