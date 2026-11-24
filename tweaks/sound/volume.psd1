@{
    Id          = 'sound.volume'
    Title       = 'Ses seviyesini ayarla'
    Description = 'Varsayılan ses çıkış aygıtının seviyesini level parametresine (0-100, varsayılan 15) getirir. Çıkış aygıtı yoksa (sunucu, sanal makine) atlanır. Aygıt değişirse yeni aygıt kendi seviyesini kullanır.'
    Category    = 'sound'
    Risk        = 'Safe'
    Params      = @{ level = 15 }
    Actions     = @(
        @{ Type = 'Volume'; Level = '{{level}}' }
    )
}
