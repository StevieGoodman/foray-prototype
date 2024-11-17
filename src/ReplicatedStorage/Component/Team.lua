local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Component = require(ReplicatedStorage.Packages.Component)
local ComponentExtensions = require(ReplicatedStorage.Packages.ComponentExtensions)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ValueObject = require(ReplicatedStorage.Packages.ValueObject)

local Team = Component.new {
    Tag = "Team",
    Ancestors = { Teams },
    Extensions = {
        ComponentExtensions.IsClass("Team"),
    },
}

function Team.FromName(name: string)
    local teams = Team:GetAll()
    for _, team in teams do
        if team.Name ~= name then continue end
        return team
    end
end

function Team:Construct()
    self.Team = self.Instance :: Team
    self.Name = self.Team.Name
    self.Members = ValueObject.new({})
    self.Color = self.Team.TeamColor.Color

    self._trove = Trove.new()
end

function Team:Start()
    self.Team.PlayerAdded:Connect(function(player)
        local members = self.Members:Get()
        table.insert(members, player)
        self.Members:Set(members)
    end)
    self.Team.PlayerRemoved:Connect(function(player)
        local members = self.Members:Get()
        local index = table.find(members, player)
        if index == nil then return end
        table.remove(members, index)
        self.Members:Set(members)
    end)
end

function Team:Stop()
    self._trove:Clean()
end

function Team:IsMember(player: Player?)
    player = player or Players.LocalPlayer
    return player.Team == self.Team
end

return Team