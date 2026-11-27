@{
    Id          = 'sound.volume'
    Title       = 'Set the volume level'
    Description = 'Sets the level of the default audio output device to the level parameter (0-100, default 15). Skipped if there is no output device (server, virtual machine). If the device changes, the new device uses its own level.'
    Category    = 'sound'
    Risk        = 'Safe'
    Params      = @{ level = 15 }
    Actions     = @(
        @{ Type = 'Volume'; Level = '{{level}}' }
    )
}
