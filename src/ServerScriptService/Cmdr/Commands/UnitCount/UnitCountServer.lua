local ServerScriptService = game:GetService("ServerScriptService")

local NodeComponent = require(ServerScriptService.Component.Node)

return function(commandContext, newUnitCount: number)
    local selectedNode = commandContext:GetData()
    if selectedNode == nil then
        return "No nodes are currently selected."
    end
    local node = NodeComponent:FromInstance(selectedNode)
    if node == nil then
        return "The selected instance is not a node. Was it just deleted?"
    end
    node.UnitCount:Set(newUnitCount)
    return `Set unit count of {node.Instance.Name} to {newUnitCount} units.`
end