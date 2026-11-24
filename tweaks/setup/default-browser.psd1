@{
    Id          = 'setup.default-browser'
    Title       = 'Varsayılan tarayıcı (Ayarlar üzerinden)'
    Description = 'https için varsayılan tarayıcı appName değilse Ayarlar > Varsayılan uygulamalar sayfasını o uygulamada açar; "Varsayılan olarak ayarla" düğmesine kullanıcı basar, sonra sonuç denetlenir. Windows 11 UserChoice karma koruması ve UCPD sürücüsü yüzünden programla güvenilir yol yok (docs/APPS.md). Etkileşimsiz kipte uygulanmaz; geri alma da Ayarlar sayfasından elle yapılır.'
    Category    = 'setup'
    Risk        = 'Caution'
    Confirm     = 'Ayarlar sayfası açılacak; "Varsayılan olarak ayarla" düğmesine sizin basmanız gerekir.'
    Params      = @{ progId = 'ChromeHTML'; appName = 'Google Chrome'; scope = 'Machine' }
    Actions     = @(
        @{ Type = 'DefaultBrowser'; ProgId = '{{progId}}'; AppName = '{{appName}}'; Scope = '{{scope}}' }
    )
}
