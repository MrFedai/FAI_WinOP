@{
    Id          = 'privacy.app-permissions'
    Title       = 'Uygulama izinlerini kapat (kamera ve mikrofon açık)'
    Description = 'Ayarlar > Gizlilik ve güvenlik > Uygulama izinleri altındaki izinleri cihaz düzeyinde kapatır: konum, bildirimlere erişim, hesap bilgisi, kişiler, takvim, telefon aramaları, arama geçmişi, e-posta, görevler, mesajlaşma, radyolar, diğer cihazlarla eşitleme, uygulama tanılaması, belgeler, resimler, videolar, müzik, dosya sistemi, metin / görüntü üretimi (yapay zekâ modelleri) ve geçiş anahtarı listeleme. Kamera ve mikrofon açık tutulur (cihaz ve kullanıcı düzeyinde). İzinler çoğunlukla Store (paketli) uygulamaları etkiler; masaüstü uygulamalarında yalnız konum, kamera ve mikrofon izni geçerlidir. Konum kapalıyken otomatik saat dilimi ve Cihazımı bul çalışmaz. İzin anahtarı olmayan bir sürümde (ör. müzik, yapay zekâ modelleri) değer yine yazılır, etkisi olmaz.'
    Category    = 'privacy'
    Risk        = 'Safe'
    Actions     = @(
        # Açık kalanlar
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam'; Name = 'Value'; Value = 'Allow'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone'; Name = 'Value'; Value = 'Allow'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam'; Name = 'Value'; Value = 'Allow'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone'; Name = 'Value'; Value = 'Allow'; Kind = 'String' }
        # Cihaz düzeyinde kapalı (HKLM)
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location'; Name = 'Value'; Value = 'Deny'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userNotificationListener'; Name = 'Value'; Value = 'Deny'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userAccountInformation'; Name = 'Value'; Value = 'Deny'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\contacts'; Name = 'Value'; Value = 'Deny'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\appointments'; Name = 'Value'; Value = 'Deny'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\phoneCall'; Name = 'Value'; Value = 'Deny'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\phoneCallHistory'; Name = 'Value'; Value = 'Deny'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\email'; Name = 'Value'; Value = 'Deny'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userDataTasks'; Name = 'Value'; Value = 'Deny'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\chat'; Name = 'Value'; Value = 'Deny'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\radios'; Name = 'Value'; Value = 'Deny'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\bluetoothSync'; Name = 'Value'; Value = 'Deny'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\appDiagnostics'; Name = 'Value'; Value = 'Deny'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\documentsLibrary'; Name = 'Value'; Value = 'Deny'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\picturesLibrary'; Name = 'Value'; Value = 'Deny'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\videosLibrary'; Name = 'Value'; Value = 'Deny'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\broadFileSystemAccess'; Name = 'Value'; Value = 'Deny'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\passkeysEnumeration'; Name = 'Value'; Value = 'Deny'; Kind = 'String' }
        # Yalnız kullanıcı düzeyinde bulunan izinler (Windows 11 26H2'de HKLM karşılığı yok)
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\musicLibrary'; Name = 'Value'; Value = 'Deny'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\systemAIModels'; Name = 'Value'; Value = 'Deny'; Kind = 'String' }
    )
}
