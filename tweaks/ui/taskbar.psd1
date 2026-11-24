@{
    Id          = 'ui.taskbar'
    Title       = 'Görev çubuğu: ortalı, otomatik gizlenir, yalnız Dosya Gezgini + Chrome'
    Description = 'Görev çubuğu ortalanır ve otomatik gizlenir (StuckRects3). Arama kutusu, Görev Görünümü, Sohbet ve Copilot düğmeleri kaldırılır (Widgets düğmesi ui.widgets-off ilkesiyle). Bildirim alanında yalnız taşma oku ve sistem simgeleri (Wi-Fi, ses, pil) kalır: uygulama simgeleri taşma menüsüne alınır, sonradan gelen uygulamalar da Windows''un varsayılanıyla oraya düşer. Sabitlemeler yalnız Dosya Gezgini ve Google Chrome olur (diğerleri kalkar; Windows''un "Start Layout" ilkesi tek seferlik kullanılır, sonra kullanıcı istediğini sabitleyebilir). Chrome kurulu değilse yalnız Gezgin sabitlenir, sonraki çalıştırmada Chrome eklenir. Gezgin yeniden başlar; etkileşimli oturum yoksa (CI) sabitleme adımı uygulanamaz.'
    Category    = 'ui'
    Risk        = 'Safe'
    Params      = @{ autoHide = $true }
    Refresh     = @('Shell')
    Actions     = @(
        # Ortalı (Windows 11 varsayılanı; açıkça yazılır)
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'TaskbarAl'; Value = 1; Kind = 'DWord' }
        # Otomatik gizle: StuckRects3 'Settings' 8. bayt, 0. bit (ABS_AUTOHIDE)
        @{ Type = 'RegistryByte'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'; Name = 'Settings'; Offset = 8; Mask = 1; Value = '{{autoHide}}' }
        # Düğmeler: arama, Görev Görünümü, Copilot
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'SearchboxTaskbarMode'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ShowTaskViewButton'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ShowCopilotButton'; Value = 0; Kind = 'DWord' }
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
