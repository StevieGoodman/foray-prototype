local ServerScriptService = game:GetService("ServerScriptService")

local NodeComponent = require(ServerScriptService.Component.Gameplay.Node)
local TeamComponent = require(ServerScriptService.Component.Gameplay.Team)

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
    local team = TeamComponent:FromInstance(newOwner)
    if node:GetUnitCount(team):Get() == 0 then
        node:GiveUnits(1, team)
    end
    node.Owner:Set(team)
    return `Claimed {node.Instance.Name} for {newOwner.Name}.`
end