local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = game:GetService("Selection")
local ServerStorage = game:GetService("ServerStorage")

local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Waiter = require(ReplicatedStorage.Packages.Waiter)

local EDGE_TEMPLATE = Waiter.getFirst(Waiter.descendants(ServerStorage.MapElements), Waiter.matchTag("Edge"))

local function CreateEdges(firstNode: Instance, otherNodes: {Instance}): {Instance}
    assert(EDGE_TEMPLATE ~= nil, "Edge template not found")
    local edgesFolder = Waiter.getFirst(Waiter.descendants(workspace), Waiter.matchTag("EdgesFolder"))
    assert(edgesFolder ~= nil, "Edges folder not found")

    local fadeBuffer = EDGE_TEMPLATE:GetAttribute("FadeBuffer") or 0.1
    local fadeDistance = EDGE_TEMPLATE:GetAttribute("FadeDistance") or 0.5

    local edges = {}
    for _, otherNode in otherNodes do
        local edge = EDGE_TEMPLATE:Clone() :: Beam
        edge.Parent = edgesFolder
        edge.Attachment0 = Waiter.getFirst(Waiter.descendants(firstNode), Waiter.matchClassName("Attachment"))
        edge.Attachment1 = Waiter.getFirst(Waiter.descendants(otherNode), Waiter.matchClassName("Attachment"))

        local distance = (edge.Attachment0.WorldCFrame.Position - edge.Attachment1.WorldCFrame.Position).Magnitude
        local fadeStart1 = (firstNode.Size.X / 2) + fadeBuffer
        local fadeEnd1 = fadeStart1 + fadeDistance
        local fadeStart2 = distance - (otherNode.Size.X / 2) - fadeBuffer
        local fadeEnd2 = fadeStart2 - fadeDistance

        fadeStart1 /= distance
        fadeEnd1 /= distance
        fadeStart2 /= distance
        fadeEnd2 /= distance

        fadeStart1 = math.clamp(fadeStart1, 0, 0.4)
        fadeEnd1 = math.clamp(fadeEnd1, fadeStart1, 0.5)
        fadeStart2 = math.clamp(fadeStart2, 0.6, 1)
        fadeEnd2 = math.clamp(fadeEnd2, 0.5, fadeStart2)

        local minTransparency = EDGE_TEMPLATE.Transparency.Keypoints[1].Value

        edge.Transparency = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(fadeStart1, 1),
            NumberSequenceKeypoint.new(fadeEnd1, minTransparency),
            NumberSequenceKeypoint.new(0.5, minTransparency),
            NumberSequenceKeypoint.new(fadeEnd2, minTransparency),
            NumberSequenceKeypoint.new(fadeStart2, 1),
            NumberSequenceKeypoint.new(1, 1),
        }
        table.insert(edges, edge)
    end

    return edges
end

local function GetEdges(nodes: {Instance}): {Instance}
    local edgesFolder = Waiter.getFirst(Waiter.descendants(workspace), Waiter.matchTag("EdgesFolder"))
    assert(edgesFolder ~= nil, "Edges folder not found")

    local edges = {}
    for _, edge in Waiter.get(Waiter.descendants(edgesFolder), Waiter.matchTag("Edge")) do
        if table.find(nodes, edge.Attachment0.Parent) == nil and table.find(nodes, edge.Attachment1.Parent) == nil then continue end
        table.insert(edges, edge)
    end

    return edges
end

local function TryCreateEdges()
    local selection = Selection:Get()
    TableUtil.Filter(selection, function(instance)
        return instance:HasTag("Node")
    end)
    if #selection < 2 then
        warn("Select at least 2 nodes to create an edge")
        return
    end
    local firstNode = table.remove(selection, 1)
    local edges = CreateEdges(firstNode, selection)
    Selection:Set(edges)
end

local function TryGetEdges()
    local selection = Selection:Get()
    TableUtil.Filter(selection, function(instance)
        return instance:HasTag("Node")
    end)
    local edges = GetEdges(Selection:Get())
    if #edges == 0 then
        warn("No edges found")
        return
    end
    Selection:Set(edges)
end

local function TryUpdateEdges()
    local selection = Selection:Get()
    TableUtil.Filter(selection, function(instance)
        return instance:HasTag("Node")
    end)
    local edges = GetEdges(Selection:Get())
    for _, edge: Beam in edges do
        CreateEdges(edge.Attachment0.Parent, {edge.Attachment1.Parent})
        edge:Destroy()
    end
end

local toolbar = plugin:CreateToolbar("Foray")

local connectNodesAction = plugin:CreatePluginAction("ForayConnectNodes", "Foray: Connect Nodes", "Connects two or more nodes together.")
local getEdgesAction =  plugin:CreatePluginAction("ForayGetEdges", "Foray: Get Edges", "Selects all edges connected to the selected nodes.")
local updateEdgesAction = plugin:CreatePluginAction("ForayUpdateEdges", "Foray: Update Edges", "Updates all edges connected to the selected nodes.")

local connectNodesButton = toolbar:CreateButton("Connect Nodes", "Connects two or more nodes together.", "rbxassetid://14978048121")
connectNodesButton.ClickableWhenViewportHidden = true
connectNodesButton.Click:Connect(TryCreateEdges)
connectNodesAction.Triggered:Connect(TryCreateEdges)

local getEdgesButton = toolbar:CreateButton("Get Edges", "Selects all edges connected to the selected nodes.", "rbxassetid://14978048121")
getEdgesButton.ClickableWhenViewportHidden = true
getEdgesButton.Click:Connect(TryGetEdges)
getEdgesAction.Triggered:Connect(TryGetEdges)

local updateEdgesButton = toolbar:CreateButton("Update Edges", "Updates all edges connected to the selected nodes.", "rbxassetid://14978048121")
updateEdgesButton.ClickableWhenViewportHidden = true
updateEdgesButton.Click:Connect(TryUpdateEdges)
updateEdgesAction.Triggered:Connect(TryUpdateEdges)