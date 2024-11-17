local ServerScriptService = game:GetService("ServerScriptService")

local NodeComponent = require(ServerScriptService.Component.Node)
local TeamComponent = require(ServerScriptService.Component.Team)

return function(commandContext, newOwner: Team?)
    newOwner = newOwner or commandContext.Executor.Team
    local hoveredNode = commandContext:GetData()
    if hoveredNode == nil then
        return "No nodes are currently being hovered over."
    end
    local node = NodeComponent:FromInstance(hoveredNode)
    if node == nil then
        return "The hovered instance is not a node. Was it just deleted?"
    end
    node.Owner:Set(TeamComponent.FromName(newOwner.Name))
    return `Claimed {node.Instance.Name} for {newOwner.Name}.`
end