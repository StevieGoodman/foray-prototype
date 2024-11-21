local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

return {
    Name = "UnitCount",
    Aliases = {},
    Description = "Sets the unit count of the selected node(s)",
    Group = "Developer",
    Args = {
        {
            Type = "number",
            Name = "unit count",
            Description = "New unit count",
        },
        {
            Type = "team",
            Name = "team",
            Description = "Which team to give units to. (defaults to owner of selected node)",
            Optional = true,
        }
    },
    Data = function(_)
        local selectedNode = Knit.GetController("Selection").SelectedNode:Get() or Knit.GetController("Selection").HoveredNode:Get()
        return if selectedNode == nil then nil else selectedNode.Instance
    end
}