local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

return {
    Name = "ProductionRate",
    Aliases = {},
    Description = "Sets the production rate of the selected node(s)",
    Group = "development",
    Args = {
        {
            Type = "number",
            Name = "rate",
            Description = "New production rate (units/s)",
        },
    },
    Data = function(_)
        local selectedNode = Knit.GetController("Selection").SelectedNode:Get() or Knit.GetController("Selection").HoveredNode:Get()
        return if selectedNode == nil then nil else selectedNode.Instance
    end
}