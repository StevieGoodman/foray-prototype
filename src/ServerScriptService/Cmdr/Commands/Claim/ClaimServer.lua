local ServerScriptService = game:GetService("ServerScriptService")

local NodeComponent = require(ServerScriptService.Component.Node)
local TeamComponent = require(ServerScriptService.Component.Team)

return function(commandContext, newOwner: Team?)
    newOwner = newOwner or commandContext.Executor.Team
    local selectedNode = commandContext:GetData()
    if selectedNode == nil then
        return "No nodes are currently selected."
    end
    local node = NodeComponent:FromInstance(selectedNode)
    if node == nil then
        return "The selected instance is not a node. Was it just deleted?"
    end
    node.Owner:Set(TeamComponent.FromName(newOwner.Name))
    return `Claimed {node.Instance.Name} for {newOwner.Name}.`
end