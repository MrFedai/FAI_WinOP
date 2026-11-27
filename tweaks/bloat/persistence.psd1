@{
    Id          = 'bloat.persistence'
    Title       = 'Keep removed apps from coming back'
    Description = 'Removes the provisioned copies of the packages in the bloat.remove list (so they are not reinstalled for new users or after updates), stops Windows from installing suggested / sponsored apps on its own (ContentDeliveryManager and CloudContent policy), and sets up a scheduled task (\FAI_WinOP\BloatCleanup, SYSTEM) that, at startup, removes the same list again from all users if the Windows build number changed (major or monthly update); the task writes to %ProgramData%\FAI_WinOP\BloatCleanup.log. The protected list and the profile''s apps are excluded from the task script too. Removing provisioned packages cannot be undone: revert deletes the task and script and restores the settings; apps are reinstalled from the Store. The DisableWindowsConsumerFeatures policy is officially effective only on Enterprise / Education; on Pro the ContentDeliveryManager values do the real work.'
    Category    = 'bloat'
    Risk        = 'Caution'
    Confirm     = 'Removing provisioned packages cannot be undone (reinstall the app from the Store if needed).'
    Actions     = @(
        # Ad listesi tweaks/bloat/remove.psd1 ile birebir aynı olmalı (birim testi denetler).
        @{ Type = 'AppxCleanup'; TaskPath = '\FAI_WinOP\BloatCleanup'; ScriptPath = '%ProgramData%\FAI_WinOP\BloatCleanup.ps1'
            Names = @(
            'Clipchamp.Clipchamp'
            'Microsoft.549981C3F5F10'
            'Microsoft.BingFinance'
            'Microsoft.BingNews'
            'Microsoft.BingSearch'
            'Microsoft.BingSports'
            'Microsoft.BingWeather'
            'Microsoft.Copilot'
            'Microsoft.GamingApp'
            'Microsoft.GetHelp'
            'Microsoft.Getstarted'
            'Microsoft.Messaging'
            'Microsoft.Microsoft3DViewer'
            'Microsoft.MicrosoftOfficeHub'
            'Microsoft.MicrosoftSolitaireCollection'
            'Microsoft.MicrosoftStickyNotes'
            'Microsoft.MixedReality.Portal'
            'Microsoft.MSPaint'
            'Microsoft.Office.OneNote'
            'Microsoft.OneConnect'
            'Microsoft.OutlookForWindows'
            'Microsoft.People'
            'Microsoft.PowerAutomateDesktop'
            'Microsoft.Print3D'
            'Microsoft.SkypeApp'
            'Microsoft.Todos'
            'Microsoft.Wallet'
            'Microsoft.Windows.DevHome'
            'Microsoft.WindowsAlarms'
            'Microsoft.WindowsFeedbackHub'
            'Microsoft.WindowsMaps'
            'Microsoft.WindowsSoundRecorder'
            'Microsoft.XboxApp'
            'Microsoft.YourPhone'
            'Microsoft.ZuneVideo'
            'MicrosoftCorporationII.QuickAssist'
            'MicrosoftTeams'
            'MSTeams'
            '5A894077.McAfeeSecurity'
            'AmazonVideo.PrimeVideo'
            'BytedancePte.Ltd.TikTok'
            'Disney.37853FC22B2CE'
            'king.com.CandyCrushSaga'
            'king.com.CandyCrushSodaSaga'
            )
        }
        # Önerilen / sponsorlu uygulamaların sessiz kurulumu ve önceden yüklenen uygulamalar
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SilentInstalledAppsEnabled'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'PreInstalledAppsEnabled'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'PreInstalledAppsEverEnabled'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'OemPreInstalledAppsEnabled'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContentEnabled'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'FeatureManagementEnabled'; Value = 0; Kind = 'DWord' }
        # Tüketici özellikleri (sponsorlu uygulama kurulumu) ve bulut içerik ilkesi
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableWindowsConsumerFeatures'; Value = 1; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableConsumerAccountStateContent'; Value = 1; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableCloudOptimizedContent'; Value = 1; Kind = 'DWord' }
    )
}
