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
local SELECTION_DOT_PRODUCT_THRESHOLD = 0.99
local SELECT_KEY = Enum.UserInputType.MouseButton1

local SelectionController = Knit.CreateController {
    Name = "Selection",
}

function SelectionController:KnitInit()
    self.SelectedNode = ValueObject.new(nil)
    self.HoveredNode = ValueObject.new(nil)

    self._selectedHighlightTrove = Trove.new()
    self._hoveredHighlightTrove = Trove.new()

    self._selectedEventTrove = Trove.new()
end

function SelectionController:KnitStart()
    RunService.RenderStepped:Connect(function()
        self:CalculateHoveredNode()
    end)
    ContextActionService:BindAction("Select", function(_, inputState, _)
        if inputState ~= Enum.UserInputState.Begin then return end
        self:_select()
    end, false, SELECT_KEY)

    self.SelectedNode.Changed:Connect(function(selectedNode)
        self:_highlightNode(selectedNode, self._selectedHighlightTrove)
        self:_bindSelectedNodeEvents(selectedNode)
    end)
    self.HoveredNode.Changed:Connect(function(hoveredNode)
        self:_highlightNode(hoveredNode, self._hoveredHighlightTrove)
    end)
end

function SelectionController:CalculateHoveredNode()
    local cursorPosition = UserInputService:GetMouseLocation()
    local ray = CAMERA:ViewportPointToRay(cursorPosition.X, cursorPosition.Y)

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

function SelectionController:_select()
    if self.HoveredNode:Get() == nil
    or self.HoveredNode:Get().Owner:Get() == nil
    or self.HoveredNode:Get().Owner:Get().Name ~= Players.LocalPlayer.Team.Name then
        self.SelectedNode:Set(nil)
    else
        self.SelectedNode:Set(self.HoveredNode:Get())
    end
end

function SelectionController:_highlightNode(node, trove)
    trove:Clean()
    if node == nil then return end
    if trove == self._hoveredHighlightTrove and
        self.SelectedNode:Get() ~= nil and
        node.Id == self.SelectedNode:Get().Id
        then return end
    local highlight = Instance.new("Highlight")
    highlight.FillTransparency = if trove == self._selectedHighlightTrove then 0.75 else 1
    highlight.OutlineTransparency = if trove == self._selectedHighlightTrove then 0 else 0.5
    highlight.FillColor = Color3.new(1, 1, 1)
    highlight.Parent = node.Instance
    trove:Add(highlight)
end

function SelectionController:_bindSelectedNodeEvents(node)
    self._selectedEventTrove:Clean()
    if node == nil then return end
    self._selectedEventTrove:Add(node.Owner.Changed:Connect(function(newOwner)
        if newOwner:IsMember() then return end
        self.SelectedNode:Set(nil)
    end))
    self._selectedEventTrove:Add(Players.LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function()
        if node.Owner:Get():IsMember() then return end
        self.SelectedNode:Set(nil)
    end))
end

return SelectionController