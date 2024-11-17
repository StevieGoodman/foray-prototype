local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Component = require(ReplicatedStorage.Packages.Component)
local ValueObject = require(ReplicatedStorage.Packages.ValueObject)
local Waiter = require(ReplicatedStorage.Packages.Waiter)

local Round = Component.new {
    Tag = "Round",
    Ancestors = { workspace },
}

Round.IdCounter = 1

function Round.new(mapName: string)
    local mapTemplate =
        Waiter.getFirst(
            Waiter.descendants(ServerStorage.Maps),
            Waiter.matchQuery({
                Name = mapName,
                Tag = "Map",
            }))
    assert(mapTemplate ~= nil, `Map template "{mapName}" not found`)
    local self = mapTemplate:Clone()
    self:RemoveTag("Map")
    self:AddTag(Round.Tag)
    self.Parent = workspace
    return Round:WaitForInstance(self)
end

function Round:Construct()
    self.MapName = self.Instance.Name
    self.Id = Round.IdCounter
    Round.IdCounter = Round.IdCounter + 1
    self.Instance.Name = `Round {self.Id} ({self.MapName})`
    self._folders = ValueObject.new({})
end

function Round:End()
    self.Instance:Destroy()
end

function Round:Reset()
    self:Destroy()
    return Round.new(self.Name)
end

function Round:GetFolder(name)
    local folders = self._folders:Get()
    local folder = folders[name]
    if folder == nil then
        folder = Instance.new("Folder")
        folder.Name = name
        folder.Parent = self.Instance
        folders[name] = folder
    end
    return folder
end

Round.new("Testing Map")

return Round