local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ValueObject = require(ReplicatedStorage.Packages.ValueObject)

local CAMERA = workspace.CurrentCamera
local CAMERA_ROTATION_OFFSET = CFrame.Angles(-math.rad(90), 0, 0)
local MAX_CAMERA_DISPLACEMENT = 128 / 2
local MIN_MOVE_SPEED = 8
local MAX_MOVE_SPEED = 48
local ZOOM_SPEED = 2
local MIN_HEIGHT = 5
local MAX_HEIGHT = 50
local MOVE_BINDINGS = {
    W = Vector2.new(0, -1),
    A = Vector2.new(-1, 0),
    S = Vector2.new(0, 1),
    D = Vector2.new(1, 0),
}

local CameraController = Knit.CreateController {
    Name = "Camera",
}

function CameraController:KnitInit()
    self.CameraPosition = ValueObject.Value.new(Vector2.new(0, 0))
    self.CameraHeight = ValueObject.Value.new(10)
    self.MoveDirection = ValueObject.Value.new(Vector2.new(0, 0))
end

function CameraController:KnitStart()
    CAMERA.CameraType = Enum.CameraType.Scriptable
    RunService:BindToRenderStep("CameraController", Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
        self:_updateCameraCFrame(deltaTime)
    end)
    UserInputService.InputBegan:Connect(function(inputObject: InputObject)
        if inputObject.UserInputType ~= Enum.UserInputType.Keyboard then return end
        local direction = MOVE_BINDINGS[inputObject.KeyCode.Name:upper()] or Vector2.new(0, 0)
        self.MoveDirection:Set(self.MoveDirection:Get() + direction)
        local connection
        connection = inputObject.Changed:Connect(function(property)
            if property == "UserInputState" and inputObject.UserInputState == Enum.UserInputState.End then
                self.MoveDirection:Set(self.MoveDirection:Get() - direction)
                connection:Disconnect()
            end
        end)
    end)
    UserInputService.InputChanged:Connect(function(inputObject: InputObject)
        if inputObject.UserInputType == Enum.UserInputType.MouseWheel then
            local newHeight = self.CameraHeight:Get() + inputObject.Position.Z * ZOOM_SPEED
            self.CameraHeight:Set(math.clamp(newHeight, MIN_HEIGHT, MAX_HEIGHT))
        end
    end)
end

function CameraController:_updateCameraCFrame(deltaTime: number)
    local moveSpeedLerpValue = (self.CameraHeight:Get() - MIN_HEIGHT) / (MAX_HEIGHT - MIN_HEIGHT)
    local moveSpeed = MIN_MOVE_SPEED + (MAX_MOVE_SPEED - MIN_MOVE_SPEED) * moveSpeedLerpValue
    local positionIncrement =
        if self.MoveDirection:Get() == Vector2.new(0, 0)
        then Vector2.new(0, 0)
        else self.MoveDirection:Get().Unit * moveSpeed * deltaTime
    local newPosition = self.CameraPosition:Get() + positionIncrement
    if newPosition.Magnitude ~= 0 then
        newPosition = newPosition.Unit * math.min(newPosition.Magnitude, MAX_CAMERA_DISPLACEMENT)
    end
    self.CameraPosition:Set(newPosition)
    CAMERA.CFrame = CFrame.new(
        self.CameraPosition:Get().X,
        self.CameraHeight:Get(),
        self.CameraPosition:Get().Y
    ) * CAMERA_ROTATION_OFFSET
end

function CameraController:_incrementPosition()
    RunService:UnbindFromRenderStep("CameraController")
end

return CameraController