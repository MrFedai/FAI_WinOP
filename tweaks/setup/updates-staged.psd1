@{
    Id          = 'setup.updates-staged'
    Title       = 'Windows Update: install pending first, then pause'
    Description = 'First, all pending software updates (Windows Update Agent; drivers excluded) are downloaded and installed, with progress printed. If the installation asks for a restart, the run stops here: restart and run the profile again (if the CLI provides a ResumeCommand, it continues on its own through RunOnce); the remaining updates and the pause are done in that run. When none are pending, updates are paused for pauseDays (default 365) days: the pause values of Settings > Windows Update (UX\Settings, start / end in UTC). FlightSettingsMaxPauseDays is not written; how 365 days appears in Settings will be verified in a VM. -UpdatesOn / -UpdatesOff separately remove / re-apply the pause. -Undo removes the pause; installed updates are not rolled back. Security patches are paused too; a long pause can make an Insider build expire. Confirmation is requested on every run.'
    Category    = 'setup'
    Risk        = 'Caution'
    AlwaysConfirm = $true
    Confirm     = 'All updates, including security patches, are paused for 365 days; a long pause can make an Insider build expire.'
    Params      = @{ pauseDays = 365 }
    Actions     = @(
        @{ Type = 'WindowsUpdate' }
        @{ Type = 'UpdatePause'; Days = '{{pauseDays}}' }
    )
}
