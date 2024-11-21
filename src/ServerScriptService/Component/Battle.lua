local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Component = require(ReplicatedStorage.Packages.Component)
local ComponentExtensions = require(ReplicatedStorage.Packages.ComponentExtensions)
local Trove = require(ReplicatedStorage.Packages.Trove)

local NodeComponent = require(ServerScriptService.Component.Node)
local TeamComponent = require(ServerScriptService.Component.Team)

local COMBAT_MULTIPLIER = 0.1
local MIN_CASUALITY_COUNT = 4

local Battle = Component.new {
    Tag = "Battle",
    Ancestors = { workspace },
    Extensions = {
        ComponentExtensions.RequiresComponent(NodeComponent)
    },
}

function Battle:Construct()
    self._trove = Trove.new()
end

function Battle:Start()

end

function Battle:SteppedUpdate(deltaTime: number)
    self:_increment(deltaTime)
end

function Battle:Stop()
    self._trove:Clean()
end

function Battle:_increment(deltaTime: number)
    local casualties = {}
    for teamName, unitCount in self._components.Node._unitCounts do
        if unitCount:Get() == 0 then continue end
        local enemyCount = 0
        for enemyName, enemyUnitCount in self._components.Node._unitCounts do
            if enemyName == teamName then continue end
            if enemyUnitCount:Get() == 0 then continue end
            enemyCount += enemyUnitCount:Get()
        end
        casualties[teamName] = (casualties[teamName] or 0) + enemyCount * COMBAT_MULTIPLIER * deltaTime
    end
    for teamName, casualtyCount in casualties do
        if 0 < casualtyCount and casualtyCount < MIN_CASUALITY_COUNT * deltaTime then
            casualtyCount = MIN_CASUALITY_COUNT * deltaTime
        end
        self._components.Node:TakeUnits(casualtyCount, TeamComponent.FromName(teamName), false)
    end
end

return Battle