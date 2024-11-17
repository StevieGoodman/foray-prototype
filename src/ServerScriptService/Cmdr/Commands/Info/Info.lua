local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

return {
    Name = "Info",
    Aliases = {},
    Description = "Shows information about the selected node(s).",
    Group = "development",
    Args = {},
    Data = function(_)
        local selectedNode = Knit.GetController("Selection").SelectedNode:Get()
        return if selectedNode == nil then nil else selectedNode.Instance
    end
}