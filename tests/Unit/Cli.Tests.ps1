#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }
# Faz 8: gömülü veri, CLI (Invoke-FaiCli), menü (Invoke-FaiMenu), -ExportProfile, SHA-256 doğrulama. Fake sağlayıcılar.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Load-Fakes.ps1')

    $script:Key = 'HKCU:\Software\FAI_WinOP_Test\Cli'
    $script:Seq = 0

    function New-Env {
        param([string[]] $Answers = @())
        $script:Seq++
        return (New-FakeContext -BackupRoot (Join-Path $TestDrive ("cli{0}" -f $script:Seq)) -Answers $Answers)
    }

    function New-T {
        param([string] $Id, [string] $Category = 'ui', [string] $Risk = 'Safe', [string] $Name = 'V', [switch] $Tool)
        $d = @{
            Id = $Id; Title = "Başlık $Id"; Description = 'test'; Category = $Category; Risk = $Risk
            Actions = @(@{ Type = 'Registry'; Path = $script:Key; Name = $Name; Value = 1; Kind = 'DWord' })
        }
        if ($Tool) { $d['Tool'] = $true }
        return [Tweak]::FromHashtable($d, 'test')
    }

    function New-TestCatalog {
        $c = @{}
        foreach ($t in @(
                (New-T -Id 'ui.alpha' -Name 'Alpha'),
                (New-T -Id 'ui.beta' -Name 'Beta'),
                (New-T -Id 'privacy.gamma' -Category 'privacy' -Name 'Gamma'),
                (New-T -Id 'refresh.tool' -Category 'refresh' -Risk 'Caution' -Name 'Tool' -Tool)
            )) { $c[$t.Id] = $t }
        return $c
    }

    function Write-Profile([string] $Name, [string[]] $Ids) {
        $path = Join-Path $TestDrive ($Name + '.json')
        $json = @{ name = $Name; tweaks = @($Ids) } | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding($false)))
        return $path
    }

    function Invoke-Quiet([scriptblock] $Body) { return (& $Body 6>$null) }
}

Describe 'Gömülü veri (bundle)' {
    It 'tweak kataloğu dosyadan okunanla aynı kimlikleri verir' {
        $embedded = Import-FaiEmbeddedTweakCatalog
        $files = Import-FaiTweakCatalog -Path (Join-Path $script:FaiRepoRoot 'tweaks')
        @($embedded.Keys | Sort-Object) | Should -Be @($files.Keys | Sort-Object)
        $embedded['sound.volume'].Params['level'] | Should -Be 15
    }

    It "satır başında '@ içeren dosya (base64) birebir aynı gelir" {
        $data = Get-FaiDataFile -Prefix 'tweaks/bloat/edge-remove.psd1'
        $disk = [System.IO.File]::ReadAllText((Join-Path $script:FaiRepoRoot 'tweaks/bloat/edge-remove.psd1'), [System.Text.Encoding]::UTF8).TrimStart([char]0xFEFF)
        ($data['tweaks/bloat/edge-remove.psd1'] -replace "`r`n", "`n") | Should -Be (($disk -replace "`r`n", "`n").TrimEnd())
    }

    It 'uygulama kataloğu ve profiller gömülü; _schema.json gömülmez' {
        (Import-FaiEmbeddedAppCatalog).ContainsKey('chrome') | Should -BeTrue
        $names = Get-FaiEmbeddedProfileName
        $names | Should -Contain 'fedai'
        (Get-FaiDataFile -Prefix 'profiles/').Keys | Should -Not -Contain 'profiles/_schema.json'
    }

    It 'fedai profili geçerli; tweak ve uygulamaların hepsi katalogda, araç yok' {
        $p = Import-FaiEmbeddedProfile -Name 'fedai'
        $catalog = Import-FaiEmbeddedTweakCatalog
        $apps = Import-FaiEmbeddedAppCatalog
        foreach ($t in $p.Tweaks) {
            $catalog.ContainsKey([string]$t['Id']) | Should -BeTrue -Because $t['Id']
            $catalog[[string]$t['Id']].Tool | Should -BeFalse
        }
        foreach ($a in $p.Apps) { $apps.ContainsKey([string]$a['Id']) | Should -BeTrue -Because $a['Id'] }
        @($p.Apps).Count | Should -Be 12
    }

    It 'bilinmeyen gömülü profil gömülü adları listeler' {
        { Import-FaiEmbeddedProfile -Name 'yok' } | Should -Throw '*fedai*'
    }
}

