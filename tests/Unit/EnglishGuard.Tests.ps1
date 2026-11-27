#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }
# v0.2.0 bekçisi (5.5): kullanıcıya görünen metin İngilizce kalsın. Kod dosyalarında yalnız dize belirteçleri
# (tek / çift tırnak, here-string, çıplak argüman) taranır; yorumlar ve yorum tabanlı yardım bloğu taranmaz.
# Veri ve belge dosyaları (JSON, README, docs/TWEAKS.md, docs/APPS.md) tümüyle taranır. Testler kapsam dışı.

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    # Türkçe harfler (ç ğ ı ö ş ü Ç Ğ İ Ö Ş Ü), kaçışla. Eşleme harfe duyarlı (-cmatch): Windows PowerShell 5.1'de (.NET Framework)
    # harfe duyarsız eşlemede İ ve ı sıradan i / I ile eşleşir, her İngilizce metin Türkçe sayılırdı.
    $script:TurkishChars = '[çğıöşüÇĞİÖŞÜ]'
    # Bilerek Türkçe harf taşıyan dize: 'dosya göreli yolu|dizenin bir parçası'
    $script:Allowed = @()

    function Get-RelPath([string] $Path) {
        return $Path.Substring($script:RepoRoot.Length + 1).Replace('\', '/')
    }

    function Test-Allowed([string] $Rel, [string] $Text) {
        foreach ($a in $script:Allowed) {
            $parts = $a -split '\|', 2
            if ($parts[0] -eq $Rel -and $Text.Contains($parts[1])) { return $true }
        }
        return $false
    }

    $script:StringKinds = @('StringLiteral', 'StringExpandable', 'HereStringLiteral', 'HereStringExpandable', 'Generic')
}

Describe 'Kullanıcıya görünen metin İngilizce (bekçi)' {
    It 'src / build / tweaks: dize belirteçlerinde Türkçe harf yok' {
        $files = @()
        foreach ($d in @('src', 'build', 'tweaks')) {
            $files += @(Get-ChildItem -Path (Join-Path $RepoRoot $d) -Recurse -File -Include '*.ps1', '*.psd1', '*.psm1')
        }
        $files.Count | Should -BeGreaterThan 50
        $hits = New-Object 'System.Collections.Generic.List[string]'
        foreach ($f in $files) {
            $tokens = $null; $errors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref] $tokens, [ref] $errors)
            $rel = Get-RelPath $f.FullName
            foreach ($t in $tokens) {
                if ($script:StringKinds -notcontains [string]$t.Kind) { continue }
                if ($t.Text -cnotmatch $script:TurkishChars) { continue }
                if (Test-Allowed $rel $t.Text) { continue }
                $txt = $t.Text
                if ($txt.Length -gt 80) { $txt = $txt.Substring(0, 80) + '…' }
                $hits.Add(('{0}:{1}: {2}' -f $rel, $t.Extent.StartLineNumber, $txt))
            }
        }
        $hits -join [Environment]::NewLine | Should -BeNullOrEmpty
    }

    It 'veri ve belgeler (JSON, README, TWEAKS.md, APPS.md): Türkçe harf yok' {
        $files = @(
            @(Get-ChildItem -Path (Join-Path $RepoRoot 'apps') -File -Filter '*.json')
            @(Get-ChildItem -Path (Join-Path $RepoRoot 'profiles') -File -Filter '*.json')
            @(Get-Item (Join-Path $RepoRoot 'README.md'), (Join-Path $RepoRoot 'docs/TWEAKS.md'), (Join-Path $RepoRoot 'docs/APPS.md'))
        )
        $hits = New-Object 'System.Collections.Generic.List[string]'
        foreach ($f in $files) {
            $rel = Get-RelPath $f.FullName
            $n = 0
            foreach ($line in [System.IO.File]::ReadAllLines($f.FullName)) {
                $n++
                if ($line -cnotmatch $script:TurkishChars) { continue }
                if (Test-Allowed $rel $line) { continue }
                $hits.Add(('{0}:{1}: {2}' -f $rel, $n, $line.Trim()))
            }
        }
        $hits -join [Environment]::NewLine | Should -BeNullOrEmpty
    }

    It 'bekçi Türkçe dizeyi yakalar, yorumu yakalamaz' {
        $tmp = Join-Path $TestDrive 'Sample.ps1'
        $body = "# yorum: " + [char]0x00e7 + "ok`nWrite-Host 'Merhaba d" + [char]0x00fc + "nya'`n"
        [System.IO.File]::WriteAllText($tmp, $body, (New-Object System.Text.UTF8Encoding $true))
        $tokens = $null; $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($tmp, [ref] $tokens, [ref] $errors)
        $found = @($tokens | Where-Object { $script:StringKinds -contains [string]$_.Kind -and $_.Text -cmatch $script:TurkishChars })
        $found.Count | Should -Be 1
        $found[0].Extent.StartLineNumber | Should -Be 2
    }
}
