@{
    Id          = 'setup.mmagent-off'
    Title       = 'Turn off memory compression and prefetching'
    Description = 'In the memory manager (MMAgent), memory compression, application launch prefetching (prefetch) and application preloading (PreLaunch) are turned off; also PrefetchParameters\EnablePrefetcher=0. For machines with plenty of RAM (at least 16 GB): the CPU time spent on compression and background disk reads go away. Page combining and OperationAPI are not touched. Memory compression takes effect after a restart. Get-MMAgent needs the SysMain service to be running. Cost: EnablePrefetcher=0 also turns off boot prefetching, so boot and first app launches may take longer; on an NVMe SSD the gain is small. On a machine with Hyper-V enabled, Windows may reject the prefetch change ("The request is not supported"). Not in the fedai profile (Phase 9: it was observed to lengthen boot).'
    Category    = 'setup'
    Risk        = 'Safe'
    Conditions  = @(@{ MinRamGB = 16 })
    Actions     = @(
        @{ Type = 'MMAgent'; Feature = 'MemoryCompression'; Enabled = $false }
        @{ Type = 'MMAgent'; Feature = 'ApplicationLaunchPrefetching'; Enabled = $false }
        @{ Type = 'MMAgent'; Feature = 'ApplicationPreLaunch'; Enabled = $false }
        @{ Type = 'Registry'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters'; Name = 'EnablePrefetcher'; Value = 0; Kind = 'DWord' }
    )
}
