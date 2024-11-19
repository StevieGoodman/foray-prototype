local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

return {
    Name = "UnitCount",
    Aliases = {},
    Description = "Sets the unit count of the selected node(s)",
    Group = "development",
    Args = {
        {
            Type = "number",
            Name = "unit count",
            Description = "New unit count",
        },
    },
    Data = function(_)
        local selectedNode = Knit.GetController("Selection").SelectedNode:Get() or Knit.GetController("Selection").HoveredNode:Get()
        return if selectedNode == nil then nil else selectedNode.Instance
    end
}