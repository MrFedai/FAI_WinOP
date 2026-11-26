#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }
# 1.4: önyükleyici (src/Bootstrap/get.ps1). Dosya çalıştırılmaz (indirir, yükseltir); yalnız fonksiyonları AST ile alınır.

BeforeAll {
    $script:GetPs1 = (Resolve-Path (Join-Path $PSScriptRoot '../../src/Bootstrap/get.ps1')).Path
    $script:GetText = [System.IO.File]::ReadAllText($GetPs1)
    $tokens = $null; $errors = $null
    $script:GetAst = [System.Management.Automation.Language.Parser]::ParseInput($GetText, [ref] $tokens, [ref] $errors)
    $errors | Should -BeNullOrEmpty
    $script:GetFunctions = @($GetAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false))
    foreach ($f in $GetFunctions) { . ([scriptblock]::Create($f.Extent.Text)) }
}

Describe 'get.ps1: FAI_WINOP_BASEURL denetimi (Test-FaiBaseUrl)' {
    It 'kabul eder: <Url>' -ForEach @(
        @{ Url = 'https://github.com/MrFedai/FAI_WinOP/releases/latest/download' }
        @{ Url = 'https://github.com/MrFedai/FAI_WinOP/releases/download/v0.1.0/' }
        @{ Url = 'http://127.0.0.1:8765/good' }
        @{ Url = 'http://localhost:8765/bad' }
        @{ Url = 'http://LOCALHOST/x' }
    ) {
        Test-FaiBaseUrl $Url | Should -BeTrue
    }

    It 'reddeder: <Url>' -ForEach @(
        @{ Url = 'http://example.com/download' }
        @{ Url = 'http://localhost.example.com/x' }
        @{ Url = 'http://127.0.0.1.example.com/x' }
        @{ Url = 'http://127.0.0.1@example.com/x' }
        @{ Url = 'https://user:pass@example.com/x' }
        @{ Url = 'http://10.0.0.5:8765/good' }
        @{ Url = 'ftp://example.com/x' }
        @{ Url = 'file:///C:/temp' }
        @{ Url = '\\server\share' }
        @{ Url = 'github.com/MrFedai' }
        @{ Url = '' }
    ) {
        Test-FaiBaseUrl $Url | Should -BeFalse
    }
}

Describe 'get.ps1: özet (Get-FaiExpectedHash / Test-FaiFileHash)' {
    It 'sha256sum biçiminin ilk sözcüğünü küçük harfle verir' {
        $h = 'AB' * 32
        Get-FaiExpectedHash ("{0}  install.ps1`n" -f $h) | Should -Be $h.ToLowerInvariant()
    }

    It 'geçersiz özet metninde $null: <Text>' -ForEach @(
        @{ Text = '' }
        @{ Text = 'zz' }
        @{ Text = ('a' * 63) }
        @{ Text = ('g' * 64) }
        @{ Text = '<html>404</html>' }
    ) {
        Get-FaiExpectedHash $Text | Should -BeNullOrEmpty
    }

    It 'dosya özetini karşılaştırır; biçimsiz beklenen değerde $false' {
        $f = Join-Path $TestDrive 'h.txt'
        [System.IO.File]::WriteAllText($f, 'merhaba')
        $real = (Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash.ToLowerInvariant()
        Test-FaiFileHash -Path $f -Expected $real | Should -BeTrue
        Test-FaiFileHash -Path $f -Expected ('0' * 64) | Should -BeFalse
        Test-FaiFileHash -Path $f -Expected '' | Should -BeFalse
    }
}

Describe 'get.ps1: yükseltilmiş komut (ConvertTo-FaiLiteral / New-FaiElevatedScript)' {
    It 'tek tırnaklı metin geri aynı değeri verir: <Value>' -ForEach @(
        @{ Value = 'düz' }
        @{ Value = "a'b" }
        @{ Value = ('x' + [char]0x2019 + '; Set-Content kurcalandi.txt x; ' + [char]0x2018) }
        @{ Value = '$(Get-Date) `n "çift"' }
        @{ Value = '' }
    ) {
        $lit = ConvertTo-FaiLiteral $Value
        $tokens = $null; $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($lit, [ref] $tokens, [ref] $errors)
        $errors | Should -BeNullOrEmpty
        $ast.EndBlock.Statements.Count | Should -Be 1
        (& ([scriptblock]::Create($lit))) | Should -BeExactly $Value
    }

    It 'betik ayrıştırılır, özeti ve argümanları taşır, Invoke-FaiSecureRun''ı çağırır' {
        $h = 'c' * 64
        $s = New-FaiElevatedScript -Source 'C:\Users\x\AppData\Local\Temp\FAI_WinOP\install.ps1' -Expected $h -Arguments @('-Profile', "o'ad", '-DryRun')
        $tokens = $null; $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($s, [ref] $tokens, [ref] $errors)
        $errors | Should -BeNullOrEmpty
        $names = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false) | ForEach-Object { $_.Name })
        $names | Should -Contain 'Invoke-FaiSecureRun'
        $names | Should -Contain 'New-FaiAdminDir'
        $names | Should -Contain 'Test-FaiFileHash'
        $last = $ast.EndBlock.Statements[-1].Extent.Text
        $last | Should -Match '^Invoke-FaiSecureRun '
        $last | Should -Match ([regex]::Escape("'$h'"))
        $last | Should -Match ([regex]::Escape("'o''ad'"))
        # UTF-16 base64 (-EncodedCommand) geri çözülür.
        $enc = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($s))
        [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($enc)) | Should -BeExactly $s
    }

    It 'biçimsiz özetle betik üretmez' {
        { New-FaiElevatedScript -Source 'C:\x' -Expected 'abc' -Arguments @() } | Should -Throw
    }
}

