@{
    Id          = 'bloat.persistence'
    Title       = 'Kaldırılan uygulamaların geri gelmesini engelle'
    Description = 'bloat.remove listesindeki paketlerin provisioned kopyalarını kaldırır (yeni kullanıcılara ve güncellemeden sonra yeniden kurulmasınlar), Windows''un önerilen / sponsorlu uygulamaları kendiliğinden kurmasını kapatır (ContentDeliveryManager ve CloudContent ilkesi) ve açılışta Windows yapı numarası değiştiyse (büyük ya da aylık güncelleme) aynı listeyi bütün kullanıcılardan yeniden kaldıran bir zamanlanmış görev (\FAI_WinOP\BloatCleanup, SYSTEM) kurar; görev %ProgramData%\FAI_WinOP\BloatCleanup.log dosyasına yazar. Korunan liste ve profildeki uygulamalar görev betiğine de girmez. Provisioned kaldırmanın geri dönüşü yoktur: geri alma görevi ve betiği siler, ayarları döndürür; uygulamalar Store''dan yeniden kurulur. DisableWindowsConsumerFeatures ilkesi resmî olarak yalnız Enterprise / Education''da etkilidir; Pro''da asıl işi ContentDeliveryManager değerleri yapar.'
    Category    = 'bloat'
    Risk        = 'Caution'
    Confirm     = 'Provisioned paket kaldırma geri alınamaz (uygulama gerekirse Store''dan kurulur).'
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
