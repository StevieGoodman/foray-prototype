return function(_, players: {Player}, team: Team)
    for _, player in players do
        player.Team = team
    end
    return `Assigned {#players} player(s) to team {team.Name}`
end