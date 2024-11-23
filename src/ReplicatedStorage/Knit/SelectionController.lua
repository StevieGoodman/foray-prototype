local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ValueObject = require(ReplicatedStorage.Packages.ValueObject)

local NodeComponent = require(ReplicatedStorage.Component.Node)

local CAMERA = workspace.CurrentCamera
local SELECT_RADIUS_THRESHOLD = 1
local SELECTION_DOT_PRODUCT_THRESHOLD = 0.99
local SELECT_KEY = Enum.UserInputType.MouseButton1

local SelectionController = Knit.CreateController {
    Name = "Selection",
}

function SelectionController:KnitInit()
    self.SelectedNodes = ValueObject.Table.new()
    self.HoveredNode = ValueObject.Value.new(nil)

    self._hoveredTrove = Trove.new()
    self._selectedTroves = {}
end

function SelectionController:KnitStart()
    RunService.RenderStepped:Connect(function()
        self:_updateHoveredNode()
    end)
    ContextActionService:BindAction("StartSelection", function(_, inputState, _)
        if inputState ~= Enum.UserInputState.Begin then return end
        self:_startSelection()
    end, false, SELECT_KEY)

    self.SelectedNodes.Inserted:Connect(function(newSelectedNode)
        local newTrove = Trove.new()
        self._selectedTroves[newSelectedNode.Id] = newTrove
        self:_highlightNode(newSelectedNode, newTrove) -- Do not reorder this line! It cleans the trove passed into it!
        self:_bindSelectedNodeEvents(newSelectedNode, newTrove)
    end)
    self.SelectedNodes.Removed:Connect(function(oldSelectedNode)
        self._selectedTroves[oldSelectedNode.Id]:Clean()
        self._selectedTroves[oldSelectedNode.Id] = nil
    end)
    self.HoveredNode.Changed:Connect(function(hoveredNode)
        self:_highlightNode(hoveredNode, self._hoveredTrove)
    end)
end

function SelectionController:IsSelected(node)
    for _, selectedNode in self.SelectedNodes do
        if selectedNode.Id == node.Id then return true end
    end
    return false
end

function SelectionController:_updateHoveredNode()
    local ray = self:_getCursorRay()
    local bestNode = nil
    local nodes = NodeComponent:GetAll()
    for _, node in nodes do
        local nodeVector = (node:GetPivot().Position - ray.Origin).Unit
        local cursorVector = ray.Direction
        local dotProduct = nodeVector:Dot(cursorVector)
        if dotProduct < SELECTION_DOT_PRODUCT_THRESHOLD then continue end
        if bestNode ~= nil and bestNode.DotProduct > dotProduct then continue end
        bestNode = {
            DotProduct = dotProduct,
            Node = node,
        }
    end

    self.HoveredNode:Set(if bestNode == nil then nil else bestNode.Node)
end

function SelectionController:_startSelection()
    local initialPosition = self:_getCursorWorldPosition(self:_getCursorRay())
    if initialPosition == nil then return end

    local partTrove = Trove.new()
    local renderSteppedConnection = RunService.RenderStepped:Connect(function()
        partTrove:Clean()
        local currentPosition = self:_getCursorWorldPosition(self:_getCursorRay())
        if currentPosition == nil or currentPosition.Y ~= 0 then return end
        local radius = (currentPosition - initialPosition).Magnitude
        if radius < SELECT_RADIUS_THRESHOLD then return end
        self:_createSelectionCircle(initialPosition, radius, partTrove)
    end)
    UserInputService.InputEnded:Wait()
    partTrove:Clean()

    renderSteppedConnection:Disconnect()
    local endingPosition = self:_getCursorWorldPosition(self:_getCursorRay())
    if endingPosition == nil then return end
    local radius = (endingPosition - initialPosition).Magnitude

    local append = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
    if radius < SELECT_RADIUS_THRESHOLD then
        self:_trySelect(self.HoveredNode:Get(), append)
    else
        if not append then
            self.SelectedNodes:Clear()
        end
        local nodes = NodeComponent:GetAll()
        for _, node in nodes do
            local distance = (node:GetPivot().Position - initialPosition).Magnitude
            if distance > radius then continue end
            self:_trySelect(node, true)
        end
    end
end

function SelectionController:_trySelect(node, append: boolean?)
    if not append then
        self.SelectedNodes:Clear()
    end
    if self.SelectedNodes:Has(node) then return end
    local hasPermissionToSelect = node ~= nil and node.Owner:Get() ~= nil and node.Owner:Get().Name == Players.LocalPlayer.Team.Name
    if Players.LocalPlayer:HasTag("BypassesEnabled") or hasPermissionToSelect then
        self.SelectedNodes:Insert(node)
    end
end

function SelectionController:_createSelectionCircle(origin: Vector3, radius: number, trove)
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.Size = Vector3.new(0.1, radius * 2, radius * 2)
    part:PivotTo(CFrame.new(origin) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.new(0, 0, 0.05))
    part.Transparency = 0.75
    part.BrickColor = BrickColor.new("Institutional white")
    part.Shape = Enum.PartType.Cylinder
    part.Parent = workspace
    trove:Add(part)
end

function SelectionController:_highlightNode(node, trove)
    trove:Clean()
    if node == nil then return end
    if trove == self._hoveredTrove and self:IsSelected(node) then return end
    local highlight = Instance.new("Highlight")
    highlight.FillTransparency = if trove == self._hoveredTrove then 1 else 0.75
    highlight.OutlineTransparency = if trove == self._hoveredTrove then 0.5 else 0
    highlight.FillColor = Color3.new(1, 1, 1)
    highlight.Parent = node.Instance
    trove:Add(highlight)
end

function SelectionController:_bindSelectedNodeEvents(node, trove)
    if node == nil then return end
    trove:Add(node.Owner.Changed:Connect(function(newOwner)
        if newOwner:IsMember() then return end
        local index = self.SelectedNodes:Find(node)
        self.SelectedNodes:Remove(index)
    end))
    trove:Add(Players.LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function()
        if node.Owner:Get():IsMember() then return end
        local index = self.SelectedNodes:Find(node)
        self.SelectedNodes:Remove(index)
    end))
end

function SelectionController:_getCursorRay(): Ray
    local cursorPosition = UserInputService:GetMouseLocation()
    return CAMERA:ViewportPointToRay(cursorPosition.X, cursorPosition.Y)
end

function SelectionController:_getCursorWorldPosition(ray: Ray): Vector3?
    if ray.Direction.Y == 0 then return nil end -- Prevent division by zero (parallel)
    local t = ray.Origin.Y / -ray.Direction.Y -- t = how many rays to travel to reach the ground
    if t < 0 then return nil end -- Prevent selection below the ground
    local intersectionPoint = ray.Origin + ray.Direction * t
    intersectionPoint = Vector3.new(intersectionPoint.X, 0, intersectionPoint.Z)
    return intersectionPoint
end

return SelectionController