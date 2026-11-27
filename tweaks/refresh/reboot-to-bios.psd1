@{
    Id          = 'refresh.reboot-to-bios'
    Title       = 'Restart to UEFI (BIOS) settings'
    Description = 'Tool: restarts the computer in a few seconds directly into the UEFI firmware settings (shutdown /r /fw). It does not run automatically with a profile; only from the menu or with -Only, with confirmation. Save open documents. To cancel before the time runs out: shutdown /a. Not supported on legacy BIOS installs.'
    Category    = 'refresh'
    Risk        = 'Caution'
    Tool        = $true
    Confirm     = 'The computer will restart in a few seconds; unsaved work will be lost.'
    Params      = @{ delay = 10 }
    Actions     = @(
        @{ Type = 'Reboot'; Firmware = $true; Delay = '{{delay}}' }
    )
}