Describe 'ConvertFrom-FaiPsd1Text' {
    It 'sabit değerleri okur' {
        $h = ConvertFrom-FaiPsd1Text -Text "@{ A = 1; B = @('x', 'y'); C = @{ D = `$true } }"
        $h['A'] | Should -Be 1
        $h['B'] | Should -Be @('x', 'y')
        $h['C']['D'] | Should -BeTrue
    }

    It 'kod içeren veriyi YÜRÜTMEZ, reddeder' {
        { ConvertFrom-FaiPsd1Text -Text "@{ A = (Get-Date) }" -Source 'kotu.psd1' } | Should -Throw '*kotu.psd1*'
    }
}

Describe 'CLI yardımcıları' {
    It 'Split-FaiList virgüllü tek metni ve diziyi açar' {
        $r = Split-FaiList -Items @('a,b', ' c ', 'a', '')
        $r | Should -Be @('a', 'b', 'c')
        (Split-FaiList -Items @()).Count | Should -Be 0
    }

    It 'ConvertTo-FaiArgumentString: anahtarlar sıralı, kapalı switch yok, dizi virgüllü, Exclude' {
        $b = @{
            Profile = 'C:\p q\x.json'; DryRun = [System.Management.Automation.SwitchParameter]::new($true)
            Unattended = [System.Management.Automation.SwitchParameter]::new($false); Only = @('a', 'b'); Version = 'v1.0.0'
        }
        ConvertTo-FaiArgumentString -Bound $b -Exclude @('Version') | Should -Be '-DryRun -Only "a,b" -Profile "C:\p q\x.json"'
    }

    It 'Test-FaiSha256 eşleşme / eşleşmeme / bozuk biçim' {
        $f = Join-Path $TestDrive 'h.txt'
        [System.IO.File]::WriteAllText($f, 'merhaba')
        $hash = (Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash.ToLowerInvariant()
        Test-FaiSha256 -Path $f -HashText "$hash  install.ps1`n" | Should -BeTrue
        Test-FaiSha256 -Path $f -HashText $hash.ToUpperInvariant() | Should -BeTrue
        Test-FaiSha256 -Path $f -HashText ('0' * 64) | Should -BeFalse
        { Test-FaiSha256 -Path $f -HashText 'bozuk' } | Should -Throw '*geçersiz*'
    }

    It 'Resolve-FaiProfile: düz http reddedilir, yol ve gömülü ad çözülür' {
        { Resolve-FaiProfile -Spec 'http://example.invalid/p.json' } | Should -Throw '*https*'
        (Resolve-FaiProfile -Spec (Write-Profile 'yerel' @('ui.alpha'))).Name | Should -Be 'yerel'
        (Resolve-FaiProfile -Spec 'fedai').Name | Should -Be 'fedai'
    }

    It 'Select-FaiProfileItem: Only ve Skip tweak, app., gaming, layout kimliklerine uygulanır' {
        $p = [Profile]::FromHashtable(@{
                name = 'x'; tweaks = @('ui.alpha', 'ui.beta'); apps = @('chrome', 'obs')
                games = @(@{ exe = 'a.exe'; priority = 'High' }); layout = @{ taskbar = @{ autoHide = $true } }
            }, 'test')
        $s = Select-FaiProfileItem -FaiProfile $p -Skip @('ui.beta', 'app.obs', 'layout.profile')
        @($s.Tweaks | ForEach-Object { $_['Id'] }) | Should -Be @('ui.alpha')
        @($s.Apps | ForEach-Object { $_['Id'] }) | Should -Be @('chrome')
        @($s.Games).Count | Should -Be 1
        $s.Layout.Count | Should -Be 0
        $o = Select-FaiProfileItem -FaiProfile $p -Only @('ui.beta')
        @($o.Tweaks | ForEach-Object { $_['Id'] }) | Should -Be @('ui.beta')
        @($o.Apps).Count | Should -Be 0
        @($o.Games).Count | Should -Be 0
    }

    It 'New-FaiSelectionProfile bilinmeyen kimlikte hata verir' {
        { New-FaiSelectionProfile -Ids @('ui.alpha', 'ui.yok') -Catalog (New-TestCatalog) } | Should -Throw '*ui.yok*'
    }

    It 'Resolve-FaiExportTarget: ad → Belgeler klasörü, .json yolu → ad dosyadan' {
        $t = Resolve-FaiExportTarget -Spec 'Ev-PC' -DefaultDir $TestDrive
        $t.Name | Should -Be 'ev-pc'
        $t.Path | Should -Be (Join-Path $TestDrive 'Ev-PC.json')
        (Resolve-FaiExportTarget -Spec (Join-Path $TestDrive 'Benim Profil.json')).Name | Should -Be 'benim-profil'
    }
}

Describe 'Invoke-FaiCli' {
    It 'kullanım hataları 2 döndürür' -ForEach @(
        @{ B = @{ Undo = $true; Profile = 'x' } }
        @{ B = @{ UpdatesOn = $true; UpdatesOff = $true } }
        @{ B = @{ List = $true; Undo = $true } }
        @{ B = @{ Unattended = $true } }
        @{ B = @{ Session = 'abc' } }
        @{ B = @{ Skip = @('ui.alpha') } }
    ) {
        $code = Invoke-Quiet { Invoke-FaiCli -Bound $B -Context (New-Env) -Catalog (New-TestCatalog) }
        $code | Should -Be 2
    }

    It '-Profile <yol> -DryRun (giriş betiğinin FaiProfile anahtarı): 0, hiçbir yazma yok' {
        $ctx = New-Env
        $path = Write-Profile 'dry' @('ui.alpha', 'ui.beta')
        $code = Invoke-Quiet { Invoke-FaiCli -Bound @{ FaiProfile = $path; DryRun = $true } -Context $ctx -Catalog (New-TestCatalog) }
        $code | Should -Be 0
        $ctx.Registry.WriteCount | Should -Be 0
    }

    It '-Profile uygular, -Skip çıkarır; -Undo geri alır' {
        $ctx = New-Env
        $cat = New-TestCatalog
        $path = Write-Profile 'uyg' @('ui.alpha', 'ui.beta')
        Invoke-Quiet { Invoke-FaiCli -Bound @{ Profile = $path; Skip = @('ui.beta') } -Context $ctx -Catalog $cat } | Should -Be 0
        $ctx.Registry.GetValue($script:Key, 'Alpha') | Should -Be 1
        $ctx.Registry.ValueExists($script:Key, 'Beta') | Should -BeFalse
        Invoke-Quiet { Invoke-FaiCli -Bound @{ Undo = $true } -Context $ctx -Catalog $cat } | Should -Be 0
        $ctx.Registry.ValueExists($script:Key, 'Alpha') | Should -BeFalse
    }

    It '-Only profil olmadan yalnız verilenleri çalıştırır ve araçlara izin verir (onaylı)' {
        $ctx = New-Env -Answers @('E')
        Invoke-Quiet { Invoke-FaiCli -Bound @{ Only = @('refresh.tool,ui.beta') } -Context $ctx -Catalog (New-TestCatalog) } | Should -Be 0
        $ctx.Registry.GetValue($script:Key, 'Tool') | Should -Be 1
        $ctx.Registry.GetValue($script:Key, 'Beta') | Should -Be 1
        $ctx.Registry.ValueExists($script:Key, 'Alpha') | Should -BeFalse
    }

    It 'bilinmeyen -Only kimliği 1 döndürür' {
        Invoke-Quiet { Invoke-FaiCli -Bound @{ Only = @('ui.yok') } -Context (New-Env) -Catalog (New-TestCatalog) } | Should -Be 1
    }

    It '-UpdatesOff motordan geçer (dry-run: yazma yok)' {
        $ctx = New-Env
        Invoke-Quiet { Invoke-FaiCli -Bound @{ UpdatesOff = $true; DryRun = $true } -Context $ctx -Catalog (New-TestCatalog) } | Should -Be 0
        $ctx.Registry.WriteCount | Should -Be 0
    }

    It '-List 0 döndürür' {
        Invoke-Quiet { Invoke-FaiCli -Bound @{ List = $true } -Context (New-Env) -Catalog (New-TestCatalog) } | Should -Be 0
    }
}

Describe 'Menü' {
    It 'ConvertFrom-FaiSelection: tek, liste, aralık; aralık dışı hata' {
        $a = ConvertFrom-FaiSelection -Text '3 1,2' -Count 5
        $a | Should -Be @(1, 2, 3)
        $b = ConvertFrom-FaiSelection -Text '4-2 5' -Count 5
        $b | Should -Be @(2, 3, 4, 5)
        (ConvertFrom-FaiSelection -Text '' -Count 5).Count | Should -Be 0
        { ConvertFrom-FaiSelection -Text '6' -Count 5 } | Should -Throw '*Aralık dışı*'
        { ConvertFrom-FaiSelection -Text 'x' -Count 5 } | Should -Throw '*Anlaşılmadı*'
    }

    It 'Get-FaiMenuCategory sabit sıra ve Türkçe başlık' {
        $cats = Get-FaiMenuCategory -Catalog (New-TestCatalog)
        @($cats | ForEach-Object { $_.Name }) | Should -Be @('ui', 'privacy', 'refresh')
        $cats[0].Label | Should -Be 'Arayüz'
        @($cats[0].Tweaks | ForEach-Object { $_.Id }) | Should -Be @('ui.alpha', 'ui.beta')
    }

    It 'kategori → onay kutusu → önizle (yazma yok) → uygula' {
        # 2: tweak seç · 1: Arayüz · 2: beta'yı işaretle · Enter: tamam · c: çalıştır · ö: önizle · u: uygula · Enter: geri · 0
        $ctx = New-Env -Answers @('2', '1', '2', '', 'c', 'ö', 'u', '', '0')
        Invoke-Quiet { Invoke-FaiMenu -Context $ctx -Catalog (New-TestCatalog) } | Should -Be 0
        $ctx.Registry.GetValue($script:Key, 'Beta') | Should -Be 1
        $ctx.Registry.ValueExists($script:Key, 'Alpha') | Should -BeFalse
        $ctx.DryRun | Should -BeFalse
        @($ctx.Prompt.Asked | Where-Object { $_.Kind -eq 'ReadLine' }).Count | Should -Be 9
    }

    It 'önizleme yalnız dry-run; G ile çıkınca hiçbir şey yazılmaz' {
        $ctx = New-Env -Answers @('2', '1', 'h', '', 'c', 'ö', 'g', '', '0')
        Invoke-Quiet { Invoke-FaiMenu -Context $ctx -Catalog (New-TestCatalog) } | Should -Be 0
        $ctx.Registry.WriteCount | Should -Be 0
    }

    It 'profil seçimi: dosya yolu ile uygular' {
        $path = Write-Profile 'menu' @('privacy.gamma')
        $ctx = New-Env -Answers @('1', 'd', $path, 'u', '0')
        Invoke-Quiet { Invoke-FaiMenu -Context $ctx -Catalog (New-TestCatalog) } | Should -Be 0
        $ctx.Registry.GetValue($script:Key, 'Gamma') | Should -Be 1
    }

    It 'araçlar: Caution araç onayla uygulanır' {
        $ctx = New-Env -Answers @('5', '1', 'u', 'E', '0')
        Invoke-Quiet { Invoke-FaiMenu -Context $ctx -Catalog (New-TestCatalog) } | Should -Be 0
        $ctx.Registry.GetValue($script:Key, 'Tool') | Should -Be 1
    }

    It 'girdi kapalıysa (art arda boş) menü kapanır' {
        Invoke-Quiet { Invoke-FaiMenu -Context (New-Env) -Catalog (New-TestCatalog) } | Should -Be 0
    }
}

Describe 'Export-FaiProfile' {
    It 'hedef durumu sağlanan tweak''leri yazar, araçları yazmaz; çıktı geçerli profil' {
        $ctx = New-Env
        $ctx.Registry.Seed($script:Key, 'Alpha', 1, 'DWord')
        $ctx.Registry.Seed($script:Key, 'Tool', 1, 'DWord')
        $path = Join-Path $TestDrive 'disa.json'
        $data = Invoke-Quiet { Export-FaiProfile -Context $ctx -Catalog (New-TestCatalog) -Name 'disa' -Path $path }
        @($data['tweaks']) | Should -Be @('ui.alpha')
        $ctx.Registry.WriteCount | Should -Be 0
        $ctx.DryRun | Should -BeFalse
        $p = Import-FaiProfileFile -Path $path
        $p.Name | Should -Be 'disa'
        @($p.Tweaks | ForEach-Object { $_['Id'] }) | Should -Be @('ui.alpha')
    }
}
