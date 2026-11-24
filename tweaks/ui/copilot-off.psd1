@{
    Id          = 'ui.copilot-off'
    Title       = 'Copilot''u kapat'
    Description = 'Windows Copilot ilkeyle kapatılır ("Windows Copilot''u kapat", kullanıcı ve makine) ve görev çubuğundaki Copilot düğmesi gizlenir. Copilot uygulamasının kendisi bloat.remove ile kaldırılır (Microsoft.Copilot). Yeni yapılarda Copilot ayrı bir uygulama olduğundan ilke yalnız eski bütünleşik Copilot''u etkiler; düğme ve uygulama kaldırma asıl işi yapar. Gezgin yeniden başlar.'
    Category    = 'ui'
    Risk        = 'Safe'
    Refresh     = @('Shell')
    Actions     = @(
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot'; Name = 'TurnOffWindowsCopilot'; Value = 1; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'; Name = 'TurnOffWindowsCopilot'; Value = 1; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ShowCopilotButton'; Value = 0; Kind = 'DWord' }
    )
}
