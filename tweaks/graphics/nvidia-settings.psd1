@{
    Id          = 'graphics.nvidia-settings'
    Title       = 'NVIDIA: tray icon and legacy sharpening off'
    Description = 'NVIDIA settings that can be made with the registry alone: the NVIDIA tray icon does not start at sign-in (NvTray\StartOnLogin=0) and the legacy image sharpening scaler is turned off (nvlddmkm FTS\EnableGR535=0; written only if the FTS key created by the driver exists). Control Panel settings (low latency, power management, vertical sync, texture filtering…) live in the NVIDIA DRS database; since no unsigned third-party tool (Profile Inspector) is used, they are outside this tweak''s scope (later, via NVAPI). Not verified on real NVIDIA hardware.'
    Category    = 'graphics'
    Risk        = 'Safe'
    Conditions  = @('HasNvidia')
    Actions     = @(
        @{ Type = 'Registry'; Path = 'HKCU:\Software\NVIDIA Corporation\NvTray'; Name = 'StartOnLogin'; Value = 0; Kind = 'DWord' }
        @{ Type = 'RegistryEach'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm'; Include = @('FTS'); Name = 'EnableGR535'; Value = 0; Kind = 'DWord' }
        @{ Type = 'RegistryEach'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm'; Include = @('Parameters'); SubKey = 'FTS'; Name = 'EnableGR535'; Value = 0; Kind = 'DWord' }
    )
}
