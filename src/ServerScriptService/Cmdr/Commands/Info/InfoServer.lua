local ServerScriptService = game:GetService("ServerScriptService")

local NodeComponent = require(ServerScriptService.Component.Node)

return function(commandContext)
    local selectedNode = commandContext:GetData()
    if selectedNode == nil then
        return "No nodes are currently selected."
    end
    local node = NodeComponent:FromInstance(selectedNode)
    if node == nil then
        return "The selected instance is not a node. Was it just deleted?"
    end
    return
`Node {node.Id}\
Owned by: {node.Owner:Get().Name}\
Production rate: {node.ProductionRate:Get()} units/s`
end