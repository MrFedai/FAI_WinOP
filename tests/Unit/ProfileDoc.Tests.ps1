#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }
# build/ProfileDoc.ps1: README'deki "What the fedai profile does" bölgesi profil / tweak / katalog verisinden üretilir;
# -Check güncel değilse 1 döner. Betik ayrı süreçte çalışır (kendi bundle'ını üretir).

BeforeAll {
    $script:Root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    $script:Script = Join-Path $script:Root 'build/ProfileDoc.ps1'
    $script:Readme = Join-Path $script:Root 'README.md'
    function Invoke-ProfileDoc([string[]] $Arguments) {
        # 5.1: 2>&1 ile gelen stderr satırı ErrorRecord olur; Stop altında testi düşürmesin
        $ErrorActionPreference = 'Continue'
        $out = & pwsh -NoProfile -File $script:Script @Arguments 2>&1
        return @{ Exit = $LASTEXITCODE; Out = ($out -join "`n") }
    }
}

Describe 'README profil bölümü' {
    It 'bölge işaretleri README''de var, sırayla ve bir kez' {
        $text = Get-Content -LiteralPath $script:Readme -Raw
        ([regex]::Matches($text, [regex]::Escape('<!-- profile:fedai:begin -->'))).Count | Should -Be 1
        ([regex]::Matches($text, [regex]::Escape('<!-- profile:fedai:end -->'))).Count | Should -Be 1
        $text.IndexOf('<!-- profile:fedai:begin -->') | Should -BeLessThan $text.IndexOf('<!-- profile:fedai:end -->')
    }

    It 'README güncel (-Check)' {
        $r = Invoke-ProfileDoc @('-Check')
        $r.Exit | Should -Be 0 -Because ('build/ProfileDoc.ps1 çalıştırılmalı: ' + $r.Out)
    }

    It 'profilden bir tweak çıkınca -Check 1 döner' {
        $profilePath = Join-Path $TestDrive 'fedai.json'
        $data = Get-Content -LiteralPath (Join-Path $script:Root 'profiles/fedai.json') -Raw | ConvertFrom-Json
        $data.tweaks = @($data.tweaks | Where-Object { $_ -ne 'ui.widgets-off' })
        ($data | ConvertTo-Json -Depth 20) | Set-Content -LiteralPath $profilePath -Encoding UTF8
        $r = Invoke-ProfileDoc @('-Check', '-ProfilePath', $profilePath)
        $r.Exit | Should -Be 1
    }

    It 'işaretsiz README hata verir' {
        $path = Join-Path $TestDrive 'README.md'
        Set-Content -LiteralPath $path -Value 'no markers' -Encoding UTF8
        $r = Invoke-ProfileDoc @('-Check', '-ReadmePath', $path)
        $r.Exit | Should -Not -Be 0
    }

    It 'README''de Türkçe harf yok' {
        (Get-Content -LiteralPath $script:Readme -Raw) | Should -Not -MatchExactly '[çğıöşüÇĞİÖŞÜ]'
    }
}
