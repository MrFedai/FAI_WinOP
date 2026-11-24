# Birim testleri için yükleyici: Fake sağlayıcılı bundle'ı TestDrive'a üretip nokta-kaynak yapar.
# Sınıflar yalnız nokta-kaynak yapılan kapsamda görünür; bu yüzden her *.Tests.ps1 BeforeAll içinde şöyle çağırır:
#     . (Join-Path $PSScriptRoot 'Load-Fakes.ps1')
# Üretim bundle'ıyla (Bundle.ps1) aynı sıra ve aynı 5.1 sözdizimi kullanılır; testler paketlenmiş koda karşı koşar.

$script:FaiRepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$script:FaiFixtures = Join-Path $script:FaiRepoRoot 'tests/Fixtures'
$faiBundleOut = Join-Path $TestDrive 'install.fakes.ps1'
& (Join-Path $script:FaiRepoRoot 'build/Bundle.ps1') -OutFile $faiBundleOut -IncludeFakes 6>&1 | Out-Null
. $faiBundleOut
