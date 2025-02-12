local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Component = require(ReplicatedStorage.Packages.Component)
local ComponentExtensions = require(ReplicatedStorage.Packages.ComponentExtensions)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Trove = require(ReplicatedStorage.Packages.Trove)

local NodeComponent = require(ServerScriptService.Component.Gameplay.Node)

local Edge = Component.new {
    Tag = "Edge",
    Ancestors = { workspace },
    Extensions = {
        ComponentExtensions.IsClass("Beam"),
        { ShouldConstruct = function(self)
            assert(self.Instance.Attachment0 ~= nil, `Edges must have a Attachment0 ({self.Instance:GetFullName()})`)
            assert(self.Instance.Attachment1 ~= nil, `Edges must have a Attachment1 ({self.Instance:GetFullName()})`)
            return true
        end },
        { ShouldConstruct = function(self)
            local promises = {}
            table.insert(promises, NodeComponent:WaitForInstance(self.Instance.Attachment0.Parent))
            table.insert(promises, NodeComponent:WaitForInstance(self.Instance.Attachment1.Parent))
            local success, result = Promise.all(promises):await()
            assert(success, result)
            return true
        end }
    },
}

function Edge:Construct()
    self.Instance = self.Instance :: Beam
    self.Length = (self.Instance.Attachment0.WorldPosition - self.Instance.Attachment1.WorldPosition).Magnitude

    self._nodes = {
        NodeComponent:FromInstance(self.Instance.Attachment0.Parent),
        NodeComponent:FromInstance(self.Instance.Attachment1.Parent),
    }

    self._trove = Trove.new()
end

function Edge:Start()
    self.Instance.Name = `Edge ({self._nodes[1].Id} ↔︎ {self._nodes[2].Id})`
    self:_register()

    for _, node in self._nodes do
        self:_updateBeamColor(node)
        self._trove:Add(node.Instance:GetPropertyChangedSignal("Color"):Connect(function(_newColor)
            self:_updateBeamColor()
        end))
    end
end

function Edge:Stop()
    self._trove:Clean()
end

function Edge:GetConnectedNode(currentNode): table
    assert(table.find(self._nodes, currentNode) ~= nil, `Cannot get connected node from a node that is not connected to this edge! ({currentNode.Instance:GetFullName()})`)
    return
        if self._nodes[1].Id == currentNode.Id
        then self._nodes[2]
        else self._nodes[1]
end

function Edge:_register()
    for _, node in self._nodes do
        local edges = node.Edges:Get()
        table.insert(edges, self)
        node.Edges:Set(edges)
    end
end

function Edge:_updateBeamColor()
    local colorSequence = ColorSequence.new{
        ColorSequenceKeypoint.new(0, self._nodes[1].Instance.Color),
        ColorSequenceKeypoint.new(1, self._nodes[2].Instance.Color),
    }
    self.Instance.Color = colorSequence
end

return Edge