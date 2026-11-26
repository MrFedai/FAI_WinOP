@{
    Id          = 'setup.store-optimize'
    Title       = 'Microsoft Store: otomatik güncelleme, video ve kişiselleştirme kapalı'
    Description = 'Store uygulamalarının otomatik indirilip güncellenmesi kapatılır (WindowsStore\WindowsUpdate\AutoDownload=2); Store uygulamaları bunun yerine winget upgrade ile güncellenir. Store''un kendi ayarlarında (settings.dat) videoların otomatik oynatılması, uygulama kurulum bildirimleri ve kişiselleştirilmiş deneyim kapatılır. Store hiç açılmamışsa ayar dosyası yoktur: o adımlar atlanır, Store bir kez açıldıktan sonraki çalıştırmada uygulanır. Yazarken Store açıksa kapatılır.'
    Category    = 'setup'
    Risk        = 'Caution'
    Actions     = @(
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate'; Name = 'AutoDownload'; Value = 2; Kind = 'DWord' }
        @{ Type = 'AppSetting'; Package = 'Microsoft.WindowsStore_8wekyb3d8bbwe'; Name = 'VideoAutoplay'; Kind = 'Bool'; Value = $false }
        @{ Type = 'AppSetting'; Package = 'Microsoft.WindowsStore_8wekyb3d8bbwe'; Name = 'EnableAppInstallNotifications'; Kind = 'Bool'; Value = $false }
        @{ Type = 'AppSetting'; Package = 'Microsoft.WindowsStore_8wekyb3d8bbwe'; Key = 'PersistentSettings'; Name = 'PersonalizationEnabled'; Kind = 'Bool'; Value = $false }
    )
}
