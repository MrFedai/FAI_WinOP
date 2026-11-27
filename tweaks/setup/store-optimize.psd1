@{
    Id          = 'setup.store-optimize'
    Title       = 'Microsoft Store: automatic updates, video and personalization off'
    Description = 'Automatic download and update of Store apps is turned off (WindowsStore\WindowsUpdate\AutoDownload=2); Store apps are updated with winget upgrade instead. In the Store''s own settings (settings.dat), video autoplay, app install notifications and personalized experience are turned off. If the Store has never been opened, the settings file does not exist: those steps are skipped and applied on the first run after the Store has been opened once. If the Store is open while writing, it is closed.'
    Category    = 'setup'
    Risk        = 'Caution'
    Actions     = @(
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate'; Name = 'AutoDownload'; Value = 2; Kind = 'DWord' }
        @{ Type = 'AppSetting'; Package = 'Microsoft.WindowsStore_8wekyb3d8bbwe'; Name = 'VideoAutoplay'; Kind = 'Bool'; Value = $false }
        @{ Type = 'AppSetting'; Package = 'Microsoft.WindowsStore_8wekyb3d8bbwe'; Name = 'EnableAppInstallNotifications'; Kind = 'Bool'; Value = $false }
        @{ Type = 'AppSetting'; Package = 'Microsoft.WindowsStore_8wekyb3d8bbwe'; Key = 'PersistentSettings'; Name = 'PersonalizationEnabled'; Kind = 'Bool'; Value = $false }
    )
}
