local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Comm = require(ReplicatedStorage.Packages.Comm)
local Component = require(ReplicatedStorage.Packages.Component)
local ComponentExtensions = require(ReplicatedStorage.Packages.ComponentExtensions)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ValueObject = require(ReplicatedStorage.Packages.ValueObject)

local TeamComponent = require(ReplicatedStorage.Component.Team)

local Node = Component.new {
    Tag = "Node",
    Ancestors = { workspace },
    Extensions = {
        ComponentExtensions.IsClass("BasePart"),
    },
}

function Node:Construct()
    self._comm = Comm.ClientComm.new(self.Instance, true, self.Tag)
    self.SendUnitsTo = self._comm:GetFunction("SendUnitsTo")
    self._properties = {
        Id = self._comm:GetProperty("Id"),
        UnitCount = self._comm:GetProperty("UnitCount"),
        Owner = self._comm:GetProperty("Owner"),
    }
    self._properties.Id:OnReady():await()
    self._properties.UnitCount:OnReady():await()

    self.Id = self._properties.Id:Get()
    self.UnitCount = ValueObject.new(self._properties.UnitCount:Get())
    self.Owner = ValueObject.new(self._properties.Owner:Get())

    self._trove = Trove.new()
end

function Node:Start()
    self._trove:Add(self._properties.UnitCount:Observe(function(newUnitCount)
        self.UnitCount:Set(newUnitCount)
    end))
    self._trove:Add(self._properties.Owner:Observe(function(newOwner)
        self.Owner:Set(TeamComponent.FromName(newOwner))
    end))
end

function Node:Stop()
    self._trove:Clean()
end

function Node:GetPivot()
    return self.Instance:GetPivot()
end

return Node