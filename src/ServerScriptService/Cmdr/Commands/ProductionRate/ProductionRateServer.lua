local ServerScriptService = game:GetService("ServerScriptService")

local NodeComponent = require(ServerScriptService.Component.Node)

return function(commandContext, newProductionRate: number)
    local selectedNode = commandContext:GetData()
    if selectedNode == nil then
        return "No nodes are currently selected."
    end
    local node = NodeComponent:FromInstance(selectedNode)
    if node == nil then
        return "The selected instance is not a node. Was it just deleted?"
    end
    node.ProductionRate:Set(newProductionRate)
    return `Set production rate of {node.Instance.Name} to {newProductionRate} units/s.`
end