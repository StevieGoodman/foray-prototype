local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Comm = require(ReplicatedStorage.Packages.Comm)
local Component = require(ReplicatedStorage.Packages.Component)
local ComponentExtensions = require(ReplicatedStorage.Packages.ComponentExtensions)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ValueObject = require(ReplicatedStorage.Packages.ValueObject)
local Waiter = require(ReplicatedStorage.Packages.Waiter)

local UnitGroupComponent = require(ServerScriptService.Component.UnitGroup)
local RoundComponent = require(ServerScriptService.Component.Round)
local TeamComponent = require(ServerScriptService.Component.Team)

local STARTING_UNIT_COUNT = 25
local COMBAT_MULTIPLIER = 0.1
local MIN_CASUALITY_COUNT = 4

local Node = Component.new {
    Tag = "Node",
    Ancestors = { workspace },
    Extensions = {
        ComponentExtensions.IsClass("BasePart"),
        ComponentExtensions.RequiresComponent(RoundComponent, Waiter.ancestors),
        ComponentExtensions.RequiresInstance("UnitCounter", Waiter.descendants, Waiter.matchTag),
    },
}

Node.IdCounter = 1

function Node.FromId(id: number)
    local nodes = Node:GetAll()
    for _, node in nodes do
        if node.Id ~= id then continue end
        return node
    end
end

function Node:Construct()
    self.Id = Node.IdCounter
    Node.IdCounter += 1
    self.Instance.Name = `Node {self.Id}`
    self.ProductionRate = ValueObject.new(1)
    self.Edges = ValueObject.new({})
    self.Round = self._components.Round
    self.Owner = ValueObject.new(TeamComponent.FromName(self.Instance:GetAttribute("DefaultOwner") or "Neutral"))

    self._comm = Comm.ServerComm.new(self.Instance, self.Tag)
    self._comm:BindFunction("SendUnitsTo", function(player, nodeId, unitCount)
        if not self:OwnedBy(player) and not player:HasTag("BypassesEnabled") then return end
        local node = Node.FromId(nodeId)
        if node == nil then return end
        self:SendUnitsTo(node, unitCount)
    end)
    self._properties = {
        Id = self._comm:CreateProperty("Id", self.Id),
        Owner = self._comm:CreateProperty("Owner", if self.Owner:Get() == nil then nil else self.Owner:Get().Name),
    }

    self._trove = Trove.new()
    self:_setUpUnitCounts()
end

function Node:Start()
    self:GiveUnits(STARTING_UNIT_COUNT, self.Owner:Get())
    self:_updateColor()
    self._trove:Add(self.Owner.Changed:Connect(function(newOwner)
        self._properties.Owner:Set(if newOwner ~= nil then newOwner.Name else nil)
        self:_updateColor()
    end))
end

function Node:SteppedUpdate(deltaTime: number)
    self:_produceUnits(deltaTime)
    self:_incrementBattle(deltaTime)
end

function Node:Stop()
    self._trove:Clean()
end

function Node:CalculatePath(to)
    local distances = {}
    distances[self.Id] = 0
    for _, connectedNode in self:GetAllConnectedNodes() do
        distances[connectedNode.Id] = math.huge
    end

    -- Calculate path using Dijkstra's algorithm
    local predecessors = {}
    local queue = self:GetAllConnectedNodes()
    table.insert(queue, self)

    while #queue ~= 0 do
        local currentNode = TableUtil.Reduce(queue, function(a, b)
            return if distances[a.Id] < distances[b.Id] then a else b
        end, queue[1])
        local index = table.find(queue, currentNode)
        table.remove(queue, index)
        local currentDistanceTravelled = distances[currentNode.Id]
        local edges = currentNode.Edges:Get()
        for _, edge in edges do
            local connectedNode = edge:GetConnectedNode(currentNode)
            local newDistance = currentDistanceTravelled + edge.Length
            if newDistance >= distances[connectedNode.Id] then continue end
            distances[connectedNode.Id] = newDistance
            predecessors[connectedNode.Id] = currentNode
        end
    end

    -- Reconstruct path
    local path = {}
    local currentNode = to
    while currentNode ~= self do
        table.insert(path, currentNode)
        currentNode = predecessors[currentNode.Id]
    end
    path = TableUtil.Reverse(path)

    return path
end

function Node:GetDirectlyConnectedNodes()
    local visitedNodeIds = {}
    local connectedNodes = {}
    for _, edge in self.Edges:Get() do
        local connectedNode = edge:GetConnectedNode(self)
        if table.find(visitedNodeIds, connectedNode.Id) ~= nil then continue end
        table.insert(visitedNodeIds, connectedNode.Id)
        table.insert(connectedNodes, connectedNode)
    end
    return connectedNodes
end

function Node:GetAllConnectedNodes(connectedNodes: table?, visitedNodeIds: table?)
    visitedNodeIds = visitedNodeIds or {}
    connectedNodes = connectedNodes or {}
    table.insert(visitedNodeIds, self.Id)
    for _, connectedNode in self:GetDirectlyConnectedNodes() do
        if table.find(visitedNodeIds, connectedNode.Id) ~= nil then continue end
        table.insert(connectedNodes, connectedNode)
        connectedNode:GetAllConnectedNodes(connectedNodes, visitedNodeIds)
    end
    return connectedNodes
