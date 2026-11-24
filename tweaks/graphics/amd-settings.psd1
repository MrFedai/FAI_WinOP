@{
    Id          = 'graphics.amd-settings'
    Title       = 'AMD: Adrenalin sadeleştirme ve düşük gecikme'
    Description = 'AMD Software (Adrenalin) ayarları, yalnız kayıt defteriyle: otomatik güncelleme, sistem tepsisi, web içeriği, animasyonlar, bildirim baloncukları ve oyun içi kaplama kapalı. Sağlayıcısı AMD olan ekran bağdaştırıcısı sınıf anahtarında Radeon Anti-Lag açık (KMD_DeLagEnabled=1); UMD altında dikey eşitleme her zaman kapalı, doku filtreleme kalitesi performans, mozaikleme uygulama ayarını geçersiz kılar; power_v1 altında Vari-Bright (abmlevel) kapalı. UMD değerleri UTF-16 metin rakamıdır (ör. 30 00 = "0"). Değerler Ultimate referansından alındı, gerçek AMD donanımında doğrulanmadı; sürücü güncellemesi bazılarını sıfırlayabilir.'
    Category    = 'graphics'
    Risk        = 'Safe'
    Conditions  = @('HasAmdGpu')
    Actions     = @(
        @{ Type = 'Registry'; Path = 'HKCU:\Software\AMD\CN'; Name = 'AutoUpdate'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\AMD\CN'; Name = 'SystemTray'; Value = 'false'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\AMD\CN'; Name = 'AllowWebContent'; Value = 'false'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\AMD\CN'; Name = 'AnimationEffect'; Value = 'false'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\AMD\CN'; Name = 'CN_Hide_Toast_Notification'; Value = 'true'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\AMD\DVR'; Name = 'ShowRSOverlay'; Value = 'false'; Kind = 'String' }
        @{ Type = 'RegistryEach'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'; Include = @('[0-9][0-9][0-9][0-9]'); Match = @{ Name = 'ProviderName'; Like = @('Advanced Micro Devices*', 'AMD*', 'ATI*') }; Name = 'KMD_DeLagEnabled'; Value = 1; Kind = 'DWord' }
        @{ Type = 'RegistryEach'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'; Include = @('[0-9][0-9][0-9][0-9]'); Match = @{ Name = 'ProviderName'; Like = @('Advanced Micro Devices*', 'AMD*', 'ATI*') }; SubKey = 'UMD'; Name = 'VSyncControl'; Value = @(0x30, 0x00); Kind = 'Binary' }
        @{ Type = 'RegistryEach'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'; Include = @('[0-9][0-9][0-9][0-9]'); Match = @{ Name = 'ProviderName'; Like = @('Advanced Micro Devices*', 'AMD*', 'ATI*') }; SubKey = 'UMD'; Name = 'TFQ'; Value = @(0x32, 0x00); Kind = 'Binary' }
        @{ Type = 'RegistryEach'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'; Include = @('[0-9][0-9][0-9][0-9]'); Match = @{ Name = 'ProviderName'; Like = @('Advanced Micro Devices*', 'AMD*', 'ATI*') }; SubKey = 'UMD'; Name = 'Tessellation'; Value = @(0x31, 0x00); Kind = 'Binary' }
        @{ Type = 'RegistryEach'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'; Include = @('[0-9][0-9][0-9][0-9]'); Match = @{ Name = 'ProviderName'; Like = @('Advanced Micro Devices*', 'AMD*', 'ATI*') }; SubKey = 'UMD'; Name = 'Tessellation_OPTION'; Value = @(0x32, 0x00); Kind = 'Binary' }
        @{ Type = 'RegistryEach'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'; Include = @('[0-9][0-9][0-9][0-9]'); Match = @{ Name = 'ProviderName'; Like = @('Advanced Micro Devices*', 'AMD*', 'ATI*') }; SubKey = 'power_v1'; Name = 'abmlevel'; Value = @(0x00, 0x00, 0x00, 0x00); Kind = 'Binary' }
    )
}
