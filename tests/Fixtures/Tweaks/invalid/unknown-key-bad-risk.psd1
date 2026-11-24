# Geçersiz fixture: yazım hatalı alan (Descripton), geçersiz Risk, geçersiz koşul, Params'ta tanımsız yer tutucu.
@{
    Id          = 'fixture.unknown-key'
    Title       = 'Bilinmeyen alan'
    Descripton  = 'yazım hatası'
    Description = 'Tweak şemasını sınar.'
    Category    = 'fixture'
    Risk        = 'Dangerous'
    Conditions  = @( 'HasQuantumGpu', @{ MinBuild = 'yüksek' } )
    Params      = @{ level = 1 }
    Actions     = @(
        @{ Type = 'Registry'; Path = 'HKCU:\Software\X'; Name = 'Y'; Value = '{{seviye}}'; Kind = 'DWord' }
    )
}
