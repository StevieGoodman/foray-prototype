local ServerScriptService = game:GetService("ServerScriptService")

local NodeComponent = require(ServerScriptService.Component.Gameplay.Node)

local function GetInfoString(node): string
    local string =
`Node {node.Id}\
Owned by: {node.Owner:Get().Name}\
Production rate: {node.ProductionRate:Get()} units/s`

    local unitCounts = node._unitCounts
    local teamsString = "\nTeams: "
    for teamName, unitCount in unitCounts do
        unitCount = unitCount:Get()
        if unitCount == 0 then continue end
        unitCount = math.round(unitCount * 10) / 10
        teamsString ..= `{teamName} ({unitCount}), `
    end
    teamsString = teamsString:sub(1, -3)
    string ..= teamsString

    local directlyConnectedNodes = node:GetDirectlyConnectedNodes()
    for index, connectedNode in directlyConnectedNodes do
        local length = node:GetEdgeTo(connectedNode).Length
        directlyConnectedNodes[index] = `{connectedNode.Instance.Name} ({length} studs)`
    end
    string ..= `\nConnected nodes: {table.concat(directlyConnectedNodes, ", ")}`

    return string
end

return function(commandContext)
    local selectedNode = commandContext:GetData()
    if selectedNode == nil then
        return "No nodes are currently selected."
    end
    local node = NodeComponent:FromInstance(selectedNode)
    if node == nil then
        return "The selected instance is not a node. Was it just deleted?"
    end
    return GetInfoString(node)
end