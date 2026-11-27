@{
    Id          = 'privacy.telemetry'
    Title       = 'Minimize telemetry'
    Description = 'Lowers diagnostic data to the lowest level the edition allows: telemetry policy, the DiagTrack (Connected User Experiences and Telemetry) and dmwappushservice services, CEIP / compatibility / disk diagnostic tasks, advertising ID, tailored experiences, feedback requests, error reporting, activity history, and ink and typing data submission. Edition difference: AllowTelemetry=0 (Security) is fully effective only on Enterprise, Education and Server; Home and Pro apply it as 1 (Required diagnostic data), so Required is the lowest policy level reachable on Home / Pro. On Home / Pro, what actually stops sending is turning off the DiagTrack service. The CEIPEnable and AITEnable policies may have no effect in newer versions and are written for older components. AllowTelemetry=0 cuts off Windows Insider flights (Insider builds get no updates). Windows Update, Store and Defender keep working; Settings shows "Some settings are managed by your organization". Do not use on a device managed with MDM / Intune (dmwappushservice carries registration messages).'
    Category    = 'privacy'
    Risk        = 'Safe'
    Actions     = @(
        # Tanılama verisi ilkesi (Home / Pro'da 1'e yükseltilir, bkz. açıklama)
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowTelemetry'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'DoNotShowFeedbackNotifications'; Value = 1; Kind = 'DWord' }
        # Telemetri servisleri
        @{ Type = 'Service'; Name = 'DiagTrack'; StartType = 'Disabled'; State = 'Stopped' }
        @{ Type = 'Service'; Name = 'dmwappushservice'; StartType = 'Disabled'; State = 'Stopped' }
        # CEIP ve uygulama uyumluluğu telemetrisi (eski bileşenler)
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows'; Name = 'CEIPEnable'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat'; Name = 'AITEnable'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat'; Name = 'DisableInventory'; Value = 1; Kind = 'DWord' }
        # Veri toplayan zamanlanmış görevler (makinede olmayan görev atlanır)
        @{ Type = 'ScheduledTask'; Path = '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser'; State = 'Disabled' }
        @{ Type = 'ScheduledTask'; Path = '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser Exp'; State = 'Disabled' }
        @{ Type = 'ScheduledTask'; Path = '\Microsoft\Windows\Application Experience\ProgramDataUpdater'; State = 'Disabled' }
        @{ Type = 'ScheduledTask'; Path = '\Microsoft\Windows\Application Experience\MareBackup'; State = 'Disabled' }
        @{ Type = 'ScheduledTask'; Path = '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator'; State = 'Disabled' }
        @{ Type = 'ScheduledTask'; Path = '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip'; State = 'Disabled' }
        @{ Type = 'ScheduledTask'; Path = '\Microsoft\Windows\Autochk\Proxy'; State = 'Disabled' }
        @{ Type = 'ScheduledTask'; Path = '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector'; State = 'Disabled' }
        @{ Type = 'ScheduledTask'; Path = '\Microsoft\Windows\Feedback\Siuf\DmClient'; State = 'Disabled' }
        @{ Type = 'ScheduledTask'; Path = '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload'; State = 'Disabled' }
        # Reklam kimliği
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; Name = 'Enabled'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo'; Name = 'DisabledByGroupPolicy'; Value = 1; Kind = 'DWord' }
        # Tanılama verisiyle kişiye özel deneyimler (Ayarlar anahtarı + yeni CPSS deposu + ilke)
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy'; Name = 'TailoredExperiencesWithDiagnosticDataEnabled'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CPSS\Store\TailoredExperiencesWithDiagnosticDataEnabled'; Name = 'Value'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableTailoredExperiencesWithDiagnosticData'; Value = 1; Kind = 'DWord' }
        # Geri bildirim sıklığı: hiçbir zaman
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Siuf\Rules'; Name = 'NumberOfSIUFInPeriod'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Siuf\Rules'; Name = 'PeriodInNanoSeconds'; Ensure = 'Absent' }
        # Windows Hata Raporlama
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting'; Name = 'Disabled'; Value = 1; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting'; Name = 'Disabled'; Value = 1; Kind = 'DWord' }
        # Etkinlik geçmişi
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'EnableActivityFeed'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'PublishUserActivities'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'UploadUserActivities'; Value = 0; Kind = 'DWord' }
        # Mürekkep ve yazma verisini Microsoft'a gönderme
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Input\TIPC'; Name = 'Enabled'; Value = 0; Kind = 'DWord' }
    )
}
