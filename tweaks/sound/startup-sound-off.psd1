@{
    Id          = 'sound.startup-sound-off'
    Title       = 'Turn off the startup sound'
    Description = 'Turns off the Windows sign-in (startup) sound. Equivalent of the Settings > Personalization > Themes > Sounds > "Play Windows Startup sound" checkbox; two values are written together, one of which is read only on some versions.'
    Category    = 'sound'
    Risk        = 'Safe'
    Actions     = @(
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\BootAnimation'; Name = 'DisableStartupSound'; Value = 1; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\EditionOverrides'; Name = 'UserSetting_DisableStartupSound'; Value = 1; Kind = 'DWord' }
    )
}
