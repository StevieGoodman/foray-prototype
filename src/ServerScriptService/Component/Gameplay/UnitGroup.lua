local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Component = require(ReplicatedStorage.Packages.Component)
local ComponentExtensions = require(ReplicatedStorage.Packages.ComponentExtensions)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ValueObject = require(ReplicatedStorage.Packages.ValueObject)
local Waiter = require(ReplicatedStorage.Packages.Waiter)

local COLLISION_DISTANCE = 0.25
local QUERY_COLLISION_GROUP = "Unit Group Query"
local TEMPLATE_UNIT_GROUP = Waiter.getFirst(Waiter.descendants(ReplicatedStorage.Assets), Waiter.matchTag("UnitGroup"))
assert(TEMPLATE_UNIT_GROUP ~= nil, "UnitGroup template not found")

local UnitGroup = Component.new {
    Tag = "UnitGroup",
    Ancestors = { workspace },
    Extensions = {
        ComponentExtensions.IsClass("BasePart"),
        ComponentExtensions.RequiresInstance("UnitCounter", Waiter.descendants, Waiter.matchTag),
    },
}

function UnitGroup.new(startNode, endNode, unitCount)
    local path = startNode:CalculatePath(endNode)
    if path == nil then return end
    local self = TEMPLATE_UNIT_GROUP:Clone()
    self.Parent = startNode.Round:GetFolder("Unit Groups")
    local success, result = UnitGroup:WaitForInstance(self):await()
    assert(success, result)
    self = result
    self.Path:Set(path)
    self.PreviousNode:Set(startNode)
    self.UnitCount:Set(unitCount)
    self.Owner:Set(startNode.Owner:Get())
    self:_pivotTo(startNode:GetPivot())
end

function UnitGroup:Construct()
    self.UnitCount = ValueObject.Value.new(nil)
    self.MoveSpeed = ValueObject.Value.new(1)
    self.Path = ValueObject.Value.new(nil)
    self.PreviousNode = ValueObject.Value.new(nil)
    self.Owner = ValueObject.Value.new(nil)

    self._trove = Trove.new()
    self._trove:Add(self.Path)
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
    self._trove:Add(self.Owner.Changed:Connect(function(_)
        self:_updateColor()
    end))
end

function UnitGroup:SteppedUpdate(deltaTime: number)
    self:_moveTowardsNextNode(deltaTime)
    self:_queryForUnitGroups()
end

function UnitGroup:Stop()
    self._trove:Clean()
end

function UnitGroup:GetPivot()
    return self.Instance:GetPivot()
end

function UnitGroup:Retreat()
    local newPreviousNode = self.Path:Get()[1]
    self.Path:Set({self.PreviousNode:Get()})
    self.PreviousNode:Set(newPreviousNode)
end

function UnitGroup:_moveTowardsNextNode(deltaTime: number)
    if self.Path:Get() == nil or self.Path:Get()[1] == nil then return end
    local currentPivot = self:GetPivot()
    local nextNode = self.Path:Get()[1]
    local nextNodePivot = nextNode:GetPivot()
    local distance = (nextNodePivot.Position - currentPivot.Position).Magnitude
    local distanceTravelled = math.min(self.MoveSpeed:Get() * deltaTime, distance)
    local remainingDistance = distance - distanceTravelled
    if remainingDistance <= 0 then
        local path = self.Path:Get()
        local previousNode = table.remove(path, 1)
        self.PreviousNode:Set(previousNode)
        self.Path:Set(path)
        if #path ~= 0 and nextNode.Owner:Get().Name == self.Owner:Get().Name then return end
        self:_enterNode(nextNode)
    else
        local newPivot = currentPivot:Lerp(nextNodePivot, distanceTravelled / distance)
        self:_pivotTo(newPivot)
    end
end

function UnitGroup:_enterNode(node)
    node:GiveUnits(self.UnitCount:Get(), self.Owner:Get())
    self.Instance:Destroy()
end

function UnitGroup:_pivotTo(cframe: CFrame)
    self.Instance:PivotTo(cframe)
end

function UnitGroup:_updateColor()
    self.Instance.Color =
        if self.Owner:Get() == nil
        then BrickColor.new("Dark stone grey").Color
        else self.Owner:Get().Color
end

function UnitGroup:_getDistanceToNextNode()
    return (self.Path:Get()[1]:GetPivot().Position - self:GetPivot().Position).Magnitude
end

function UnitGroup:_onCollision(otherUnitGroup)
    local sameOwner = self.Owner:Get() == otherUnitGroup.Owner:Get()
    local closerToNextNode = self:_getDistanceToNextNode() < otherUnitGroup:_getDistanceToNextNode()
    local hasMoreUnits = self.UnitCount:Get() > otherUnitGroup.UnitCount:Get()
    local hasSameDestinationNode = self.Path:Get()[#self.Path:Get()] == otherUnitGroup.Path:Get()[#otherUnitGroup.Path:Get()]
    local headingInOppositeDirections = self.Path:Get()[1] == otherUnitGroup.PreviousNode:Get()
    if sameOwner and closerToNextNode and hasSameDestinationNode then
        self.UnitCount:Set(self.UnitCount:Get() + otherUnitGroup.UnitCount:Get())
        otherUnitGroup.Instance:Destroy()
    elseif not sameOwner and not hasMoreUnits and headingInOppositeDirections then
        self:Retreat()
    end
end

function UnitGroup:_queryForUnitGroups()
    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    overlapParams:AddToFilter(self.Instance)
    overlapParams.CollisionGroup = QUERY_COLLISION_GROUP
    local unitGroups = workspace:GetPartBoundsInRadius(self:GetPivot().Position, COLLISION_DISTANCE, overlapParams)
    for _, unitGroup in unitGroups do
        unitGroup = UnitGroup:FromInstance(unitGroup)
        if unitGroup == nil then continue end
        self:_onCollision(unitGroup)
    end
end

return UnitGroup