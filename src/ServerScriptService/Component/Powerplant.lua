local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Component = require(ReplicatedStorage.Packages.Component)
local ComponentExtensions = require(ReplicatedStorage.Packages.ComponentExtensions)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ValueObject = require(ReplicatedStorage.Packages.ValueObject)

local FactoryComponent = require(ServerScriptService.Component.Factory)
local NodeComponent = require(ServerScriptService.Component.Node)

local MESH_ID = 132264144550547
local MESH_DIMENSIONS = Vector3.new(1, 0.6, 1)
local PRODUCTION_RATE_BOOST = 20
local UPGRADE_COST = 2500

local Powerplant = Component.new {
    Tag = "Powerplant",
    Ancestors = { workspace },
    Extensions = {
        ComponentExtensions.RequiresComponent(NodeComponent),
    },
}

NodeComponent.RegisterUpgradeType({
    Name = "Powerplant",
    Component = Powerplant,
    Cost = UPGRADE_COST,
    MeshId = MESH_ID,
    MeshDimensions = MESH_DIMENSIONS,
    MeshScale = 2,
})

function Powerplant:Construct()
    self.ProductionRateBoost = ValueObject.Value.new(PRODUCTION_RATE_BOOST)

    self._trove = Trove.new()
    self._trove:Add(self.ProductionRateBoost)
end

function Powerplant:Start()
    local connectedNodes = self._components.Node:GetDirectlyConnectedNodes()
    for _, node in connectedNodes do
        self:_tryBoostProduction(node.UpgradeComponent:Get())
        self._trove:Add(node.UpgradeComponent.Changed:Connect(function(newUpgradeComponent)
            self:_tryBoostProduction(newUpgradeComponent)
        end))
    end
end

function Powerplant:Stop()
    self._trove:Clean()
end

function Powerplant:_tryBoostProduction(upgradeComponent)
    if upgradeComponent == nil or upgradeComponent.Tag ~= FactoryComponent.Tag then return end
    self._trove:Add(upgradeComponent:BoostProduction(self.ProductionRateBoost:Get()))
end


return Powerplant