@{
    Id          = 'ui.desktop-icons'
    Title       = 'Masaüstü simgeleri: Bu Bilgisayar + Geri Dönüşüm Kutusu'
    Description = 'Masaüstünde Bu Bilgisayar ve Geri Dönüşüm Kutusu gösterilir (Ayarlar > Kişiselleştirme > Temalar > Masaüstü simgesi ayarları). "Simgeleri otomatik düzenle" kapatılır, "Simgeleri kılavuza hizala" açık kalır (FFlags: Windows varsayılanı 0x40200225, otomatik düzenle biti 0x1 kaldırılır); böylece simgeler sürüklendikleri yerde kalır. Sağ alt köşe konumu: simgeler bir kez elle yerleştirilip -ExportLayout ile profile alınır (desktop.iconLayouts), profil uygulanınca aynı konumlar geri gelir. Gezgin yeniden başlar.'
    Category    = 'ui'
    Risk        = 'Safe'
    Refresh     = @('Shell')
    Actions     = @(
        # 0 = göster (NewStartPanel: Windows 10 / 11 görünümü)
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel'; Name = '{20D04FE0-3AEA-1069-A2D8-08002B30309D}'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel'; Name = '{645FF040-5081-101B-9F08-00AA002F954E}'; Value = 0; Kind = 'DWord' }
        # Otomatik düzenle kapalı, kılavuza hizala açık (0x40200224)
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\Shell\Bags\1\Desktop'; Name = 'FFlags'; Value = 1075839524; Kind = 'DWord' }
    )
}
