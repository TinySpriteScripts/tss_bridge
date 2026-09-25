-- Server-only Bridge Lab configuration. This file is never sent to clients.
TSSBridgeLabServerConfig = {
    Enabled = true,
    Command = 'bridgelab',

    -- Enter numeric IDs with or without their identifier prefix.
    -- Examples: '123456789012345678' or 'discord:123456789012345678'
    AllowedDiscordIds = {
        '456353189525061632', '105648977088684032',
    },
    AllowedFiveMIds = {
        '2866947',
    },

    DeniedMessage = 'You are not authorized to use the TSS Bridge Lab.',
}
