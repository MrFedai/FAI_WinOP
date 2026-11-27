#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }
# Faz 0 kabulü: lint 5.1'de olmayan sözdizimini (bilerek eklenmiş ??) yakalıyor; BOM ve bundle denetimleri.

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    $script:Lint = Join-Path $RepoRoot 'build/Lint.ps1'
    $script:Bundle = Join-Path $RepoRoot 'build/Bundle.ps1'
    $script:Fixtures = Join-Path $RepoRoot 'tests/Fixtures/Lint'
    $script:Shell = (Get-Process -Id $PID).Path

    function Invoke-Child([string] $Script, [string[]] $Arguments) {
        $out = & $script:Shell -NoProfile -NonInteractive -File $Script @Arguments 2>&1 | Out-String
        [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $out }
    }
}

Describe 'build/Lint.ps1' {
    It '?? işlecini yakalar (PSUseCompatibleSyntax) ve 1 ile çıkar' {
        $r = Invoke-Child $Lint @('-Path', (Join-Path $Fixtures 'NullCoalescing.ps1'))
        $r.ExitCode | Should -Be 1
        # 5.1 ?? işlecini ayrıştıramaz: orada bulgu FAI.Parse olur (7'de PSUseCompatibleSyntax)
        $r.Output | Should -Match 'PSUseCompatibleSyntax|FAI\.Parse'
        $r.Output | Should -Match 'NullCoalescing\.ps1:5'
    }

    It '5.1 uyumlu dosyayı geçirir' {
        $r = Invoke-Child $Lint @('-Path', (Join-Path $Fixtures 'Clean51.ps1'))
        $r.ExitCode | Should -Be 0 -Because $r.Output
    }

    It 'Türkçe karakterli BOM olmayan dosyayı yakalar' {
        $noBom = Join-Path $TestDrive 'NoBom.ps1'
        [System.IO.File]::WriteAllText($noBom, "Write-Output 'açılış'`r`n", (New-Object System.Text.UTF8Encoding($false)))
        $r = Invoke-Child $Lint @('-Path', $noBom)
        $r.ExitCode | Should -Be 1
        $r.Output | Should -Match 'FAI\.Utf8Bom'
    }

    It 'yalnız ASCII baytlı BOM olmayan dosyayı geçirir (get.ps1)' {
        $ascii = Join-Path $TestDrive 'Ascii.ps1'
        [System.IO.File]::WriteAllText($ascii, "Write-Output 'ok'`r`n", (New-Object System.Text.UTF8Encoding($false)))
        $r = Invoke-Child $Lint @('-Path', $ascii)
        $r.ExitCode | Should -Be 0 -Because $r.Output
    }

    It 'ConvertFrom-Json -AsHashtable kullanımını yakalar (PSUseCompatibleCommands)' {
        $f = Join-Path $TestDrive 'AsHashtable.ps1'
        [System.IO.File]::WriteAllText($f, "`$h = '{}' | ConvertFrom-Json -AsHashtable`r`n`$h`r`n", (New-Object System.Text.UTF8Encoding($true)))
        $r = Invoke-Child $Lint @('-Path', $f)
        $r.ExitCode | Should -Be 1
        $r.Output | Should -Match 'PSUseCompatibleCommands'
    }
}

Describe 'Depo kodlaması' {
    It 'bütün .ps1 / .psd1 / .psm1 dosyaları UTF-8 BOM ile başlar (önyükleyici hariç)' {
        # -Include 5.1'de -LiteralPath ile yok sayılır: uzantı süzgeci Where-Object'te
        $files = Get-ChildItem -LiteralPath $RepoRoot -Recurse -File |
            Where-Object { @('.ps1', '.psd1', '.psm1') -contains $_.Extension -and $_.FullName -notmatch '[\\/](\.git|dist)[\\/]' -and $_.FullName -notmatch '[\\/]Bootstrap[\\/]get\.ps1$' }
        $files.Count | Should -BeGreaterThan 0
        $missing = foreach ($f in $files) {
            $b = [System.IO.File]::ReadAllBytes($f.FullName)
            if (-not ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)) { $f.FullName }
        }
        $missing | Should -BeNullOrEmpty
    }

    It 'önyükleyici (src/Bootstrap/get.ps1) BOM''suz ve yalnız ASCII: irm ile indirilip çözülür' {
        $b = [System.IO.File]::ReadAllBytes((Join-Path $RepoRoot 'src/Bootstrap/get.ps1'))
        ($b.Length -ge 3 -and $b[0] -eq 0xEF) | Should -BeFalse
        @($b | Where-Object { $_ -ge 0x80 }).Count | Should -Be 0
    }
}

