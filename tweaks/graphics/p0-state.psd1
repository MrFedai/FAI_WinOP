@{
    Id            = 'graphics.p0-state'
    Title         = 'NVIDIA: P0 güç durumunda sabit tut'
    Description   = 'NVIDIA ekran kartının dinamik P-state geçişlerini kapatır (DisableDynamicPstate=1): kart boştayken de en yüksek güç durumunda (P0) kalır, saat düşüşünden gelen gecikme sıçramaları azalır. Değer yalnız sağlayıcısı NVIDIA olan ekran bağdaştırıcısı sınıf anahtarına (0000, 0001…) yazılır; Intel / AMD anahtarlarına dokunulmaz. Dizüstünde pil süresi kısalır ve ısı artar; bu yüzden onay her çalıştırmada istenir (profil autoConfirm''i işlemez, -Unattended''da uygulanmaz). Sürücü yeniden yüklenince ya da yeniden başlatınca etkin olur. Not: etkisi gerçek donanımda ölçülmedi (Faz 9).'
    Category      = 'graphics'
    Risk          = 'Caution'
    AlwaysConfirm = $true
    Confirm       = 'Ekran kartı boştayken de tam güçte kalır: dizüstünde pil süresi kısalır ve ısı artar.'
    Conditions    = @('HasNvidia')
    Actions       = @(
        @{ Type = 'RegistryEach'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'; Include = @('[0-9][0-9][0-9][0-9]'); Match = @{ Name = 'ProviderName'; Like = @('NVIDIA*') }; Name = 'DisableDynamicPstate'; Value = 1; Kind = 'DWord' }
    )
}
