@{
    Id            = 'graphics.p0-state'
    Title         = 'NVIDIA: stay in the P0 power state'
    Description   = 'Turns off dynamic P-state switching on the NVIDIA GPU (DisableDynamicPstate=1): the card stays in the highest power state (P0) even when idle, which reduces latency spikes from clock drops. The value is written only to the display adapter class keys (0000, 0001…) whose provider is NVIDIA; Intel / AMD keys are not touched. On a laptop, battery life gets shorter and heat rises; for this reason confirmation is requested on every run (the profile''s autoConfirm does not apply, and it is not applied with -Unattended). Takes effect when the driver is reloaded or after a restart. Note: the effect has not been measured on real hardware (Phase 9).'
    Category      = 'graphics'
    Risk          = 'Caution'
    AlwaysConfirm = $true
    Confirm       = 'The GPU stays at full power even when idle: on a laptop, battery life gets shorter and heat rises.'
    Conditions    = @('HasNvidia')
    Actions       = @(
        @{ Type = 'RegistryEach'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'; Include = @('[0-9][0-9][0-9][0-9]'); Match = @{ Name = 'ProviderName'; Like = @('NVIDIA*') }; Name = 'DisableDynamicPstate'; Value = 1; Kind = 'DWord' }
    )
}
