# Geçersiz fixture: 0. eylemde yol / tür hataları, 1. eylemde bilinmeyen tür, 2. eylemde yeni alan yazım hatası.
@{
    Id          = 'fixture.bad-action'
    Title       = 'Hatalı eylem'
    Description = 'Eylem şemasını sınar.'
    Category    = 'fixture'
    Risk        = 'Safe'
    Actions     = @(
        @{ Type = 'Registry'; Path = 'C:\Windows'; Name = 'X'; Value = 'metin'; Kind = 'DWord' }
        @{ Type = 'Teleport'; Name = 'X' }
        @{ Type = 'Service'; Name = 'Spooler'; StartTyp = 'Disabled' }
    )
}
