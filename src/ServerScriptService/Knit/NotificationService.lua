local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local NotificationService = Knit.CreateService {
    Name = "Notification",
    Client = {
        NewNotification = Knit.CreateSignal(),
    }
}

function NotificationService:NotifyAll(message: string)
    self.Client.NewNotification:FireAll(message)
end

function NotificationService:Notify(players: Player | {Players}, message: string)
    if typeof(players) ~= table then
        players = {players}
    end
    self.Client.NewNotification:FireFor(players, message)
end

return NotificationService