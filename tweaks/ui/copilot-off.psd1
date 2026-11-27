@{
    Id          = 'ui.copilot-off'
    Title       = 'Turn off Copilot'
    Description = 'Windows Copilot is turned off by policy ("Turn off Windows Copilot", user and machine) and the Copilot button on the taskbar is hidden. The Copilot app itself is removed by bloat.remove (Microsoft.Copilot). In newer builds Copilot is a separate app, so the policy affects only the old integrated Copilot; the button and the app removal do the real work. Explorer restarts.'
    Category    = 'ui'
    Risk        = 'Safe'
    Refresh     = @('Shell')
    Actions     = @(
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot'; Name = 'TurnOffWindowsCopilot'; Value = 1; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'; Name = 'TurnOffWindowsCopilot'; Value = 1; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ShowCopilotButton'; Value = 0; Kind = 'DWord' }
    )
}
