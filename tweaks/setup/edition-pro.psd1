@{
    Id          = 'setup.edition-pro'
    Title       = 'Windows Home → Pro yükseltmesi (Ayarlar üzerinden)'
    Description = 'Yalnız Home (Core) sürümde: Ayarlar > Etkinleştirme sayfasını açar; Pro''ya yükseltme kullanıcının kendi ürün anahtarıyla ("Ürün anahtarını değiştir") ya da Microsoft Store''dan satın alınan yükseltmeyle yapılır. Araç anahtar içermez, genel / KMS anahtarı girmez ve hiçbir etkinleştirme atlatması yapmaz (korsan aktivasyon yok). Yükseltme sonunda Windows yeniden başlar; sürüm Pro olunca tweak koşulu sağlanmaz, atlanır. Etkileşimsiz kipte uygulanmaz; geri alma yoktur.'
    Category    = 'setup'
    Risk        = 'Caution'
    Confirm     = 'Ayarlar > Etkinleştirme açılacak; yükseltmeyi kendi ürün anahtarınızla ya da Store''dan siz yaparsınız.'
    Conditions  = @(@{ Edition = 'Core' })
    Actions     = @(
        @{ Type = 'OpenSettings'; Uri = 'ms-settings:activation'; Message = 'Etkinleştirme sayfası açıldı: "Ürün anahtarını değiştir" ile kendi Pro anahtarınızı girin ya da Store''dan Pro yükseltmesini alın. Yükseltme sonrası Windows yeniden başlar.' }
    )
}
