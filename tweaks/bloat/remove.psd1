@{
    Id          = 'bloat.remove'
    Title       = 'Remove unnecessary Store apps'
    Description = 'Removes preinstalled Store apps from an explicit blocklist (no wildcards, each by package name) for the signed-in user. Before running, the installed ones are shown as a table and confirmation is requested. The protected list (src/Core/Bloat.ps1, Get-FaiBloatProtected) and the Appx names of the profile''s apps (apps/catalog.json appxNames) are never removed: Store, winget (App Installer), Snipping Tool, WhatsApp, Claude, shell / system components, codecs, Photos, Paint, Notepad, Terminal, Calculator, Media Player, driver control panels, Xbox identity. Revert: while the provisioned copy stays on the machine the package is registered again; if bloat.persistence also removed the provisioned copy, revert warns and the app is reinstalled from the Store.'
    Category    = 'bloat'
    Risk        = 'Caution'
    Confirm     = 'The apps above will be removed (they can be reinstalled from the Store).'
    Actions     = @(
        @{ Type = 'Appx'; Name = 'Clipchamp.Clipchamp';                    Scope = 'User' }  # Clipchamp video düzenleyici
        @{ Type = 'Appx'; Name = 'Microsoft.549981C3F5F10';                Scope = 'User' }  # Cortana
        @{ Type = 'Appx'; Name = 'Microsoft.BingFinance';                  Scope = 'User' }  # Finans (Windows 10)
        @{ Type = 'Appx'; Name = 'Microsoft.BingNews';                     Scope = 'User' }  # Haberler
        @{ Type = 'Appx'; Name = 'Microsoft.BingSearch';                   Scope = 'User' }  # Bing Arama uygulaması
        @{ Type = 'Appx'; Name = 'Microsoft.BingSports';                   Scope = 'User' }  # Spor (Windows 10)
        @{ Type = 'Appx'; Name = 'Microsoft.BingWeather';                  Scope = 'User' }  # Hava Durumu
        @{ Type = 'Appx'; Name = 'Microsoft.Copilot';                      Scope = 'User' }  # Copilot uygulaması (düğmesi ui.copilot-off)
        @{ Type = 'Appx'; Name = 'Microsoft.GamingApp';                    Scope = 'User' }  # Xbox uygulaması (Game Bar ve Xbox kimliği kalır)
        @{ Type = 'Appx'; Name = 'Microsoft.GetHelp';                      Scope = 'User' }  # Yardım Alın
        @{ Type = 'Appx'; Name = 'Microsoft.Getstarted';                   Scope = 'User' }  # İpuçları
        @{ Type = 'Appx'; Name = 'Microsoft.Messaging';                    Scope = 'User' }  # Mesajlaşma (Windows 10)
        @{ Type = 'Appx'; Name = 'Microsoft.Microsoft3DViewer';            Scope = 'User' }  # 3D Görüntüleyici (Windows 10)
        @{ Type = 'Appx'; Name = 'Microsoft.MicrosoftOfficeHub';           Scope = 'User' }  # Microsoft 365 (Office) tanıtım uygulaması
        @{ Type = 'Appx'; Name = 'Microsoft.MicrosoftSolitaireCollection'; Scope = 'User' }  # Solitaire
        @{ Type = 'Appx'; Name = 'Microsoft.MicrosoftStickyNotes';         Scope = 'User' }  # Yapışkan Notlar
        @{ Type = 'Appx'; Name = 'Microsoft.MixedReality.Portal';          Scope = 'User' }  # Karma Gerçeklik Portalı (Windows 10)
        @{ Type = 'Appx'; Name = 'Microsoft.MSPaint';                      Scope = 'User' }  # Paint 3D (yeni Paint korunur: Microsoft.Paint)
        @{ Type = 'Appx'; Name = 'Microsoft.Office.OneNote';               Scope = 'User' }  # OneNote for Windows 10
        @{ Type = 'Appx'; Name = 'Microsoft.OneConnect';                   Scope = 'User' }  # Mobil Planlar (Windows 10)
        @{ Type = 'Appx'; Name = 'Microsoft.OutlookForWindows';            Scope = 'User' }  # yeni Outlook
        @{ Type = 'Appx'; Name = 'Microsoft.People';                       Scope = 'User' }  # Kişiler
        @{ Type = 'Appx'; Name = 'Microsoft.PowerAutomateDesktop';         Scope = 'User' }  # Power Automate
        @{ Type = 'Appx'; Name = 'Microsoft.Print3D';                      Scope = 'User' }  # Print 3D (Windows 10)
        @{ Type = 'Appx'; Name = 'Microsoft.SkypeApp';                     Scope = 'User' }  # Skype
        @{ Type = 'Appx'; Name = 'Microsoft.Todos';                        Scope = 'User' }  # Microsoft To Do
        @{ Type = 'Appx'; Name = 'Microsoft.Wallet';                       Scope = 'User' }  # Cüzdan (Windows 10)
        @{ Type = 'Appx'; Name = 'Microsoft.Windows.DevHome';              Scope = 'User' }  # Dev Home (kullanımdan kalktı)
        @{ Type = 'Appx'; Name = 'Microsoft.WindowsAlarms';                Scope = 'User' }  # Saat (alarm / zamanlayıcı)
        @{ Type = 'Appx'; Name = 'Microsoft.WindowsFeedbackHub';           Scope = 'User' }  # Geri Bildirim Merkezi
        @{ Type = 'Appx'; Name = 'Microsoft.WindowsMaps';                  Scope = 'User' }  # Haritalar
        @{ Type = 'Appx'; Name = 'Microsoft.WindowsSoundRecorder';         Scope = 'User' }  # Ses Kaydedici
        @{ Type = 'Appx'; Name = 'Microsoft.XboxApp';                      Scope = 'User' }  # eski Xbox Console Companion (Windows 10)
        @{ Type = 'Appx'; Name = 'Microsoft.YourPhone';                    Scope = 'User' }  # Telefon Bağlantısı
        @{ Type = 'Appx'; Name = 'Microsoft.ZuneVideo';                    Scope = 'User' }  # Filmler ve TV
        @{ Type = 'Appx'; Name = 'MicrosoftCorporationII.QuickAssist';     Scope = 'User' }  # Hızlı Yardım
        @{ Type = 'Appx'; Name = 'MicrosoftTeams';                         Scope = 'User' }  # Teams (eski kişisel)
        @{ Type = 'Appx'; Name = 'MSTeams';                                Scope = 'User' }  # Teams (yeni)
        @{ Type = 'Appx'; Name = '5A894077.McAfeeSecurity';                Scope = 'User' }  # McAfee (OEM)
        @{ Type = 'Appx'; Name = 'AmazonVideo.PrimeVideo';                 Scope = 'User' }  # Prime Video (önerilen uygulama)
        @{ Type = 'Appx'; Name = 'BytedancePte.Ltd.TikTok';                Scope = 'User' }  # TikTok (önerilen uygulama)
        @{ Type = 'Appx'; Name = 'Disney.37853FC22B2CE';                   Scope = 'User' }  # Disney+ (önerilen uygulama)
        @{ Type = 'Appx'; Name = 'king.com.CandyCrushSaga';                Scope = 'User' }  # Candy Crush Saga (önerilen uygulama)
        @{ Type = 'Appx'; Name = 'king.com.CandyCrushSodaSaga';            Scope = 'User' }  # Candy Crush Soda Saga (önerilen uygulama)
    )
}
