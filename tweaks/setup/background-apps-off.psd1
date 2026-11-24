@{
    Id          = 'setup.background-apps-off'
    Title       = 'Arka plan uygulamalarını kapat (istisna listesi hariç)'
    Description = 'Gizlilik ilkesiyle (AppPrivacy\LetAppsRunInBackground=2, "zorla reddet") Store / paketli uygulamaların arka planda çalışması kapatılır; exceptions parametresindeki paket aile adları (varsayılan WhatsApp: 5319275A.WhatsAppDesktop_cv1g1gvanyjgm) LetAppsRunInBackground_ForceAllowTheseApps ile açık kalır. İlke sonradan kurulan uygulamaları da kapsar; Ayarlar''daki uygulama başına seçenek ilke yüzünden gri görünür. Win32 uygulamaları (ör. winget ile kurulan Telegram Desktop) bu ayardan etkilenmez, bu yüzden listede yok. Kullanıcı genel anahtarı (GlobalUserDisabled) kullanılmadı: o istisnaları da kapatır.'
    Category    = 'setup'
    Risk        = 'Safe'
    Params      = @{ exceptions = @('5319275A.WhatsAppDesktop_cv1g1gvanyjgm') }
    Actions     = @(
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'; Name = 'LetAppsRunInBackground'; Value = 2; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'; Name = 'LetAppsRunInBackground_ForceAllowTheseApps'; Value = '{{exceptions}}'; Kind = 'MultiString' }
    )
}
