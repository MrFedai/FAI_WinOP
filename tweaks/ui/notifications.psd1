@{
    Id          = 'ui.notifications'
    Title       = 'Bildirimleri kapat (istisna listesi hariç)'
    Description = 'Bildirimler genel olarak açık tutulur, ama bildirim gönderen uygulama ve sistem bileşenlerinin hepsi tek tek kapatılır; exceptions parametresindeki kalıplara (-like, varsayılan *WhatsApp*, *Telegram*) uyanlar açık kalır. Windows Güvenliği / Defender ile Güvenlik ve Bakım bildirimleri her zaman korunur. Ayrıca Windows hoş geldin deneyimi, kurulumu tamamlama önerileri ve ipucu / öneri bildirimleri kapanır. Bir uygulamanın bildirim kaydı ilk bildiriminde oluşur: sonradan kurulan uygulama profil yeniden çalıştırılınca kapanır.'
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
