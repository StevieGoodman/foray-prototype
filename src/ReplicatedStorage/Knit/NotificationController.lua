local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local NotificationService

local NotificationController = Knit.CreateController {
    Name = "Notification",
}

function NotificationController:KnitInit()
    NotificationService = Knit.GetService("Notification")

    self._systemChannel = TextChatService.TextChannels.RBXSystem
end

function NotificationController:KnitStart()
    NotificationService.NewNotification:Connect(function(message)
        self:Notify(`<b>{message}</b>`)
    end)
end

function NotificationController:Notify(message: string)
    self._systemChannel:DisplaySystemMessage(message)
end

return NotificationController