Describe 'get.ps1: Invoke-FaiSecureRun (yönetici-yalnız kopya yeniden doğrulanır, yalnız o çalışır)' {
    BeforeEach {
        $script:AdminDir = Join-Path $TestDrive ('admin-' + [guid]::NewGuid().ToString('N'))
        [void](New-Item -ItemType Directory -Path $AdminDir)
        $script:Source = Join-Path $TestDrive 'install.ps1'
        [System.IO.File]::WriteAllText($Source, "Write-Output 'kurulum'")
        $script:Hash = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash.ToLowerInvariant()
        Mock New-FaiAdminDir { $script:AdminDir }
        Mock Start-FaiInstaller { }
        Mock Write-Host { }
    }

    It 'özet tutarsa kopyayı (kaynağı değil) argümanlarla çalıştırır, sonra klasörü siler' {
        Invoke-FaiSecureRun -Source $Source -Expected $Hash -Arguments @('-Profile', 'fedai', '-DryRun')
        Should -Invoke Start-FaiInstaller -Times 1 -Exactly -ParameterFilter {
            $Path -eq (Join-Path $script:AdminDir 'install.ps1') -and ($Arguments -join ' ') -eq '-Profile fedai -DryRun'
        }
        Test-Path -LiteralPath $AdminDir | Should -BeFalse
    }

    It 'dosya ilk doğrulamadan sonra değiştiyse çalıştırmaz, hata verir, klasörü siler' {
        [System.IO.File]::AppendAllText($Source, "`r`nSet-Content kurcalandi.txt x")
        { Invoke-FaiSecureRun -Source $Source -Expected $Hash -Arguments @() } | Should -Throw '*SHA-256*'
        Should -Invoke Start-FaiInstaller -Times 0 -Exactly
        Test-Path -LiteralPath $AdminDir | Should -BeFalse
    }
}

Describe 'get.ps1: yapı' {
    It 'powershell.exe -File yalnız Start-FaiInstaller içinde (%TEMP% dosyası doğrudan çalıştırılmaz)' {
        $cmds = $GetAst.FindAll({
                param($n)
                $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -match '^powershell(\.exe)?$'
            }, $true)
        foreach ($c in $cmds) {
            if ($c.Extent.Text -notmatch '-File') { continue }
            $p = $c.Parent
            while ($p -and -not ($p -is [System.Management.Automation.Language.FunctionDefinitionAst])) { $p = $p.Parent }
            $p.Name | Should -Be 'Start-FaiInstaller'
        }
        $GetText | Should -Not -Match '-File\s+"?\$faiFile'
        $GetText | Should -Match '-EncodedCommand'
    }

    It 'yükseltilmiş betiğe aktarılan fonksiyonlar dosyada tanımlı' {
        $defined = @($GetFunctions | ForEach-Object { $_.Name })
        foreach ($n in @('Test-FaiFileHash', 'New-FaiAdminDir', 'Start-FaiInstaller', 'Invoke-FaiSecureRun')) { $defined | Should -Contain $n }
    }

    It 'yönetici-yalnız klasör ACL''i oluşturma anında verilir: SYSTEM + Administrators, kalıtım kapalı, sahip Administrators' {
        $body = ($GetFunctions | Where-Object { $_.Name -eq 'New-FaiAdminDir' }).Extent.Text
        $body | Should -Match 'S-1-5-32-544'
        $body | Should -Match 'S-1-5-18'
        $body | Should -Match 'SetAccessRuleProtection\(\$true, \$false\)'
        $body | Should -Match 'SetOwner\(\$admins\)'
        $body | Should -Match 'CreateDirectory\(\$path, \$sec\)'
        $body | Should -Match 'ReparsePoint'
    }

    It 'BASEURL denetimi indirmeden önce' {
        $GetText.IndexOf('Test-FaiBaseUrl $env:FAI_WINOP_BASEURL') | Should -BeGreaterThan 0
        $GetText.IndexOf('Test-FaiBaseUrl $env:FAI_WINOP_BASEURL') | Should -BeLessThan $GetText.IndexOf('DownloadFile(')
    }
}
