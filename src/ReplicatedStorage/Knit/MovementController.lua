local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local SelectionController

local MovementController = Knit.CreateController {
    Name = "Movement",
}

function MovementController:KnitInit()
    SelectionController = Knit.GetController("Selection")
end

function MovementController:KnitStart()
    ContextActionService:BindAction(
        "TrySendUnits",
        function(_, inputState: Enum.UserInputState, inputObject: InputObject)
            if inputState ~= Enum.UserInputState.Begin then return end
            self:_trySendUnits(self:_keyCodeToUnitCount(inputObject.KeyCode))
        end,
        false,
        Enum.KeyCode.Q,
        Enum.KeyCode.E,
        Enum.KeyCode.R,
        Enum.KeyCode.F)
end

function MovementController:_trySendUnits(unitCount: number)
    local selectedNodes = SelectionController.SelectedNodes:Get()
    local hoveredNode = SelectionController.HoveredNode:Get()
    if #selectedNodes == 0 or hoveredNode == nil or SelectionController.SelectedNodes:Has(hoveredNode) then return end
    for _, selectedNode in selectedNodes do
        selectedNode.SendUnitsTo(hoveredNode.Id, unitCount)
    end
end

function MovementController:_keyCodeToUnitCount(keyCode)
    if keyCode == Enum.KeyCode.Q then return 26 end
    if keyCode == Enum.KeyCode.E then return 501 end
    if keyCode == Enum.KeyCode.R then return 2501 end
    if keyCode == Enum.KeyCode.F then return math.huge end
    return 0
end

return MovementController