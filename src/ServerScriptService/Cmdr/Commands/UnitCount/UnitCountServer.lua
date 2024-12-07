local ServerScriptService = game:GetService("ServerScriptService")

local NodeComponent = require(ServerScriptService.Component.Gameplay.Node)
local TeamComponent = require(ServerScriptService.Component.Gameplay.Team)

return function(commandContext, newUnitCount: number, team: Team?)
    local selectedNode = commandContext:GetData()
    if selectedNode == nil then
        return "No nodes are currently selected."
    end
    local node = NodeComponent:FromInstance(selectedNode)
    if node == nil then
        return "The selected instance is not a node. Was it just deleted?"
    end
    if team == nil and node.Owner:Get() == nil then
        return "The team cannot be inferred because the node has no owner."
    end
    local teamName = if team == nil then node.Owner:Get().Name else team.Name
    team = TeamComponent.FromName(teamName)
    local newAmount = node:SetUnitCount(newUnitCount, team)
    return `Set unit count of {node.Instance.Name} to {newAmount} units.`
end