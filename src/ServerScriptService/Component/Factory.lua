local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Component = require(ReplicatedStorage.Packages.Component)
local ComponentExtensions = require(ReplicatedStorage.Packages.ComponentExtensions)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ValueObject = require(ReplicatedStorage.Packages.ValueObject)

local NodeComponent = require(ServerScriptService.Component.Node)

local DEFAULT_PRODUCTION_RATE = 4

local Factory = Component.new {
    Tag = "Factory",
    Ancestors = { workspace },
    Extensions = {
        ComponentExtensions.RequiresComponent(NodeComponent),
    },
}

function Factory:Construct()
    self._trove = Trove.new()
end

function Factory:Start()
    self.ProductionRate = ValueObject.new(DEFAULT_PRODUCTION_RATE)
end

function Factory:SteppedUpdate(deltaTime: number)
    self:_produceUnits(deltaTime)
end

function Factory:Stop()
    self._trove:Clean()
end

function Factory:_produceUnits(deltaTime: number)
    local node = self._components.Node
    local teamsPresent = #TableUtil.Keys(TableUtil.Filter(node._unitCounts, function(unitCount, _)
        return unitCount:Get() > 0
    end))
    if teamsPresent > 1 then return end
    local newUnits = self.ProductionRate:Get() * deltaTime
    local isNeutral = node.Owner:Get().Name == "Neutral"
    if isNeutral then
        newUnits /= 2
    end
    if node.Owner:Get() == nil then return end
    node:GiveUnits(newUnits, node.Owner:Get())
end

return Factory