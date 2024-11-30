local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Waiter = require(ReplicatedStorage.Packages.Waiter)

Knit.OnStart()
:andThen(function()
    for _, component in Waiter.get(Waiter.descendants(script), Waiter.matchClassName("ModuleScript")) do
        require(component)
    end
    print(`Component has successfully started on the client!`)
end)
:catch(function(error)
    error(`Failed to start Component on the client: {error}`)
end)