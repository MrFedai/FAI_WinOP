@{
    Id          = 'setup.default-browser'
    Title       = 'Default browser (via Settings)'
    Description = 'If the default browser for https is not appName, opens Settings > Default apps for that app; the user clicks the "Set default" button, then the result is checked. Because of the Windows 11 UserChoice hash protection and the UCPD driver, there is no reliable programmatic way (docs/APPS.md). Not applied in non-interactive mode; revert is also done manually from the Settings page.'
    Category    = 'setup'
    Risk        = 'Caution'
    Confirm     = 'The Settings page will open; you need to click the "Set default" button yourself.'
    Params      = @{ progId = 'ChromeHTML'; appName = 'Google Chrome'; scope = 'Machine' }
    Actions     = @(
        @{ Type = 'DefaultBrowser'; ProgId = '{{progId}}'; AppName = '{{appName}}'; Scope = '{{scope}}' }
    )
}
