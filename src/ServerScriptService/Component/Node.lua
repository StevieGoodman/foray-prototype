local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

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

function Node:Construct()
    self.ProductionRate = ValueObject.new(1)
    self.UnitCount = ValueObject.new(0)
    self.Edges = ValueObject.new({})

    self._trove = Trove.new()
    self._trove:Add(self.UnitCount)
end

function Node:Start()
    self._trove:Add(self.UnitCount.Changed:Connect(function()
        self:_updateUnitCounter()
    end))
    self._trove:Add(self.Edges.Changed:Connect(function(edges)
        task.wait(5)
        for _, edge in edges do
            print("Sending units to edge")
            self:SendUnitsTo(edge:GetConnectedNode(self), math.random() * self.UnitCount:Get())
        end
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
    unitCount = math.floor(unitCount)
    assert(self.UnitCount:Get() >= unitCount, `Cannot send more units than are available! ({self.Instance:GetFullName()})`)
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