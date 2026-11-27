@{
    Id          = 'ui.widgets-off'
    Title       = 'Turn off Widgets'
    Description = 'The Widgets app (MicrosoftWindows.Client.WebExperience) is removed for this user: the board and its taskbar button go with it. The policy path ("Allow widgets" = Disabled, Policies\Microsoft\Dsh) cannot be written even as administrator in newer builds because of the UCPD driver; the taskbar value (TaskbarDa) is also protected. The package is not needed by the shell; it is an exception by exact name in the protected list (MicrosoftWindows.Client.*). The provisioned copy stays: the board appears for new users, and revert registers the package again. The legacy Windows 10 News and interests policy (Windows Feeds\\EnableFeeds) is also under UCPD protection and has no effect on Windows 11: it is not written. Explorer restarts.'
    Category    = 'ui'
    Risk        = 'Safe'
    Refresh     = @('Shell')
    Actions     = @(
        @{ Type = 'Appx'; Name = 'MicrosoftWindows.Client.WebExperience'; Scope = 'User' }
    )
}
