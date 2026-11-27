@{
    Id          = 'system.timer-resolution'
    Title       = 'Timer resolution 0.5 ms'
    Description = 'Installs the FAI_TimerResolution service (src/Native/TimerResolution.cs, starts automatically at boot) and sets the system timer to 0.5 ms (5000 × 100 ns). On Windows 11, a resolution requested by a process affects only that process; for a system-wide effect GlobalTimerResolutionRequests=1 is required (Session Manager\kernel). May slightly increase power consumption on battery. -Undo removes the service and deletes the value.'
    Category    = 'system'
    Risk        = 'Safe'
    Params      = @{ resolution = 5000 }
    Actions     = @(
        @{ Type = 'Registry'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel'; Name = 'GlobalTimerResolutionRequests'; Value = 1; Kind = 'DWord' }
        @{ Type = 'TimerResolution'; Resolution = '{{resolution}}' }
    )
}
