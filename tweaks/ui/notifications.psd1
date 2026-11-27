@{
    Id          = 'ui.notifications'
    Title       = 'Turn off notifications (except an exception list)'
    Description = 'Notifications stay on globally, but every app and system component that sends notifications is turned off one by one; those that match the patterns in the exceptions parameter (-like, default *WhatsApp*, *Telegram*) stay on. Windows Security / Defender and Security and Maintenance notifications are always kept. Also turned off: the Windows welcome experience, suggestions to finish setting up, and tip / suggestion notifications. An app''s notification entry is created with its first notification: an app installed later is turned off when the profile is run again.'
    Category    = 'ui'
    Risk        = 'Caution'
    Params      = @{ exceptions = @('*WhatsApp*', '*Telegram*') }
    Actions     = @(
        # Genel anahtar açık: istisnalar bildirim gösterebilsin
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications'; Name = 'ToastEnabled'; Value = 1; Kind = 'DWord' }
        # Henüz kaydı olmayabilecek sistem gönderenleri (önceden kapatılır)
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.Suggested'; Name = 'Enabled'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.StartupApp'; Name = 'Enabled'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Microsoft.SkyDrive.Desktop'; Name = 'Enabled'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\windows.immersivecontrolpanel_cw5n1h2txyewy!microsoft.windows.immersivecontrolpanel'; Name = 'Enabled'; Value = 0; Kind = 'DWord' }
        # Kayıtlı bütün gönderenler kapalı; güvenlik bildirimleri ve istisnalar hariç
        @{
            Type    = 'RegistryEach'
            Path    = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings'
            Name    = 'Enabled'
            Value   = 0
            Kind    = 'DWord'
            Exclude = @('Windows.Defender*', '*SecHealthUI*', 'Windows.SystemToast.SecurityAndMaintenance', '{{exceptions}}')
        }
        # Öneri bildirimleri: hoş geldin deneyimi, ipuçları, kurulumu tamamlama
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-310093Enabled'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338389Enabled'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SoftLandingEnabled'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement'; Name = 'ScoobeSystemSettingEnabled'; Value = 0; Kind = 'DWord' }
    )
}
