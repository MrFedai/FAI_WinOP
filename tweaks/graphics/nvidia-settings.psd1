@{
    Id          = 'graphics.nvidia-settings'
    Title       = 'NVIDIA: tepsi simgesi ve eski keskinleştirme kapalı'
    Description = 'Yalnız kayıt defteriyle yapılabilen NVIDIA ayarları: oturum açılışında NVIDIA tepsi simgesi başlamaz (NvTray\StartOnLogin=0) ve eski görüntü keskinleştirme ölçekleyicisi kapanır (nvlddmkm FTS\EnableGR535=0; yalnız sürücünün oluşturduğu FTS anahtarı varsa yazılır). Denetim Masası ayarları (düşük gecikme, güç yönetimi, dikey eşitleme, doku filtreleme…) NVIDIA DRS veritabanındadır; imzasız üçüncü parti araç (Profile Inspector) kullanılmadığından bu tweak''in kapsamı dışındadır (NVAPI ile sonra). Gerçek NVIDIA donanımında doğrulanmadı.'
    Category    = 'graphics'
    Risk        = 'Safe'
    Conditions  = @('HasNvidia')
    Actions     = @(
        @{ Type = 'Registry'; Path = 'HKCU:\Software\NVIDIA Corporation\NvTray'; Name = 'StartOnLogin'; Value = 0; Kind = 'DWord' }
        @{ Type = 'RegistryEach'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm'; Include = @('FTS'); Name = 'EnableGR535'; Value = 0; Kind = 'DWord' }
        @{ Type = 'RegistryEach'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm'; Include = @('Parameters'); SubKey = 'FTS'; Name = 'EnableGR535'; Value = 0; Kind = 'DWord' }
    )
}
