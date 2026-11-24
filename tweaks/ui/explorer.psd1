@{
    Id          = 'ui.explorer'
    Title       = 'Dosya Gezgini düzeni'
    Description = 'Dosya Gezgini Bu Bilgisayar ile açılır, dosya uzantıları görünür, başlık çubuğunda tam yol yazar. Gezinti bölmesinde Galeri ve Ana Sayfa gizlenir; 3D Nesneler Bu Bilgisayar''dan gizlenir (Windows 11''de zaten yoktur, eylem yalnız güvencedir). Ana Sayfa HubMode ilkesiyle gizlenir: Microsoft bu davranışı güncellemelerle değiştirebilir, gerçek donanımda doğrulanacak (Faz 9). Gezinti bölmesi değişiklikleri Gezgin yeniden başlayınca görünür.'
    Category    = 'ui'
    Risk        = 'Safe'
    Actions     = @(
        # Bu Bilgisayar ile aç
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'LaunchTo'; Value = 1; Kind = 'DWord' }
        # Dosya uzantılarını göster
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'HideFileExt'; Value = 0; Kind = 'DWord' }
        # Başlık çubuğunda tam yol
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState'; Name = 'FullPath'; Value = 1; Kind = 'DWord' }
        # Galeri gizli (kullanıcı sınıf kaydı HKCR'yi geçersiz kılar)
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}'; Name = 'System.IsPinnedToNameSpaceTree'; Value = 0; Kind = 'DWord' }
        # Ana Sayfa (Hızlı erişim) gizli
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer'; Name = 'HubMode'; Value = 1; Kind = 'DWord' }
        # 3D Nesneler gizli (Windows 10 mirası; klasör tanımı Windows 11'de de durur)
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{31C0DD25-9439-4F12-BF41-7FF4EDA38722}\PropertyBag'; Name = 'ThisPCPolicy'; Value = 'Hide'; Kind = 'String' }
    )
}
