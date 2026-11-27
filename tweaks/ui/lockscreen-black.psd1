@{
    Id          = 'ui.lockscreen-black'
    Title       = 'Lock and sign-in screen black'
    Description = 'A plain black image (C:\ProgramData\FAI_WinOP\Black.png, 1920x1080) is generated and assigned by policy (PersonalizationCSP) as the lock screen image; Windows Spotlight and lock screen tips are disabled by this image, and the user cannot change it from Settings. The blurred (acrylic) background on the sign-in screen is turned off, so the sign-in screen also looks black. The path is written assuming the system drive is C: (the policy value does not expand environment variables). The effect shows at the next lock.'
    Category    = 'ui'
    Risk        = 'Safe'
    Actions     = @(
        @{ Type = 'SolidImage'; Path = 'C:\ProgramData\FAI_WinOP\Black.png'; Color = '000000'; Width = 1920; Height = 1080 }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'; Name = 'LockScreenImagePath'; Value = 'C:\ProgramData\FAI_WinOP\Black.png'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'; Name = 'LockScreenImageUrl'; Value = 'C:\ProgramData\FAI_WinOP\Black.png'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'; Name = 'LockScreenImageStatus'; Value = 1; Kind = 'DWord' }
        # Oturum açma ekranında akrilik bulanıklık yok
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'DisableAcrylicBackgroundOnLogon'; Value = 1; Kind = 'DWord' }
    )
}
