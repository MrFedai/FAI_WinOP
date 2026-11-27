@{
    Id          = 'graphics.amd-settings'
    Title       = 'AMD: simplified Adrenalin and low latency'
    Description = 'AMD Software (Adrenalin) settings, registry only: automatic updates, system tray, web content, animations, notification bubbles and in-game overlay are off. In the class key of the display adapter whose provider is AMD, Radeon Anti-Lag is on (KMD_DeLagEnabled=1); under UMD, vertical sync is always off, texture filtering quality is performance, and tessellation overrides the application setting; under power_v1, Vari-Bright (abmlevel) is off. UMD values are UTF-16 text digits (e.g. 30 00 = "0"). Values were taken from the Ultimate reference and not verified on real AMD hardware; a driver update may reset some of them.'
    Category    = 'graphics'
    Risk        = 'Safe'
    Conditions  = @('HasAmdGpu')
    Actions     = @(
        @{ Type = 'Registry'; Path = 'HKCU:\Software\AMD\CN'; Name = 'AutoUpdate'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\AMD\CN'; Name = 'SystemTray'; Value = 'false'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\AMD\CN'; Name = 'AllowWebContent'; Value = 'false'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\AMD\CN'; Name = 'AnimationEffect'; Value = 'false'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\AMD\CN'; Name = 'CN_Hide_Toast_Notification'; Value = 'true'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\AMD\DVR'; Name = 'ShowRSOverlay'; Value = 'false'; Kind = 'String' }
        @{ Type = 'RegistryEach'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'; Include = @('[0-9][0-9][0-9][0-9]'); Match = @{ Name = 'ProviderName'; Like = @('Advanced Micro Devices*', 'AMD*', 'ATI*') }; Name = 'KMD_DeLagEnabled'; Value = 1; Kind = 'DWord' }
        @{ Type = 'RegistryEach'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'; Include = @('[0-9][0-9][0-9][0-9]'); Match = @{ Name = 'ProviderName'; Like = @('Advanced Micro Devices*', 'AMD*', 'ATI*') }; SubKey = 'UMD'; Name = 'VSyncControl'; Value = @(0x30, 0x00); Kind = 'Binary' }
        @{ Type = 'RegistryEach'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'; Include = @('[0-9][0-9][0-9][0-9]'); Match = @{ Name = 'ProviderName'; Like = @('Advanced Micro Devices*', 'AMD*', 'ATI*') }; SubKey = 'UMD'; Name = 'TFQ'; Value = @(0x32, 0x00); Kind = 'Binary' }
        @{ Type = 'RegistryEach'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'; Include = @('[0-9][0-9][0-9][0-9]'); Match = @{ Name = 'ProviderName'; Like = @('Advanced Micro Devices*', 'AMD*', 'ATI*') }; SubKey = 'UMD'; Name = 'Tessellation'; Value = @(0x31, 0x00); Kind = 'Binary' }
        @{ Type = 'RegistryEach'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'; Include = @('[0-9][0-9][0-9][0-9]'); Match = @{ Name = 'ProviderName'; Like = @('Advanced Micro Devices*', 'AMD*', 'ATI*') }; SubKey = 'UMD'; Name = 'Tessellation_OPTION'; Value = @(0x32, 0x00); Kind = 'Binary' }
        @{ Type = 'RegistryEach'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'; Include = @('[0-9][0-9][0-9][0-9]'); Match = @{ Name = 'ProviderName'; Like = @('Advanced Micro Devices*', 'AMD*', 'ATI*') }; SubKey = 'power_v1'; Name = 'abmlevel'; Value = @(0x00, 0x00, 0x00, 0x00); Kind = 'Binary' }
    )
}