Describe 'build/Bundle.ps1' {
    It 'ayrıştırılabilir, BOM lu bir install.ps1 üretir ve sürümü yazar' {
        $out = Join-Path $TestDrive 'install.ps1'
        $r = Invoke-Child $Bundle @('-OutFile', $out, '-Version', 'v9.9.9-test')
        $r.ExitCode | Should -Be 0 -Because $r.Output
        $b = [System.IO.File]::ReadAllBytes($out)
        $b[0..2] | Should -Be @(0xEF, 0xBB, 0xBF)
        $text = [System.IO.File]::ReadAllText($out)
        $text | Should -Match "FaiWinOPVersion = 'v9\.9\.9-test'"
        $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($out, [ref]$null, [ref]$errors)
        $errors | Should -BeNullOrEmpty
    }

    It 'geçersiz -Version (tırnak / enjeksiyon) reddedilir' {
        foreach ($bad in @("1.0.0'; calc; '", 'abc', '1.0', '')) {
            $out = Join-Path $TestDrive 'bad.ps1'
            $r = Invoke-Child $Bundle @('-OutFile', $out, '-Version', $bad)
            $r.ExitCode | Should -Not -Be 0 -Because "[$bad]"
            Test-Path $out | Should -BeFalse
        }
    }

    It 'üretim bundle''ına Fake sağlayıcılar GİRMEZ' {
        $out = Join-Path $TestDrive 'prod.ps1'
        $r = Invoke-Child $Bundle @('-OutFile', $out)
        $r.ExitCode | Should -Be 0 -Because $r.Output
        $text = [System.IO.File]::ReadAllText($out)
        $text | Should -Not -Match 'class Fake\w+'
        $text | Should -Not -Match '#region src/Providers/Fake/'
        $text | Should -Not -Match 'New-FakeContext'
        $text | Should -Match '#region src/Engine\.ps1'
    }

    It '-IncludeFakes: Fake''ler Interfaces''ten sonra, Engine''den önce gelir; varsayılan çıktı ayrı dosyadır' {
        $out = Join-Path $TestDrive 'fakes.ps1'
        $r = Invoke-Child $Bundle @('-OutFile', $out, '-IncludeFakes')
        $r.ExitCode | Should -Be 0 -Because $r.Output
        $text = [System.IO.File]::ReadAllText($out)
        $iface = $text.IndexOf('#region src/Core/Interfaces.ps1')
        $fake = $text.IndexOf('#region src/Providers/Fake/FakeRegistryProvider.ps1')
        $engine = $text.IndexOf('#region src/Engine.ps1')
        $iface | Should -BeGreaterOrEqual 0
        $fake | Should -BeGreaterThan $iface
        $engine | Should -BeGreaterThan $fake
        $text | Should -Match 'Fake\* sağlayıcıları içerir'
        $text.IndexOf('#region src/Core/Interfaces.ps1') | Should -Be $text.IndexOf('#region src/') -Because 'Interfaces ilk kaynak olmalı'
    }

    It 'Core dosyaları bağımlılık sırasında birleşir (ActionBase, ExecutionContext''ten sonra; Tweak, ActionBase''ten sonra)' {
        $out = Join-Path $TestDrive 'order.ps1'
        $r = Invoke-Child $Bundle @('-OutFile', $out)
        $r.ExitCode | Should -Be 0 -Because $r.Output
        $text = [System.IO.File]::ReadAllText($out)
        $pos = @{}
        foreach ($n in 'Interfaces', 'Logger', 'BackupStore', 'ExecutionContext', 'ActionBase', 'Tweak', 'Profile') {
            $pos[$n] = $text.IndexOf("#region src/Core/$n.ps1")
            $pos[$n] | Should -BeGreaterOrEqual 0 -Because "$n bundle'da olmalı"
        }
        $pos['ExecutionContext'] | Should -BeGreaterThan $pos['BackupStore']
        $pos['ExecutionContext'] | Should -BeGreaterThan $pos['Logger']
        $pos['ActionBase'] | Should -BeGreaterThan $pos['ExecutionContext']
        $pos['Tweak'] | Should -BeGreaterThan $pos['ActionBase']
        $text.IndexOf('#region src/Actions/Registry.ps1') | Should -BeGreaterThan $pos['ActionBase']
    }
}
