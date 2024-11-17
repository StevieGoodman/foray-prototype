local BYPASS_TAG = "BypassesEnabled"

return function(commandContext, player: Player?)
    player = player or commandContext.Executor
    if not player:HasTag(BYPASS_TAG) then
        player:AddTag(BYPASS_TAG)
        return `Enabled bypasses for {player.Name}.`
    else
        player:RemoveTag(BYPASS_TAG)
        return `Disabled bypasses for {player.Name}.`
    end
end