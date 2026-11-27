@{
    Id          = 'ui.taskbar'
    Title       = 'Taskbar: buttons off, tray in overflow, only File Explorer + Chrome'
    Description = 'The Search box, Task View and Chat buttons are removed (the Widgets button by ui.widgets-off, the Copilot button by ui.copilot-off). Alignment and auto-hide are not set in this tweak but by the profile''s layout.taskbar.alignment / autoHide (single source; -ExportLayout captures them). In the notification area only the overflow arrow and system icons (Wi-Fi, volume, battery) remain: app icons move to the overflow menu, and apps that arrive later also land there with Windows'' default. Pins are only File Explorer and Google Chrome (the others are removed; the Windows "Start Layout" policy is used once, after which the user can pin whatever they like). If Chrome is not installed, only Explorer is pinned and Chrome is added on the next run. Explorer restarts; without an interactive session (CI) the pinning step cannot be applied.'
    Category    = 'ui'
    Risk        = 'Safe'
    Refresh     = @('Shell')
    Actions     = @(
        # Hiza (TaskbarAl) ve otomatik gizleme (StuckRects3): profil layout.taskbar (src/Core/Layout.ps1)
        # Düğmeler: arama, Görev Görünümü (Copilot: ui.copilot-off)
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'SearchboxTaskbarMode'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ShowTaskViewButton'; Value = 0; Kind = 'DWord' }
        # Sohbet (Teams) düğmesi: ilke 3 = gizli (TaskbarMn yerine; yeni yapılarda düğme zaten yok)
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Chat'; Name = 'ChatIcon'; Value = 3; Kind = 'DWord' }
        # Bildirim alanı: uygulama simgeleri taşma menüsünde
        @{ Type = 'RegistryEach'; Path = 'HKCU:\Control Panel\NotifyIconSettings'; Name = 'IsPromoted'; Value = 0; Kind = 'DWord' }
        # Sabitlemeler (en sonda: Gezgin'i yeniden başlatır, önceki ayarlar da o anda okunur)
        @{ Type = 'TaskbarPins'; Pins = @(
                @{ AppId = 'Microsoft.Windows.Explorer' }
                @{ Link = '%ProgramData%\Microsoft\Windows\Start Menu\Programs\Google Chrome.lnk' }
            )
        }
    )
}
