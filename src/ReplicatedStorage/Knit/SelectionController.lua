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
    self.SelectedNodes = ValueObject.Table.new()
    self.HoveredNode = ValueObject.Value.new(nil)

    self._hoveredTrove = Trove.new()
    self._selectedTroves = {}
end

function SelectionController:KnitStart()
    RunService.RenderStepped:Connect(function()
        self:CalculateHoveredNode()
    end)
    ContextActionService:BindAction("Select", function(_, inputState, _)
        if inputState ~= Enum.UserInputState.Begin then return end
        self:_select()
    end, false, SELECT_KEY)

    self.SelectedNodes.Inserted:Connect(function(newSelectedNode)
        local newTrove = Trove.new()
        self._selectedTroves[newSelectedNode.Id] = newTrove
        self:_highlightNode(newSelectedNode, newTrove) -- Do not reorder this line! It cleans the trove passed into it!
        self:_bindSelectedNodeEvents(newSelectedNode, newTrove)
    end)
    self.SelectedNodes.Removed:Connect(function(oldSelectedNode)
        print("Deselected", oldSelectedNode)
        self._selectedTroves[oldSelectedNode.Id]:Clean()
        self._selectedTroves[oldSelectedNode.Id] = nil
    end)
    self.HoveredNode.Changed:Connect(function(hoveredNode)
        self:_highlightNode(hoveredNode, self._hoveredTrove)
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
    if not Players.LocalPlayer:HasTag("BypassesEnabled")
    and (self.HoveredNode:Get() == nil
    or self.HoveredNode:Get().Owner:Get() == nil
    or self.HoveredNode:Get().Owner:Get().Name ~= Players.LocalPlayer.Team.Name) then
        self.SelectedNodes:Clear()
    else
        local append = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
        if append then
            self.SelectedNodes:Insert(self.HoveredNode:Get())
        else
            self.SelectedNodes:Set({self.HoveredNode:Get()})
        end
    end
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

function SelectionController:IsSelected(node)
    for _, selectedNode in self.SelectedNodes do
        if selectedNode.Id == node.Id then return true end
    end
    return false
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

return SelectionController