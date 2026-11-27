@{
    Id          = 'system.restore-point'
    Title       = 'System Restore point'
    Description = 'The first step (First) of every run: creates a System Restore point before the profile''s apps and the other tweaks. Turns on System Protection if it is off on the system drive. Windows'' once-per-24-hours point limit (SystemRestorePointCreationFrequency) is temporarily lifted during creation, then restored. -Undo does not delete the point; FAI_WinOP has its own revert, so this point is a last resort (rstrui). Note: turning on System Protection / creating a point has not been verified on a real machine (VM).'
    Category    = 'system'
    Risk        = 'Safe'
    First       = $true
    Params      = @{ description = 'FAI_WinOP' }
    Actions     = @(
        @{ Type = 'RestorePoint'; Description = '{{description}}' }
    )
}
