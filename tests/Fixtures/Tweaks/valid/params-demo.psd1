# Geçerli fixture: Caution + parametre (yer tutucu '{{level}}'); profil level'ı geçersiz kılabilir.
@{
    Id          = 'fixture.params-demo'
    Title       = 'Parametreli örnek'
    Description = 'Parametreyle ayarlanan bir değer yazar.'
    Category    = 'fixture'
    Risk        = 'Caution'
    Confirm     = 'Bu bir örnektir, pil ve ısı etkisi yoktur.'
    Params      = @{ level = 15 }
    Actions     = @(
        @{ Type = 'Registry'; Path = 'HKCU:\Software\FAI_WinOP_Test\Demo'; Name = 'Level'; Value = '{{level}}'; Kind = 'DWord' }
    )
}
