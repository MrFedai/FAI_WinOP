# Geçerli fixture: her kayıt defteri türü; biri var olan, kalanı olmayan değerler (Engine-Smoke + birim testleri).
@{
    Id          = 'fixture.registry-demo'
    Title       = 'Kayıt defteri örneği'
    Description = 'Tüm kayıt defteri türlerini yazar; var olan bir değeri değiştirir, yeni değerler ekler.'
    Category    = 'fixture'
    Risk        = 'Safe'
    Conditions  = @()
    Actions     = @(
        @{ Type = 'Registry'; Path = 'HKCU:\Software\FAI_WinOP_Test\Demo'; Name = 'Existing'; Value = 2; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\FAI_WinOP_Test\Demo'; Name = 'NewString'; Value = 'Açılış sesi'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\FAI_WinOP_Test\Demo'; Name = 'NewQWord'; Value = 4294967296; Kind = 'QWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\FAI_WinOP_Test\Demo'; Name = 'NewMulti'; Value = @('a', 'b'); Kind = 'MultiString' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\FAI_WinOP_Test\Demo'; Name = 'NewBinary'; Value = @(1, 2, 255); Kind = 'Binary' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\FAI_WinOP_Test\Demo'; Name = 'Obsolete'; Ensure = 'Absent' }
    )
}
