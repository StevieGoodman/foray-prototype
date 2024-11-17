return {
    Name = "Bypass",
    Aliases = { "Sudo" },
    Description = "Toggles developer bypasses for a player.",
    Group = "development",
    Args = {
        {
            Type = "player",
            Name = "Player",
            Description = "Whom to toggle bypasses for (defaults to command executor)",
            Optional = true,
        },
    },
}