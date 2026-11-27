@{
    Id          = 'ui.taskbar'
    Title       = 'Görev çubuğu: düğmeler kapalı, tepsi taşma menüsünde, yalnız Dosya Gezgini + Chrome'
    Description = 'Arama kutusu, Görev Görünümü ve Sohbet düğmeleri kaldırılır (Widgets düğmesi ui.widgets-off, Copilot düğmesi ui.copilot-off ile). Hiza ve otomatik gizleme bu tweak''te değil, profil layout.taskbar.alignment / autoHide ile verilir (tek kaynak; -ExportLayout yakalar). Bildirim alanında yalnız taşma oku ve sistem simgeleri (Wi-Fi, ses, pil) kalır: uygulama simgeleri taşma menüsüne alınır, sonradan gelen uygulamalar da Windows''un varsayılanıyla oraya düşer. Sabitlemeler yalnız Dosya Gezgini ve Google Chrome olur (diğerleri kalkar; Windows''un "Start Layout" ilkesi tek seferlik kullanılır, sonra kullanıcı istediğini sabitleyebilir). Chrome kurulu değilse yalnız Gezgin sabitlenir, sonraki çalıştırmada Chrome eklenir. Gezgin yeniden başlar; etkileşimli oturum yoksa (CI) sabitleme adımı uygulanamaz.'
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
