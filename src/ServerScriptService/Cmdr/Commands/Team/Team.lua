return {
    Name = "Team",
    Aliases = {},
    Description = "Sets a player(s) team",
    Group = "Developer",
    Args = {
        {
            Type = "players",
            Name = "Players",
            Description = "Whose team to set",
        },
        {
            Type = "team",
            Name = "Team",
            Description = "The team to assign the player(s) to",
        },
    },
}