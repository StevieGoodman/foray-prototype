local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

return {
    Name = "Claim",
    Aliases = {},
    Description = "Sets the owner of hovered node to the specified team",
    Group = "development",
    Args = {
        {
            Type = "team",
            Name = "Team",
            Description = "Which team to set as the owner (defaults to command executor's team)",
            Optional = true
        },
    },
    Data = function(_)
        local hoveredNode = Knit.GetController("Selection").HoveredNode:Get()
        return if hoveredNode == nil then nil else hoveredNode.Instance
    end
}