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

function Team.new(name: string, brickColor: BrickColor)
    local team = Instance.new("Team")
    team.Name = name
    team.TeamColor = brickColor
    team.AutoAssignable = true
    team:AddTag("Team")
    team.Parent = Teams
    return Team:WaitForInstance(team)
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

function Team:AddMember(player: Player)
    player.Team = self.Team
end

function Team:RemoveMember(player: Player)
    player.Team = nil
end

function Team:IsMember(player: Player)
    return player.Team == self.Team
end

Team.new("Red", BrickColor.new("Bright red"))
Team.new("Blue", BrickColor.new("Bright blue"))
Team.new("Green", BrickColor.new("Bright green"))
Team.new("Yellow", BrickColor.new("Bright yellow"))

return Team