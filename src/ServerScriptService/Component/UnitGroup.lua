local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Component = require(ReplicatedStorage.Packages.Component)
local ComponentExtensions = require(ReplicatedStorage.Packages.ComponentExtensions)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ValueObject = require(ReplicatedStorage.Packages.ValueObject)
local Waiter = require(ReplicatedStorage.Packages.Waiter)

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
    self.UnitCount:Set(unitCount)
    self.Owner:Set(startNode.Owner:Get())
    self:_pivotTo(startNode:GetPivot())
end

function UnitGroup:Construct()
    self.UnitCount = ValueObject.new(nil)
    self.MoveSpeed = ValueObject.new(1)
    self.Path = ValueObject.new(nil)
    self.Owner = ValueObject.new(nil)

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
end

function UnitGroup:Stop()
    self._trove:Clean()
end

function UnitGroup:GetPivot()
    return self.Instance:GetPivot()
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
        table.remove(path, 1)
        self.Path:Set(path)
        if #path ~= 0 then return end
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

return UnitGroup