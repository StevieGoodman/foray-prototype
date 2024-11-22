local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local SelectionController

local UpgradeController = Knit.CreateController {
    Name = "Upgrade",
}

function UpgradeController:KnitInit()
    SelectionController = Knit.GetController("Selection")
end

function UpgradeController:KnitStart()
    ContextActionService:BindAction(
        "Upgrade",
        function(_, inputState: Enum.UserInputState, inputObject: InputObject)
            if inputState ~= Enum.UserInputState.Begin then return end
            self:_upgrade(self:_keyCodeToUpgradeName(inputObject.KeyCode))
        end,
        false,
        Enum.KeyCode.One,
        Enum.KeyCode.Two--,
        --Enum.KeyCode.Three,
        --Enum.KeyCode.Four
        )
end

function UpgradeController:_upgrade(upgradeName: string)
    local hoveredNode = SelectionController.HoveredNode:Get()
    if hoveredNode == nil then return end
    hoveredNode.Upgrade(upgradeName)
end

function UpgradeController:_keyCodeToUpgradeName(keyCode)
    if keyCode == Enum.KeyCode.One then return "Factory" end
    if keyCode == Enum.KeyCode.Two then return "Powerplant" end
    if keyCode == Enum.KeyCode.Three then return "Fort" end
    if keyCode == Enum.KeyCode.Four then return "Artillery" end
    return nil
end

return UpgradeController