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
        { Test-FaiSha256 -Path $f -HashText 'bozuk' } | Should -Throw '*invalid*'
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
        @{ B = @{ Session = 'abc'; UpdatesOn = $true } }
        @{ B = @{ SkipFailed = $true } }
        @{ B = @{ SkipFailed = $true; Profile = 'x' } }
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

    It 'rapor günlük dosyasına madde madde yazılır (Faz 9: dry-run raporu incelenir)' {
        $ctx = New-Env
        $ctx.Logger.Path = Join-Path $TestDrive 'logs/rapor.log'
        $path = Write-Profile 'rapor' @('ui.alpha')
        Invoke-Quiet { Invoke-FaiCli -Bound @{ Profile = $path; DryRun = $true } -Context $ctx -Catalog (New-TestCatalog) } | Should -Be 0
        $text = Get-Content -LiteralPath $ctx.Logger.Path -Raw -Encoding UTF8
        $text | Should -Match '\[PREVIEW\] ui\.alpha — Başlık ui\.alpha'
        $text | Should -Match '      · '
        $ctx.Logger.Entries | Where-Object { $_.Message -match 'ui\.alpha — ' } | Should -BeNullOrEmpty
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

    It '-Undo hatada oturumu açık bırakır (-Unattended soru sormaz); -Undo -SkipFailed kapatır' {
        $ctx = New-Env
        $ctx.Registry.Seed($script:Key, 'Alpha', 0, 'DWord')
        $cat = New-TestCatalog
        $path = Write-Profile 'skip' @('ui.alpha', 'ui.beta')
        Invoke-Quiet { Invoke-FaiCli -Bound @{ Profile = $path } -Context $ctx -Catalog $cat } | Should -Be 0
        $ctx.Registry.FailOnName = 'Alpha'
        Invoke-Quiet { Invoke-FaiCli -Bound @{ Undo = $true; Unattended = $true } -Context $ctx -Catalog $cat } | Should -Be 1
        $ctx.Prompt.Asked.Count | Should -Be 0
        $ctx.Backup.GetLatest() | Should -Not -BeNullOrEmpty
        $ctx.Registry.ValueExists($script:Key, 'Beta') | Should -BeFalse
        Invoke-Quiet { Invoke-FaiCli -Bound @{ Undo = $true; SkipFailed = $true; Unattended = $true } -Context $ctx -Catalog $cat } | Should -Be 0
        $ctx.Backup.GetLatest() | Should -BeNullOrEmpty
    }

    It '-Profile -Session: devam aynı oturuma yazar' {
        $ctx = New-Env
        $cat = New-TestCatalog
        Invoke-Quiet { Invoke-FaiCli -Bound @{ Profile = (Write-Profile 'd1' @('ui.alpha')) } -Context $ctx -Catalog $cat } | Should -Be 0
        $id = $ctx.Backup.ListSessionIds()[0]
        Invoke-Quiet { Invoke-FaiCli -Bound @{ Profile = (Write-Profile 'd2' @('ui.beta')); Session = $id } -Context $ctx -Catalog $cat } | Should -Be 0
        $ctx.Backup.ListSessionIds() | Should -Be @($id)
        $ctx.Backup.Load($id).Entries.Count | Should -Be 2
        Invoke-Quiet { Invoke-FaiCli -Bound @{ Undo = $true } -Context $ctx -Catalog $cat } | Should -Be 0
        $ctx.Registry.ValueExists($script:Key, 'Alpha') | Should -BeFalse
        $ctx.Registry.ValueExists($script:Key, 'Beta') | Should -BeFalse
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

Describe 'Oturum sahibi denetimi (3.1)' {
    BeforeAll {
        $script:Me = @{ Name = 'PC\fai'; Sid = 'S-1-5-21-1-2-3-1001' }
        $script:Other = @{ Name = 'PC\yonetici'; Sid = 'S-1-5-21-1-2-3-500' }
        function New-SessionUser([hashtable] $Process, [AllowNull()] [hashtable] $Owner) {
            return [FakeSessionUserProvider]::new($Process, $Owner)
        }
    }

    It 'Test-FaiSessionUser: SID varsa SID, yoksa ad (harf duyarsız); sahip yoksa Unknown' {
        (Test-FaiSessionUser -Provider (New-SessionUser $script:Me $script:Me))['Status'] | Should -Be 'Same'
        $r = Test-FaiSessionUser -Provider (New-SessionUser $script:Other $script:Me)
        $r['Status'] | Should -Be 'Other'
        $r['Process'] | Should -Be 'PC\yonetici'
        $r['Owner'] | Should -Be 'PC\fai'
        (Test-FaiSessionUser -Provider (New-SessionUser @{ Name = 'PC\FAI'; Sid = '' } @{ Name = 'pc\fai'; Sid = '' }))['Status'] | Should -Be 'Same'
        (Test-FaiSessionUser -Provider (New-SessionUser $script:Me $null))['Status'] | Should -Be 'Unknown'
    }

    It 'aynı kullanıcı → sürer' {
        $ctx = New-Env
        $path = Write-Profile 'oturum1' @('ui.alpha')
        $code = Invoke-Quiet { Invoke-FaiCli -Bound @{ Profile = $path } -Context $ctx -Catalog (New-TestCatalog) -SessionUser (New-SessionUser $script:Me $script:Me) }
        $code | Should -Be 0
        $ctx.Registry.GetValue($script:Key, 'Alpha') | Should -Be 1
        $ctx.Logger.Count('WARN') | Should -Be 0
    }

    It 'farklı kullanıcı → durur (3), hiçbir yazma yok; -DryRun da durur' {
        $path = Write-Profile 'oturum2' @('ui.alpha')
        foreach ($b in @(@{ Profile = $path }, @{ Profile = $path; DryRun = $true }, @{ Undo = $true })) {
            $ctx = New-Env
            $code = Invoke-Quiet { Invoke-FaiCli -Bound $b -Context $ctx -Catalog (New-TestCatalog) -SessionUser (New-SessionUser $script:Other $script:Me) }
            $code | Should -Be 3
            $ctx.Registry.WriteCount | Should -Be 0
        }
    }

    It 'farklı kullanıcı + -AllowOtherUser → sürer, günlüğe uyarı' {
        $ctx = New-Env
        $path = Write-Profile 'oturum3' @('ui.alpha')
        $bound = @{ Profile = $path; AllowOtherUser = [System.Management.Automation.SwitchParameter]::new($true) }
        $code = Invoke-Quiet { Invoke-FaiCli -Bound $bound -Context $ctx -Catalog (New-TestCatalog) -SessionUser (New-SessionUser $script:Other $script:Me) }
        $code | Should -Be 0
        $ctx.Registry.GetValue($script:Key, 'Alpha') | Should -Be 1
        @($ctx.Logger.Entries | Where-Object { $_.Level -eq 'WARN' -and $_.Message -match 'AllowOtherUser' -and $_.Message -match 'yonetici' }).Count | Should -Be 1
    }

    It 'oturum sahibi bulunamadı → uyarır ve sürer' {
        $ctx = New-Env
        $path = Write-Profile 'oturum4' @('ui.alpha')
        $code = Invoke-Quiet { Invoke-FaiCli -Bound @{ Profile = $path } -Context $ctx -Catalog (New-TestCatalog) -SessionUser (New-SessionUser $script:Me $null) }
        $code | Should -Be 0
        $ctx.Registry.GetValue($script:Key, 'Alpha') | Should -Be 1
        @($ctx.Logger.Entries | Where-Object { $_.Level -eq 'WARN' -and $_.Message -match 'owner not found' }).Count | Should -Be 1
    }

    It 'yönetici gerektirmeyen yollar (-List, -ExportProfile) denetlenmez' {
        $other = New-SessionUser $script:Other $script:Me
        Invoke-Quiet { Invoke-FaiCli -Bound @{ List = $true } -Context (New-Env) -Catalog (New-TestCatalog) -SessionUser $other } | Should -Be 0
        $out = Join-Path $TestDrive 'oturum-disa.json'
        Invoke-Quiet { Invoke-FaiCli -Bound @{ ExportProfile = $out } -Context (New-Env) -Catalog (New-TestCatalog) -SessionUser $other } | Should -Be 0
        Test-Path -LiteralPath $out | Should -BeTrue
    }
}

Describe 'Yeniden başlatmada mutlak yollar (3.2)' {
    BeforeAll {
        $script:Cwd = 'C:\Users\fai\Desktop'
    }

    It 'ConvertTo-FaiAbsolutePath: göreli, .., kök göreli, mutlak, UNC' {
        ConvertTo-FaiAbsolutePath -Path '.\x.json' -BaseDir $script:Cwd | Should -Be 'C:\Users\fai\Desktop\x.json'
        ConvertTo-FaiAbsolutePath -Path 'p/x.json' -BaseDir $script:Cwd | Should -Be 'C:\Users\fai\Desktop\p\x.json'
        ConvertTo-FaiAbsolutePath -Path '..\..\p\x.json' -BaseDir "$script:Cwd\" | Should -Be 'C:\Users\p\x.json'
        ConvertTo-FaiAbsolutePath -Path '\p\x.json' -BaseDir $script:Cwd | Should -Be 'C:\p\x.json'
        ConvertTo-FaiAbsolutePath -Path 'D:\a\.\b\..\x.json' -BaseDir $script:Cwd | Should -Be 'D:\a\x.json'
        ConvertTo-FaiAbsolutePath -Path '\\srv\pay\x.json' -BaseDir $script:Cwd | Should -Be '\\srv\pay\x.json'
    }

    It 'ConvertTo-FaiAbsoluteBound: yol alanlar mutlak; ad, URL ve diğer parametreler aynen' {
        $b = @{ Profile = '.\x.json'; ExportProfile = 'disa\ev.json'; Only = @('a'); Session = 'abc' }
        $r = ConvertTo-FaiAbsoluteBound -Bound $b -BaseDir $script:Cwd
        $r['Profile'] | Should -Be 'C:\Users\fai\Desktop\x.json'
        $r['ExportProfile'] | Should -Be 'C:\Users\fai\Desktop\disa\ev.json'
        $r['Session'] | Should -Be 'abc'
        $b['Profile'] | Should -Be '.\x.json'
        (ConvertTo-FaiAbsoluteBound -Bound @{ Profile = 'fedai'; ExportProfile = 'ev' } -BaseDir $script:Cwd)['Profile'] | Should -Be 'fedai'
        (ConvertTo-FaiAbsoluteBound -Bound @{ ExportProfile = 'ev' } -BaseDir $script:Cwd)['ExportProfile'] | Should -Be 'ev'
        (ConvertTo-FaiAbsoluteBound -Bound @{ Profile = 'https://x/y.json' } -BaseDir $script:Cwd)['Profile'] | Should -Be 'https://x/y.json'
    }

    It 'UAC (Invoke-FaiElevated): göreli -Profile mutlak argüman dizesine girer' {
        Mock Get-FaiWorkingDir { return 'C:\Users\fai\Desktop' }
        Mock Start-Process { $script:Started = $ArgumentList }
        $script:Started = ''
        $code = Invoke-Quiet { Invoke-FaiElevated -ScriptPath 'C:\t\install.ps1' -Bound @{ Profile = '.\x.json'; DryRun = $true } }
        $code | Should -Be 0
        $script:Started | Should -Be '-NoProfile -ExecutionPolicy Bypass -NoExit -File "C:\t\install.ps1" -DryRun -Profile "C:\Users\fai\Desktop\x.json"'
    }

    It '-Version yeniden başlatması: göreli -Profile / -ExportProfile mutlak, -Version yok' {
        Mock Get-FaiWorkingDir { return 'C:\Users\fai\Desktop' }
        Mock Get-FaiVerifiedScript { return 'C:\t\install-v0.0.1.ps1' }
        Mock Start-Process { $script:Started = $ArgumentList; return [pscustomobject]@{ ExitCode = 0 } }
        $script:Started = ''
        $oldTemp = $env:TEMP
        $env:TEMP = $TestDrive
        try {
            $code = Invoke-Quiet { Invoke-FaiCli -Bound @{ Version = 'v0.0.1'; FaiProfile = '..\p\x.json'; DryRun = $true } -Context (New-Env) -Catalog (New-TestCatalog) }
            $code | Should -Be 0
            $script:Started | Should -Be '-NoProfile -ExecutionPolicy Bypass -File "C:\t\install-v0.0.1.ps1" -DryRun -Profile "C:\Users\fai\p\x.json"'
            $code = Invoke-Quiet { Invoke-FaiCli -Bound @{ Version = 'v0.0.1'; ExportProfile = '.\ev.json' } -Context (New-Env) -Catalog (New-TestCatalog) }
            $code | Should -Be 0
            $script:Started | Should -BeLike '* -ExportProfile "C:\Users\fai\Desktop\ev.json"'
        }
        finally { $env:TEMP = $oldTemp }
    }

    It 'devam komutu (Get-FaiResumeCommand): göreli -Profile mutlak' {
        Mock Get-FaiWorkingDir { return 'C:\Users\fai\Desktop' }
        $src = Join-Path $TestDrive 'resume-rel.ps1'
        [System.IO.File]::WriteAllText($src, '# betik')
        $cmd = Get-FaiResumeCommand -ScriptPath $src -Bound @{ Profile = '.\x.json'; Unattended = $true } -DataDir (Join-Path $TestDrive 'resume-rel')
        $cmd | Should -BeLike '* -Profile "C:\Users\fai\Desktop\x.json" -Unattended'
    }
}

Describe 'Menü' {
    It 'ConvertFrom-FaiSelection: tek, liste, aralık; aralık dışı hata' {
        $a = ConvertFrom-FaiSelection -Text '3 1,2' -Count 5
        $a | Should -Be @(1, 2, 3)
        $b = ConvertFrom-FaiSelection -Text '4-2 5' -Count 5
        $b | Should -Be @(2, 3, 4, 5)
        (ConvertFrom-FaiSelection -Text '' -Count 5).Count | Should -Be 0
        { ConvertFrom-FaiSelection -Text '6' -Count 5 } | Should -Throw '*Out of range*'
        { ConvertFrom-FaiSelection -Text 'x' -Count 5 } | Should -Throw '*Not understood*'
    }

    It 'Get-FaiMenuCategory sabit sıra ve Türkçe başlık' {
        $cats = Get-FaiMenuCategory -Catalog (New-TestCatalog)
        @($cats | ForEach-Object { $_.Name }) | Should -Be @('ui', 'privacy', 'refresh')
        $cats[0].Label | Should -Be 'Interface'
        @($cats[0].Tweaks | ForEach-Object { $_.Id }) | Should -Be @('ui.alpha', 'ui.beta')
    }

    It 'kategori → onay kutusu → önizle (yazma yok) → uygula' {
        # 2: tweak seç · 1: Interface · 2: beta'yı işaretle · Enter: tamam · r: çalıştır · p: önizle · a: uygula · Enter: geri · 0
        $ctx = New-Env -Answers @('2', '1', '2', '', 'r', 'p', 'a', '', '0')
        Invoke-Quiet { Invoke-FaiMenu -Context $ctx -Catalog (New-TestCatalog) } | Should -Be 0
        $ctx.Registry.GetValue($script:Key, 'Beta') | Should -Be 1
        $ctx.Registry.ValueExists($script:Key, 'Alpha') | Should -BeFalse
        $ctx.DryRun | Should -BeFalse
        @($ctx.Prompt.Asked | Where-Object { $_.Kind -eq 'ReadLine' }).Count | Should -Be 9
    }

    It 'önizleme yalnız dry-run; B ile çıkınca hiçbir şey yazılmaz' {
        $ctx = New-Env -Answers @('2', '1', 'a', '', 'r', 'p', 'b', '', '0')
        Invoke-Quiet { Invoke-FaiMenu -Context $ctx -Catalog (New-TestCatalog) } | Should -Be 0
        $ctx.Registry.WriteCount | Should -Be 0
    }

    It 'profil seçimi: dosya yolu ile uygular' {
        $path = Write-Profile 'menu' @('privacy.gamma')
        $ctx = New-Env -Answers @('1', 'f', $path, 'a', '0')
        Invoke-Quiet { Invoke-FaiMenu -Context $ctx -Catalog (New-TestCatalog) } | Should -Be 0
        $ctx.Registry.GetValue($script:Key, 'Gamma') | Should -Be 1
    }

    It 'araçlar: Caution araç onayla uygulanır' {
        $ctx = New-Env -Answers @('5', '1', 'a', 'Y', '0')
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

Describe 'Veri klasörü (Initialize-FaiRunStorage)' {
    BeforeAll {
        $script:DataDir = 'C:\ProgramData\FAI_WinOP'
        $script:UserDir = 'C:\Users\fai\AppData\Local\FAI_WinOP'
    }

    It '-ExportProfile ve -ExportLayout yönetici istemez; diğer işler ister' {
        Test-FaiNeedsAdmin -Options @{ ExportProfile = 'ev' } | Should -BeFalse
        Test-FaiNeedsAdmin -Options @{ ExportLayout = $true } | Should -BeFalse
        Test-FaiNeedsAdmin -Options @{ ExportLayout = $true; Profile = 'C:\x\layout.json' } | Should -BeFalse
        Test-FaiNeedsAdmin -Options @{ Profile = 'fedai' } | Should -BeTrue
        Test-FaiNeedsAdmin -Options @{ Undo = $true } | Should -BeTrue
        Test-FaiNeedsAdmin -Options @{ ExportProfile = '' } | Should -BeTrue
        Test-FaiNeedsAdmin -Options @{} | Should -BeTrue
    }

    It '-ExportProfile / -ExportLayout yolu ProgramData''ya dokunmaz: sağlayıcı hiç çağrılmaz, günlük ve yedek kullanıcıda' {
        foreach ($opts in @(@{ ExportProfile = 'ev' }, @{ ExportLayout = $true })) {
            $sec = [FakeFileSecurityProvider]::new()
            $st = Initialize-FaiRunStorage -NeedsAdmin (Test-FaiNeedsAdmin -Options $opts) -Security $sec -DataDir $script:DataDir -UserDataDir $script:UserDir
            $sec.CallLog.Count | Should -Be 0
            $sec.Touched('C:\ProgramData') | Should -BeFalse
            $st['LogDir'] | Should -BeLike "$script:UserDir*"
            $st['BackupRoot'] | Should -BeLike "$script:UserDir*"
            $st['LogDir'] | Should -Not -BeLike '*ProgramData*'
            @($st['Quarantined']).Count | Should -Be 0
        }
    }

    It 'yönetici işi veri klasörünü önce korur; günlük ve yedek orada, kenara alınanlar döner' {
        $sec = [FakeFileSecurityProvider]::new()
        $sec.SeedDirectory($script:DataDir, 'S-1-5-32-544')
        $sec.SeedFile("$script:DataDir\BloatCleanup.ps1", 'S-1-5-21-1000-1000-1000-1001')
        $st = Initialize-FaiRunStorage -NeedsAdmin $true -Security $sec -DataDir $script:DataDir -UserDataDir $script:UserDir
        Test-FaiRestrictedAcl -Acl $sec.GetAcl($script:DataDir) | Should -BeTrue
        @($st['AclFixed']) | Should -Contain $script:DataDir
        @($st['Quarantined']).Count | Should -Be 1
        $st['LogDir'] | Should -BeLike "$script:DataDir*"
        $st['BackupRoot'] | Should -BeLike "$script:DataDir*"
    }

    It 'devam kopyası shared\ altına yazılır' {
        $data = Join-Path $TestDrive 'resume-data'
        $src = Join-Path $TestDrive 'resume-src.ps1'
        [System.IO.File]::WriteAllText($src, '# betik')
        $cmd = Get-FaiResumeCommand -ScriptPath $src -Bound @{ Profile = 'fedai' } -DataDir $data
        $target = Join-Path (Join-Path $data 'shared') 'install.ps1'
        Test-Path -LiteralPath $target | Should -BeTrue
        $cmd | Should -BeLike ('*"{0}"*' -f $target)
    }
}

Describe 'Kenar durumları (3.5)' {
    It 'a) -Version: V büyük harfle kırpılır; biçim hatalıysa kullanım hatası (2)' {
        Mock Get-FaiVerifiedScript { $script:BaseUrlSeen = $BaseUrl; return 'C:\t\install.ps1' }
        Mock Start-Process { return [pscustomobject]@{ ExitCode = 0 } }
        $oldTemp = $env:TEMP
        $env:TEMP = $TestDrive
        try {
            $code = Invoke-Quiet { Invoke-FaiCli -Bound @{ Version = 'V9.8.7' } -Context (New-Env) -Catalog (New-TestCatalog) }
            $code | Should -Be 0
            $script:BaseUrlSeen | Should -BeLike '*/releases/download/v9.8.7'
        }
        finally { $env:TEMP = $oldTemp }
        foreach ($bad in @('vv1.2.3', '1.2', 'v1.2.3-x', 'abc')) {
            Invoke-Quiet { Invoke-FaiCli -Bound @{ Version = $bad } -Context (New-Env) -Catalog (New-TestCatalog) } | Should -Be 2
        }
    }

    It 'b) -ExportLayout ile -Only / -Skip kullanım hatası; -Profile ile korunur' {
        Invoke-Quiet { Invoke-FaiCli -Bound @{ ExportLayout = $true; Only = @('ui.alpha') } -Context (New-Env) -Catalog (New-TestCatalog) } | Should -Be 2
        Invoke-Quiet { Invoke-FaiCli -Bound @{ ExportLayout = $true; Skip = @('ui.alpha') } -Context (New-Env) -Catalog (New-TestCatalog) } | Should -Be 2
        $path = Write-Profile 'dis-duzen' @('ui.alpha')
        Invoke-Quiet { Invoke-FaiCli -Bound @{ ExportLayout = $true; Profile = $path } -Context (New-Env) -Catalog (New-TestCatalog) } | Should -Not -Be 2
    }

    It 'c) menüden çalışan iş hatalıysa çıkış 1, yoksa 0' {
        $path = Write-Profile 'menu-hata' @('privacy.gamma')
        $ctx = New-Env -Answers @('1', 'f', $path, 'a', '0')
        $ctx.Registry.FailOnName = 'Gamma'
        Invoke-Quiet { Invoke-FaiMenu -Context $ctx -Catalog (New-TestCatalog) } | Should -Be 1
        $ctx2 = New-Env -Answers @('1', 'f', $path, 'a', '0')
        Invoke-Quiet { Invoke-FaiMenu -Context $ctx2 -Catalog (New-TestCatalog) } | Should -Be 0
    }

    It 'd) -ExportProfile: denetlenemeyen tweak uyarılır, profile alınmaz' {
        $ctx = New-Env
        $ctx.Registry.Seed($script:Key, 'Alpha', 1, 'DWord')
        $cat = New-TestCatalog
        # Motor, Test istisna atan tweak'i 'Failed' raporlar (Engine: 'action N (...) could not be checked').
        Mock Invoke-FaiEngine {
            $r = [Reporter]::new()
            [void]$r.Add('ui.alpha', 'A', 'UpToDate', '', [string[]]@())
            [void]$r.Add('ui.beta', 'B', 'Failed', 'action 1 (Registry) could not be checked: access denied', [string[]]@())
            return $r
        }
        $data = Invoke-Quiet { Export-FaiProfile -Context $ctx -Catalog $cat -Name 'disa' }
        @($data['tweaks']) | Should -Be @('ui.alpha')
        @($ctx.Logger.Entries | Where-Object { $_.Message -match 'ui\.beta could not be checked, not added to the profile: ' }).Count | Should -Be 1
    }

    It 'e) devam kopyası başarısızsa Get-FaiResumeCommand hata verir (RunOnce yazılmaz)' {
        { Get-FaiResumeCommand -ScriptPath (Join-Path $TestDrive 'yok.ps1') -Bound @{ Profile = 'x' } -DataDir (Join-Path $TestDrive 'resume-yok') } | Should -Throw
    }
}

