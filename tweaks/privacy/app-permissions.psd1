@{
    Id          = 'privacy.app-permissions'
    Title       = 'Turn off app permissions (camera and microphone stay on)'
    Description = 'Turns off, at the device level, the permissions under Settings > Privacy & security > App permissions: location, notification access, account info, contacts, calendar, phone calls, call history, email, tasks, messaging, radios, sync with other devices, app diagnostics, documents, pictures, videos, music, file system, text / image generation (AI models) and passkey listing. Camera and microphone stay on (device and user level). The permissions mostly affect Store (packaged) apps; for desktop apps only the location, camera and microphone permissions apply. While location is off, automatic time zone and Find my device do not work. On a version without a permission key (e.g. music, AI models) the value is still written but has no effect.'
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
