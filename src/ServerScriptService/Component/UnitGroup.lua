local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Component = require(ReplicatedStorage.Packages.Component)
local ComponentExtensions = require(ReplicatedStorage.Packages.ComponentExtensions)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ValueObject = require(ReplicatedStorage.Packages.ValueObject)
local Waiter = require(ReplicatedStorage.Packages.Waiter)

local TEMPLATE_UNIT_GROUP = Waiter.getFirst(Waiter.descendants(ReplicatedStorage.Assets), Waiter.matchTag("UnitGroup"))
assert(TEMPLATE_UNIT_GROUP ~= nil, "UnitGroup template not found")

local UNIT_GROUP_FOLDER = Instance.new("Folder")
UNIT_GROUP_FOLDER.Name = "Unit Groups"
UNIT_GROUP_FOLDER.Parent = workspace

local UnitGroup = Component.new {
    Tag = "UnitGroup",
    Ancestors = { workspace },
    Extensions = {
        ComponentExtensions.IsClass("BasePart"),
        ComponentExtensions.RequiresInstance("UnitCounter", Waiter.descendants, Waiter.matchTag),
    },
}

function UnitGroup.new(startNode, endNode, unitCount)
    local self = TEMPLATE_UNIT_GROUP:Clone()
    self.Parent = UNIT_GROUP_FOLDER
    local success, result = UnitGroup:WaitForInstance(self):await()
    assert(success, result)
    self = result
    self.StartNode:Set(startNode)
    self.EndNode:Set(endNode)
    self.UnitCount:Set(unitCount)
    self:PivotTo(startNode:GetPivot())
end

function UnitGroup:Construct()
    self.StartNode = ValueObject.new(nil)
    self.EndNode = ValueObject.new(nil)
    self.UnitCount = ValueObject.new(nil)
    self.MoveSpeed = ValueObject.new(1)

    self._trove = Trove.new()
    self._trove:Add(self.StartNode)
    self._trove:Add(self.EndNode)
    self._trove:Add(self.UnitCount)
    self._trove:Add(self.MoveSpeed)
end

function UnitGroup:Start()
    self._trove:Add(self.UnitCount.Changed:Connect(function(newUnitCount)
        if self.UnitCount:Get() <= 0 then
            self.Instance:Destroy()
        else
            self._instances.UnitCounter.Text = newUnitCount
        end
    end))
end

function UnitGroup:SteppedUpdate(deltaTime: number)
    self:_moveTowardsEndNode(deltaTime)
end

function UnitGroup:Stop()
    self._trove:Clean()
end

function UnitGroup:GetPivot()
    return self.Instance:GetPivot()
end

function UnitGroup:PivotTo(cframe: CFrame)
    self.Instance:PivotTo(cframe)
end

function UnitGroup:_moveTowardsEndNode(deltaTime: number)
    local currentPivot = self:GetPivot()
    local endNodePivot = self.EndNode:Get():GetPivot()
    local distance = (endNodePivot.Position - currentPivot.Position).Magnitude
    local distanceTravelled = self.MoveSpeed:Get() * deltaTime
    local remainingDistance = distance - distanceTravelled
    if remainingDistance <= 0 then
        self:_enterNode(self.EndNode:Get())
    else
        local newPivot = currentPivot:Lerp(endNodePivot, distanceTravelled / distance)
        self:PivotTo(newPivot)
    end
end

function UnitGroup:_enterNode(node)
    local unitCount = self.UnitCount:Get()
    local nodeUnitCount = node.UnitCount:Get()
    node.UnitCount:Set(nodeUnitCount + unitCount)
    self.Instance:Destroy()
end

return UnitGroup