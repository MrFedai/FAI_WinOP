@{
    Id          = 'ui.explorer'
    Title       = 'File Explorer layout'
    Description = 'File Explorer opens to This PC, file extensions are shown, and the title bar shows the full path. Gallery and Home are hidden in the navigation pane; 3D Objects is hidden from This PC (it does not exist on Windows 11 anyway; the action is only a safeguard). Home is hidden with the HubMode policy: Microsoft may change this behavior with updates, to be verified on real hardware (Phase 9). Navigation pane changes show after Explorer restarts.'
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
