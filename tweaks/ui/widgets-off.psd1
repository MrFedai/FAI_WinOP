@{
    Id          = 'ui.widgets-off'
    Title       = 'Pencere öğelerini (Widgets) kapat'
    Description = 'Pencere öğeleri panosu ve görev çubuğundaki düğmesi ilkeyle kapatılır ("Pencere öğelerine izin ver" = Devre dışı); Windows 10 mirası Haberler ve ilgi alanları da kapalı. Düğme ilkeyle kalkar: TaskbarDa kullanıcı değeri yeni yapılarda Windows tarafından korunur (UCPD), dışarıdan yazılamaz. Pencere öğeleri uygulaması (MicrosoftWindows.Client.WebExperience) kaldırılmaz. Gezgin yeniden başlar.'
    Category    = 'ui'
    Risk        = 'Safe'
    Refresh     = @('Shell')
    Actions     = @(
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'; Name = 'AllowNewsAndInterests'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds'; Name = 'EnableFeeds'; Value = 0; Kind = 'DWord' }
    )
}
