local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Comm = require(ReplicatedStorage.Packages.Comm)
local Component = require(ReplicatedStorage.Packages.Component)
local ComponentExtensions = require(ReplicatedStorage.Packages.ComponentExtensions)
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