end

function Node:IsDirectlyConnectedTo(node)
    return table.find(self:GetDirectlyConnectedNodes(), node) ~= nil
end

function Node:IsConnectedTo(node)
    return table.find(self:GetAllConnectedNodes(), node) ~= nil
end

function Node:GetEdgeTo(node)
    for _, edge in self.Edges:Get() do
        if edge:GetConnectedNode(self).Id ~= node.Id then continue end
        return edge
    end
end

function Node:GetPivot()
    return self.Instance:GetPivot()
end

function Node:SendUnitsTo(node, unitCount: number)
    unitCount = self:TakeUnits(unitCount, self.Owner:Get(), true)
    if unitCount <= 1 then
        self:GiveUnits(unitCount, self.Owner:Get())
        return
    end
    unitCount = math.floor(unitCount)
    UnitGroupComponent.new(self, node, unitCount)
end

function Node:OwnedBy(player: Player)
    if self.Owner:Get() == nil then return false end
    return self.Owner:Get():IsMember(player)
end

function Node:GetUnitCount(team): number
    return self._unitCounts[team.Name]
end

function Node:SetUnitCount(newUnitCount: number, team): number
    newUnitCount = math.max(newUnitCount, 0)
    local unitCount = self:GetUnitCount(team)
    unitCount:Set(newUnitCount)
    return unitCount:Get()
end

function Node:TakeUnits(amount: number, team, protectOwnership: boolean): number
    amount = math.max(amount, 0)
    local unitCount = self:GetUnitCount(team)
    local taken = math.min(if protectOwnership then unitCount:Get() - 1 else unitCount:Get(), amount)
    self:SetUnitCount(unitCount:Get() - taken, team)
    return taken
end

function Node:GiveUnits(amount: number, team): number
    amount = math.max(amount, 0)
    local unitCount = self:GetUnitCount(team)
    self:SetUnitCount(unitCount:Get() + amount, team)
    return amount
end

function Node:_setUpUnitCounts()
    self._unitCounts = {}
    for _, team in TeamComponent.Teams:Get() do
        self:_setUpUnitCount(team)
    end

    self._trove:Add(TeamComponent.Teams.Changed:Connect(function(teams)
        for _, team in teams do
            self:_setUpUnitCount(team)
        end
    end))
end

function Node:_setUpUnitCount(team)
    if self._unitCounts[team.Name] ~= nil then return end
    self._unitCounts[team.Name] = ValueObject.new(0)
    self._trove:Add(self._unitCounts[team.Name])

    self._trove:Add(self._unitCounts[team.Name].Changed:Connect(function(_: number)
        self:_updateUnitCounter()
        self:_updateOwner()
    end))
end

function Node:_updateColor()
    self.Instance.Color =
        if self.Owner:Get() == nil
        then BrickColor.new("Dark stone grey").Color
        else self.Owner:Get().Color
end

function Node:_produceUnits(deltaTime: number)
    local teamsPresent = #TableUtil.Keys(TableUtil.Filter(self._unitCounts, function(unitCount, _)
        return unitCount:Get() > 0
    end))
    if teamsPresent > 1 then return end
    local newUnits = self.ProductionRate:Get() * deltaTime
    local isNeutral = self.Owner:Get().Name == "Neutral"
    if isNeutral then
        newUnits /= 2
    end
    if self.Owner:Get() == nil then return end
    self:GiveUnits(newUnits, self.Owner:Get())
end

function Node:_updateOwner()
    local presentUnitCounts = TableUtil.Filter(self._unitCounts, function(unitCount, _)
        return unitCount:Get() > 0
    end)
    local presentTeamCount = #TableUtil.Keys(presentUnitCounts)
    if presentTeamCount == 0 then
        self.Owner:Set(nil)
        return
    elseif presentTeamCount == 1 then
        for teamName, _ in presentUnitCounts do
            if self.Owner:Get() ~= nil and self.Owner:Get().Name == teamName then return end
            self.Owner:Set(TeamComponent.FromName(teamName))
            return
        end
        return
    end
end

function Node:_updateUnitCounter()
    local text = ""
    for teamName, unitCount in self._unitCounts do
        if unitCount:Get() < 1 then continue end
        local team = TeamComponent.FromName(teamName)
        text ..= `<font color="#{team.Color:ToHex()}">{math.floor(unitCount:Get())}</font>`
        text ..= " v "
    end
    text = string.sub(text, 1, -4)
    self._instances.UnitCounter.Text = text
end

function Node:_incrementBattle(deltaTime: number)
    local casualties = {}
    for teamName, unitCount in self._unitCounts do
        if unitCount:Get() == 0 then continue end
        local enemyCount = 0
        for enemyName, enemyUnitCount in self._unitCounts do
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
        self:TakeUnits(casualtyCount, TeamComponent.FromName(teamName), false)
    end
end

return Node