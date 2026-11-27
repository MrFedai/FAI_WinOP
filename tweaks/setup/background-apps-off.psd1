@{
    Id          = 'setup.background-apps-off'
    Title       = 'Turn off background apps (except an exception list)'
    Description = 'With a privacy policy (AppPrivacy\LetAppsRunInBackground=2, "force deny") Store / packaged apps are stopped from running in the background; the package family names in the exceptions parameter (default WhatsApp: 5319275A.WhatsAppDesktop_cv1g1gvanyjgm) stay allowed through LetAppsRunInBackground_ForceAllowTheseApps. The policy also covers apps installed later; the per-app option in Settings appears grayed out because of the policy. Win32 apps (e.g. Telegram Desktop installed with winget) are not affected by this setting, so they are not in the list. The user-wide switch (GlobalUserDisabled) was not used: it would turn off the exceptions too.'
    Category    = 'setup'
    Risk        = 'Safe'
    Params      = @{ exceptions = @('5319275A.WhatsAppDesktop_cv1g1gvanyjgm') }
    Actions     = @(
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'; Name = 'LetAppsRunInBackground'; Value = 2; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'; Name = 'LetAppsRunInBackground_ForceAllowTheseApps'; Value = '{{exceptions}}'; Kind = 'MultiString' }
    )
}
