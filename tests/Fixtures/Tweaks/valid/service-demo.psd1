# Geçerli fixture: servis eylemi + koşul (yalnız dizüstü olmayan makinede).
@{
    Id          = 'fixture.service-demo'
    Title       = 'Servis örneği'
    Description = 'Sahte bir servisi devre dışı bırakır ve durdurur.'
    Category    = 'fixture'
    Risk        = 'Safe'
    Conditions  = @( @{ Not = 'IsLaptop' }, @{ MinBuild = 22000 } )
    Actions     = @(
        @{ Type = 'Service'; Name = 'FaiDemoSvc'; StartType = 'Disabled'; State = 'Stopped' }
    )
}
