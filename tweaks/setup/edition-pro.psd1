@{
    Id          = 'setup.edition-pro'
    Title       = 'Windows Home → Pro upgrade (via Settings)'
    Description = 'Home (Core) edition only: opens the Settings > Activation page; the upgrade to Pro is done with the user''s own product key ("Change product key") or with an upgrade bought from the Microsoft Store. The tool contains no key, enters no generic / KMS key and performs no activation bypass (no pirated activation). Windows restarts at the end of the upgrade; once the edition is Pro, the tweak condition is not met and it is skipped. Not applied in non-interactive mode; there is no revert.'
    Category    = 'setup'
    Risk        = 'Caution'
    Confirm     = 'Settings > Activation will open; you do the upgrade yourself with your own product key or from the Store.'
    Conditions  = @(@{ Edition = 'Core' })
    Actions     = @(
        @{ Type = 'OpenSettings'; Uri = 'ms-settings:activation'; Message = 'Activation page opened: enter your own Pro key with "Change product key", or get the Pro upgrade from the Store. Windows restarts after the upgrade.' }
    )
}
