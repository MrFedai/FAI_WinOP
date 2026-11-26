@{
    Id          = 'ui.widgets-off'
    Title       = 'Pencere öğelerini (Widgets) kapat'
    Description = 'Pencere öğeleri uygulaması (MicrosoftWindows.Client.WebExperience) bu kullanıcı için kaldırılır: pano ve görev çubuğundaki düğmesi onunla gider. İlke yolu ("Pencere öğelerine izin ver" = Devre dışı, Policies\Microsoft\Dsh) yeni yapılarda UCPD sürücüsü yüzünden yönetici olarak da yazılamıyor; görev çubuğu değeri (TaskbarDa) de korumalı. Paket kabuk için gerekmez; korunan listede (MicrosoftWindows.Client.*) birebir adıyla istisna. Provisioned kopya kalır: yeni kullanıcılarda pano gelir, geri alma paketi yeniden kaydeder. Windows 10 mirası Haberler ve ilgi alanları ilkesi (Windows Feeds\\EnableFeeds) de UCPD korumasında ve Windows 11''de etkisiz: yazılmaz. Gezgin yeniden başlar.'
    Category    = 'ui'
    Risk        = 'Safe'
    Refresh     = @('Shell')
    Actions     = @(
        @{ Type = 'Appx'; Name = 'MicrosoftWindows.Client.WebExperience'; Scope = 'User' }
    )
}
