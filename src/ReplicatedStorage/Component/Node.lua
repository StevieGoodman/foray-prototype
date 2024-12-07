local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Comm = require(ReplicatedStorage.Packages.Comm)
local Component = require(ReplicatedStorage.Packages.Component)
local ComponentExtensions = require(ReplicatedStorage.Packages.ComponentExtensions)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ValueObject = require(ReplicatedStorage.Packages.ValueObject)
local Waiter = require(ReplicatedStorage.Packages.Waiter)

local RoundComponent = require(ReplicatedStorage.Component.Round)
local TeamComponent = require(ReplicatedStorage.Component.Team)

local Node = Component.new {
    Tag = "Node",
    Ancestors = { workspace },
    Extensions = {
        ComponentExtensions.IsClass("BasePart"),
        ComponentExtensions.RequiresComponent(RoundComponent, Waiter.ancestors),
    },
}

function Node:Construct()
    self._comm = Comm.ClientComm.new(self.Instance, true, self.Tag)
    self.SendUnitsTo = self._comm:GetFunction("SendUnitsTo")
    self.Upgrade = self._comm:GetFunction("Upgrade")
    self._properties = {
        Id = self._comm:GetProperty("Id"),
        Owner = self._comm:GetProperty("Owner"),
    }
    self._properties.Id:OnReady():await()

    self.Id = self._properties.Id:Get()
    self.Owner = ValueObject.Value.new(self._properties.Owner:Get())

    self._trove = Trove.new()
    self._trove:Add(self._comm)
    self._trove:Add(self.Owner)

    self._components.Round:RegisterNode(self)
end

function Node:Start()
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