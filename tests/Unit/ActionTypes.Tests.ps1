#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }
# Faz 2 eylem türleri (ScheduledTask, Appx, Winget, Power, File, Shortcut, Script, Volume, TimerResolution):
# şema · Test · Snapshot · Apply · Revert, yalnız Fake sağlayıcılar üzerinden. Ayrıca bütün türler bir arada motor
# döngüsü (dry-run sıfır yazma → uygula → undo = başlangıç durumu), Windows sağlayıcılarının yapısı ve gömülü native kaynak.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Load-Fakes.ps1')
    $script:Seq = 0
    function New-Ctx {
        $script:Seq++
        return (New-FakeContext -BackupRoot (Join-Path $TestDrive ('b{0}' -f $script:Seq)))
    }
    function Act([hashtable] $Def) { return (New-FaiAction -Definition $Def) }
    function Errs([hashtable] $Def) { return @(Get-FaiActionError -Definition $Def) }

    # Snapshot JSON'a yazılıp okunur (BackupStore gibi): geri alma diskten gelen veriyle çalışmalı.
    function RoundTrip([hashtable] $Snapshot) { return [hashtable](ConvertFrom-JsonText -Json ($Snapshot | ConvertTo-Json -Depth 10)) }

    # Apply → Test → Revert (JSON'dan) döngüsü; Revert sonrası durum Before ile aynı olmalı.
    function Invoke-Cycle([ExecutionContext] $Ctx, [ActionBase] $Action, [scriptblock] $State) {
        $before = & $State
        $snap = RoundTrip ($Action.Snapshot($Ctx))
        $Action.Apply($Ctx)
        $Action.Test($Ctx) | Should -BeTrue -Because 'Apply sonrası hedef durum sağlanmalı'
        $after = & $State
        $Action.Revert($Ctx, $snap)
        (& $State) | Should -Be $before -Because 'Revert başlangıç durumunu birebir geri getirmeli'
        return $after
    }
}

Describe 'RegistryAction: geri almada oluşturulan anahtarlar' {
    It 'değer için oluşturulan anahtar zinciri geri almada silinir; önceden var olan üst anahtar kalır' {
        $ctx = New-Ctx
        $ctx.Registry.Seed('HKCU:\Software\Var', 'X', 1, 'DWord')
        $a = Act @{ Type = 'Registry'; Path = 'HKCU:\Software\Var\Yeni\Alt'; Name = 'V'; Value = 1; Kind = 'DWord' }
        $snap = RoundTrip ($a.Snapshot($ctx))
        $snap['MissingFrom'] | Should -Be 'HKCU:\Software\Var\Yeni'
        $a.Apply($ctx)
        $ctx.Registry.KeyExists('HKCU:\Software\Var\Yeni\Alt') | Should -BeTrue
        $a.Revert($ctx, $snap)
        $ctx.Registry.KeyExists('HKCU:\Software\Var\Yeni') | Should -BeFalse
        $ctx.Registry.ValueExists('HKCU:\Software\Var', 'X') | Should -BeTrue
    }

    It 'oluşturulan anahtara sonradan başka değer yazıldıysa o anahtar silinmez' {
        $ctx = New-Ctx
        $a = Act @{ Type = 'Registry'; Path = 'HKCU:\Software\Yeni\Alt'; Name = 'V'; Value = 1; Kind = 'DWord' }
        $snap = RoundTrip ($a.Snapshot($ctx))
        $a.Apply($ctx)
        $ctx.Registry.Seed('HKCU:\Software\Yeni', 'Baska', 1, 'DWord')
        $a.Revert($ctx, $snap)
        $ctx.Registry.KeyExists('HKCU:\Software\Yeni\Alt') | Should -BeFalse
        $ctx.Registry.ValueExists('HKCU:\Software\Yeni', 'Baska') | Should -BeTrue
    }

    It 'Ensure=Absent ve var olan anahtar için MissingFrom tutulmaz' {
        $ctx = New-Ctx
        $ctx.Registry.Seed('HKCU:\Software\Var', 'X', 1, 'DWord')
        (Act @{ Type = 'Registry'; Path = 'HKCU:\Software\Yok'; Name = 'V'; Ensure = 'Absent' }).Snapshot($ctx).ContainsKey('MissingFrom') | Should -BeFalse
        (Act @{ Type = 'Registry'; Path = 'HKCU:\Software\Var'; Name = 'V'; Value = 1; Kind = 'DWord' }).Snapshot($ctx).ContainsKey('MissingFrom') | Should -BeFalse
    }
}

Describe 'ScheduledTaskAction' {
    It 'şema: yol \ ile başlamalı, State Enabled / Disabled' {
        Errs @{ Type = 'ScheduledTask'; Path = '\A\B'; State = 'Disabled' } | Should -BeNullOrEmpty
        Errs @{ Type = 'ScheduledTask'; Path = 'A\B'; State = 'Off' } | Should -HaveCount 2
        Errs @{ Type = 'ScheduledTask'; Path = '\A\'; State = 'Enabled'; X = 1 } | Should -HaveCount 2
    }

    It 'devre dışı bırakır, geri alınca etkin olur' {
        $ctx = New-Ctx
        $ctx.Tasks.Seed('\Microsoft\Windows\Test\T1', 'Enabled')
        $a = Act @{ Type = 'ScheduledTask'; Path = '\Microsoft\Windows\Test\T1'; State = 'Disabled' }
        $a.Test($ctx) | Should -BeFalse
        $after = Invoke-Cycle $ctx $a { $ctx.Tasks.GetTaskState('\Microsoft\Windows\Test\T1') }
        $after | Should -Be 'Disabled'
    }

    It 'olmayan görev: Test $true, Apply yazmadan uyarır' {
        $ctx = New-Ctx
        $a = Act @{ Type = 'ScheduledTask'; Path = '\Yok'; State = 'Disabled' }
        $a.Test($ctx) | Should -BeTrue
        $a.Apply($ctx)
        $ctx.Tasks.WriteCount | Should -Be 0
        $ctx.Logger.Count('WARN') | Should -Be 1
        $a.Preview($ctx) | Should -Match 'task not found'
    }
}

Describe 'AppxAction' {
    It 'şema: joker ve bilinmeyen Scope reddedilir' {
        Errs @{ Type = 'Appx'; Name = 'Microsoft.BingNews' } | Should -BeNullOrEmpty
        Errs @{ Type = 'Appx'; Name = 'Microsoft.*' } | Should -HaveCount 1
        Errs @{ Type = 'Appx'; Name = 'A'; Scope = 'Machine' } | Should -HaveCount 1
    }

    It 'Scope=User: kullanıcı paketini kaldırır; provisioned kopyadan geri kaydeder' {
        $ctx = New-Ctx
        $ctx.Appx.Seed(@('X.App', 'Y.App'), @('X.App'))
        $a = Act @{ Type = 'Appx'; Name = 'X.App'; Scope = 'User' }
        Invoke-Cycle $ctx $a { (@($ctx.Appx.GetInstalled() | Sort-Object) -join ',') + '|' + ($ctx.Appx.GetProvisioned() -join ',') } | Should -Be 'Y.App|X.App'
        $ctx.Logger.Count('WARN') | Should -Be 0
    }

    It 'Scope=All: önce kullanıcı sonra provisioned kaldırılır; geri dönüşü olmayan adım uyarı olur, hata değil' {
        $ctx = New-Ctx
        $ctx.Appx.Seed(@('X.App'), @('X.App'))
        $a = Act @{ Type = 'Appx'; Name = 'X.App' }
        $snap = RoundTrip ($a.Snapshot($ctx))
        $a.Apply($ctx)
        $ctx.Appx.WriteLog | Should -Be @('RemoveInstalled X.App', 'RemoveProvisioned X.App')
        $a.Test($ctx) | Should -BeTrue
        { $a.Revert($ctx, $snap) } | Should -Not -Throw
        $ctx.Logger.Count('WARN') | Should -Be 2
        $a.Describe() | Should -Match 'user \+ provisioned'
    }

    It 'kurulu değilse Test $true, Apply yazmaz' {
        $ctx = New-Ctx
        $a = Act @{ Type = 'Appx'; Name = 'X.App' }
        $a.Test($ctx) | Should -BeTrue
        $a.Apply($ctx)
        $ctx.Appx.WriteCount | Should -Be 0
    }
}

Describe 'WingetAction' {
    It 'şema: Source winget / msstore, Ensure Present / Absent, kimlikte boşluk yok' {
        Errs @{ Type = 'Winget'; Id = 'Google.Chrome' } | Should -BeNullOrEmpty
        Errs @{ Type = 'Winget'; Id = '9NKSQGP7F2NH'; Source = 'msstore'; Ensure = 'Absent' } | Should -BeNullOrEmpty
        Errs @{ Type = 'Winget'; Id = 'Google Chrome'; Source = 'choco'; Ensure = 'Yes' } | Should -HaveCount 3
    }

    It 'kurar; geri alınca kaldırır' {
        $ctx = New-Ctx
        $a = Act @{ Type = 'Winget'; Id = 'Google.Chrome' }
        Invoke-Cycle $ctx $a { $ctx.Packages.IsInstalled('Google.Chrome', 'winget') } | Should -BeTrue
        $ctx.Packages.WriteLog | Should -Be @('Install winget Google.Chrome', 'Uninstall winget Google.Chrome')
    }

    It 'Ensure=Absent kaldırır; geri alınca aynı kaynaktan yeniden kurar' {
        $ctx = New-Ctx
        $ctx.Packages.Seed('9NKSQGP7F2NH', 'msstore')
        $a = Act @{ Type = 'Winget'; Id = '9NKSQGP7F2NH'; Source = 'msstore'; Ensure = 'Absent' }
        Invoke-Cycle $ctx $a { $ctx.Packages.IsInstalled('9NKSQGP7F2NH', 'msstore') } | Should -BeFalse
        $a.Describe() | Should -Be 'Package (msstore): 9NKSQGP7F2NH is removed'
    }
}

Describe 'PowerAction' {
    It 'şema: ActiveScheme kipi tek başına; ayar kipinde Subgroup + Setting + AC/DC' {
        Errs @{ Type = 'Power'; ActiveScheme = 'SCHEME_MIN' } | Should -BeNullOrEmpty
        Errs @{ Type = 'Power'; ActiveScheme = 'SCHEME_MIN'; AC = 1 } | Should -HaveCount 1
        Errs @{ Type = 'Power'; Subgroup = 'SUB_SLEEP'; Setting = 'STANDBYIDLE'; DC = 900 } | Should -BeNullOrEmpty
        Errs @{ Type = 'Power'; Subgroup = 'SUB_SLEEP'; Setting = 'STANDBYIDLE' } | Should -HaveCount 1
        Errs @{ Type = 'Power'; Subgroup = 'SUB SLEEP'; Setting = 'X'; AC = -1; DC = 'çok' } | Should -HaveCount 3
    }

    It 'AC ve DC ayrı yazılır; geri alma ikisini de döndürür' {
        $ctx = New-Ctx
        $ctx.Power.Seed('SCHEME_CURRENT', 'SUB_SLEEP', 'STANDBYIDLE', 1800, 600)
        $a = Act @{ Type = 'Power'; Subgroup = 'SUB_SLEEP'; Setting = 'STANDBYIDLE'; AC = 0; DC = 900 }
        $a.Test($ctx) | Should -BeFalse
        $a.Preview($ctx) | Should -Match 'current: on AC = 1800, on battery = 600'
        $after = Invoke-Cycle $ctx $a { $ctx.Power.Dump() -join ';' }
        $after | Should -Match 'sub_sleep\|standbyidle\|0\|900'
    }

    It 'yalnız verilen taraf yazılır' {
        $ctx = New-Ctx
        $ctx.Power.Seed('SCHEME_CURRENT', 'SUB_SLEEP', 'HIBERNATEIDLE', 0, 3600)
        $a = Act @{ Type = 'Power'; Subgroup = 'SUB_SLEEP'; Setting = 'HIBERNATEIDLE'; AC = 7200 }
        $a.Apply($ctx)
        $ctx.Power.GetValue('SCHEME_CURRENT', 'SUB_SLEEP', 'HIBERNATEIDLE', $false) | Should -Be 3600
        $ctx.Power.WriteCount | Should -Be 1
    }

    It 'snapshot planın GUID''ini tutar: etkin plan sonradan değişse de doğru plana döner' {
        $ctx = New-Ctx
        $ctx.Power.Seed('SCHEME_BALANCED', 'SUB_DISK', 'DISKIDLE', 600, 300)
        $ctx.Power.Seed('SCHEME_MIN', 'SUB_DISK', 'DISKIDLE', 1200, 1200)
        $a = Act @{ Type = 'Power'; Subgroup = 'SUB_DISK'; Setting = 'DISKIDLE'; AC = 0; DC = 0 }
        $snap = RoundTrip ($a.Snapshot($ctx))
        $a.Apply($ctx)
        $ctx.Power.SetActiveScheme('SCHEME_MIN')
        $a.Revert($ctx, $snap)
        $ctx.Power.GetValue('SCHEME_BALANCED', 'SUB_DISK', 'DISKIDLE', $true) | Should -Be 600
        $ctx.Power.GetValue('SCHEME_MIN', 'SUB_DISK', 'DISKIDLE', $true) | Should -Be 1200
    }

    It 'etkin planı değiştirir; geri alınca önceki plan etkin olur; olmayan plan hata verir' {
        $ctx = New-Ctx
        $a = Act @{ Type = 'Power'; ActiveScheme = 'SCHEME_MIN' }
        Invoke-Cycle $ctx $a { $ctx.Power.GetActiveScheme() } | Should -Be '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
        $missing = Act @{ Type = 'Power'; ActiveScheme = 'e9a42b02-d5df-448d-aa00-03f14749eb61' }
        $missing.Test($ctx) | Should -BeFalse
        { $missing.Apply($ctx) } | Should -Throw '*Power plan not found*'
    }
}

Describe 'FileAction' {
    It 'şema: mutlak / %DEĞİŞKEN% yolu; Absent iken Content verilmez' {
        Errs @{ Type = 'File'; Path = '%LOCALAPPDATA%\X\a.json'; Content = '{}' } | Should -BeNullOrEmpty
        Errs @{ Type = 'File'; Path = 'C:\x.txt'; Content = 'a'; Encoding = 'UTF8BOM' } | Should -BeNullOrEmpty
        Errs @{ Type = 'File'; Path = 'goreli\x.txt'; Content = 1; Encoding = 'Latin1' } | Should -HaveCount 3
        Errs @{ Type = 'File'; Path = 'C:\x.txt'; Ensure = 'Absent'; Content = 'a' } | Should -HaveCount 1
    }

    It 'yeni dosya yazar; geri alınca siler' {
        $ctx = New-Ctx
        $a = Act @{ Type = 'File'; Path = 'C:\FAI_WinOP_Test\yeni.txt'; Content = 'Merhaba ğüşİ' }
        $a.Test($ctx) | Should -BeFalse
        Invoke-Cycle $ctx $a { $ctx.Files.Dump() -join ';' } | Should -Not -BeNullOrEmpty
        $ctx.Files.FileExists('C:\FAI_WinOP_Test\yeni.txt') | Should -BeFalse
    }

    It 'var olan dosyanın üzerine yazar; geri alınca baytlar birebir döner' {
        $ctx = New-Ctx
        $orig = [byte[]](0xFF, 0xFE, 0x41, 0x00, 0x00, 0x01)
        $ctx.Files.Seed('C:\FAI_WinOP_Test\ayar.ini', $orig)
        $a = Act @{ Type = 'File'; Path = 'C:\FAI_WinOP_Test\ayar.ini'; Content = "a=1`r`n"; Encoding = 'Unicode' }
        Invoke-Cycle $ctx $a { $ctx.Files.Dump() -join ';' } | Out-Null
        ([byte[]]$ctx.Files.ReadBytes('C:\FAI_WinOP_Test\ayar.ini')) -join ',' | Should -Be ($orig -join ',')
    }

    It 'kodlama: UTF8BOM ön eki yazılır, UTF8 (varsayılan) BOM''suz' {
        ([FileAction]::Encode('a', 'UTF8BOM')) -join ',' | Should -Be '239,187,191,97'
        ([FileAction]::Encode('a', '')) -join ',' | Should -Be '97'
        ([FileAction]::Encode('a', 'Unicode')) -join ',' | Should -Be '255,254,97,0'
    }

    It 'Ensure=Absent siler; geri alınca geri yazar' {
        $ctx = New-Ctx
        $ctx.Files.SeedText('C:\Users\Public\Desktop\Edge.lnk', 'lnk')
        $a = Act @{ Type = 'File'; Path = 'C:\Users\Public\Desktop\Edge.lnk'; Ensure = 'Absent' }
        Invoke-Cycle $ctx $a { $ctx.Files.Dump() -join ';' } | Should -BeNullOrEmpty
    }

    It 'yedek sınırından büyük dosyada Snapshot hata verir (dokunulmaz)' {
        $ctx = New-Ctx
        $ctx.Files.Seed('C:\buyuk.bin', (New-Object byte[] ([FileAction]::MaxBackupBytes + 1)))
        $a = Act @{ Type = 'File'; Path = 'C:\buyuk.bin'; Ensure = 'Absent' }
        { $a.Snapshot($ctx) } | Should -Throw '*exceeds the backup limit*'
    }

    It '%DEĞİŞKEN% yolu çalışma anında açılır' {
        $ctx = New-Ctx
        $env:FAI_TEST_DIR = 'C:\Acilmis'
        try {
            $a = Act @{ Type = 'File'; Path = '%FAI_TEST_DIR%\x.txt'; Content = 'x' }
            $a.Apply($ctx)
            $ctx.Files.FileExists('C:\Acilmis\x.txt') | Should -BeTrue
            $a.Describe() | Should -Match '%FAI_TEST_DIR%'
        }
        finally { Remove-Item Env:\FAI_TEST_DIR }
    }
}

Describe 'ShortcutAction' {
    It 'şema: .lnk yolu, TargetPath zorunlu, Absent iken özellik verilmez' {
        Errs @{ Type = 'Shortcut'; Path = '%APPDATA%\x.lnk'; TargetPath = 'C:\a.exe' } | Should -BeNullOrEmpty
        Errs @{ Type = 'Shortcut'; Path = '%APPDATA%\x.url' } | Should -HaveCount 2
        Errs @{ Type = 'Shortcut'; Path = 'C:\x.lnk'; Ensure = 'Absent'; Arguments = '-a' } | Should -HaveCount 1
    }

    It 'oluşturur; Test yol harfini ve %DEĞİŞKEN%''i yok sayar; geri alınca siler' {
        $ctx = New-Ctx
        $a = Act @{ Type = 'Shortcut'; Path = 'C:\Start\Not.lnk'; TargetPath = 'C:\Windows\notepad.exe'; Arguments = '/a' }
        Invoke-Cycle $ctx $a { $ctx.Files.Dump() -join ';' } | Should -Not -BeNullOrEmpty
        $ctx.Shortcuts.Seed('C:\Start\Not.lnk', @{ TargetPath = 'c:\windows\NOTEPAD.EXE'; Arguments = '/a' })
        $a.Test($ctx) | Should -BeTrue
    }

    It 'var olan kısayolu değiştirir; geri alınca aynı .lnk baytları döner' {
        $ctx = New-Ctx
        $ctx.Shortcuts.Seed('C:\Start\Chrome.lnk', @{ TargetPath = 'C:\eski\chrome.exe'; Description = 'eski' })
        $a = Act @{ Type = 'Shortcut'; Path = 'C:\Start\Chrome.lnk'; TargetPath = 'C:\yeni\chrome.exe' }
        Invoke-Cycle $ctx $a { $ctx.Files.Dump() -join ';' } | Out-Null
        $ctx.Shortcuts.ReadShortcut('C:\Start\Chrome.lnk')['Description'] | Should -Be 'eski'
    }

    It 'Ensure=Absent siler; geri alınca geri gelir' {
        $ctx = New-Ctx
        $ctx.Shortcuts.Seed('C:\Users\Public\Desktop\Edge.lnk', @{ TargetPath = 'C:\edge.exe' })
        $a = Act @{ Type = 'Shortcut'; Path = 'C:\Users\Public\Desktop\Edge.lnk'; Ensure = 'Absent' }
        Invoke-Cycle $ctx $a { $ctx.Files.Dump() -join ';' } | Should -BeNullOrEmpty
    }
}

Describe 'Fake = gerçek sağlayıcı davranışı (4.1)' {
    It 'DeleteEmptyKey: kovanın hemen altındaki anahtarı silmez, derindekini siler' {
        $ctx = New-Ctx
        $ctx.Registry.SetValue('HKCU:\FakeTop', 'V', 1, 'DWord')
        $ctx.Registry.DeleteValue('HKCU:\FakeTop', 'V')
        $ctx.Registry.DeleteEmptyKey('HKCU:\FakeTop')
        $ctx.Registry.KeyExists('HKCU:\FakeTop') | Should -BeTrue
        $ctx.Registry.SetValue('HKCU:\Soft\Deep', 'V', 1, 'DWord')
        $ctx.Registry.DeleteValue('HKCU:\Soft\Deep', 'V')
        $ctx.Registry.DeleteEmptyKey('HKCU:\Soft\Deep')
        $ctx.Registry.KeyExists('HKCU:\Soft\Deep') | Should -BeFalse
    }

    It 'DeleteEmptyKey: değeri ya da alt anahtarı olan anahtarı silmez' {
        $ctx = New-Ctx
        $ctx.Registry.SetValue('HKCU:\Soft\A', 'V', 1, 'DWord')
        $ctx.Registry.SetValue('HKCU:\Soft\A\B', 'V', 1, 'DWord')
        $ctx.Registry.DeleteEmptyKey('HKCU:\Soft\A')
        $ctx.Registry.KeyExists('HKCU:\Soft\A') | Should -BeTrue
        $ctx.Registry.DeleteEmptyKey('HKCU:\Soft\A\B')
        $ctx.Registry.ValueExists('HKCU:\Soft\A\B', 'V') | Should -BeTrue
    }

    It 'winget paket kimliği harfe duyarsız eşlenir' {
        $p = [FakePackageProvider]::new()
        $p.Seed('Google.Chrome', 'winget')
        $p.IsInstalled('google.CHROME', 'winget') | Should -BeTrue
        $p.Uninstall('GOOGLE.chrome', 'winget')
        $p.IsInstalled('Google.Chrome', 'winget') | Should -BeFalse
    }

    It 'kısayol IconLocation "yol,indeks" döner; Test "x.ico" ile "x.ico,0"ı eşit sayar' {
        $ctx = New-Ctx
        $ctx.Shortcuts.Seed('C:\S\a.lnk', @{ TargetPath = 'C:\a.exe'; IconLocation = 'C:\x.ico' })
        $ctx.Shortcuts.ReadShortcut('C:\S\a.lnk')['IconLocation'] | Should -Be 'C:\x.ico,0'
        $ctx.Shortcuts.Seed('C:\S\b.lnk', @{ TargetPath = 'C:\a.exe'; IconLocation = 'C:\x.ico,3' })
        $ctx.Shortcuts.ReadShortcut('C:\S\b.lnk')['IconLocation'] | Should -Be 'C:\x.ico,3'
        (Act @{ Type = 'Shortcut'; Path = 'C:\S\a.lnk'; TargetPath = 'C:\a.exe'; IconLocation = 'C:\x.ico' }).Test($ctx) | Should -BeTrue
        (Act @{ Type = 'Shortcut'; Path = 'C:\S\a.lnk'; TargetPath = 'C:\a.exe'; IconLocation = 'C:\x.ico,0' }).Test($ctx) | Should -BeTrue
        (Act @{ Type = 'Shortcut'; Path = 'C:\S\b.lnk'; TargetPath = 'C:\a.exe'; IconLocation = 'C:\x.ico' }).Test($ctx) | Should -BeFalse
    }
}

Describe 'WindowsSystemInfoProvider.DecideLaptop' {
    It 'dizüstü kasa → $true (pil olsun olmasın)' {
        [WindowsSystemInfoProvider]::DecideLaptop([int[]]@(10), $false) | Should -BeTrue
        [WindowsSystemInfoProvider]::DecideLaptop([int[]]@(3, 9), $true) | Should -BeTrue
    }
    It 'masaüstü kasa + pil (UPS) → $false' {
        foreach ($c in 3, 4, 5, 6, 7, 13, 15, 16, 35, 36) {
            [WindowsSystemInfoProvider]::DecideLaptop([int[]]@($c), $true) | Should -BeFalse -Because "kasa $c"
        }
    }
    It 'kasa bilinmiyor / yok → pil karar verir' {
        [WindowsSystemInfoProvider]::DecideLaptop([int[]]@(), $true) | Should -BeTrue
        [WindowsSystemInfoProvider]::DecideLaptop([int[]]@(2), $true) | Should -BeTrue
        [WindowsSystemInfoProvider]::DecideLaptop([int[]]@(), $false) | Should -BeFalse
    }
}

Describe 'ScriptAction' {
    BeforeEach { [FakeScriptHost]::State.Clear() }

    It 'şema: Apply + Revert zorunlu, kod ayrıştırılabilir olmalı' {
        Errs @{ Type = 'Script'; Apply = '1'; Revert = '2' } | Should -BeNullOrEmpty
        Errs @{ Type = 'Script'; Apply = 'if ('; Test = ' ' } | Should -HaveCount 3
    }

    It 'Test → Snapshot → Apply → Revert(snapshot değeri) zinciri' {
        $ctx = New-Ctx
        [FakeScriptHost]::State['v'] = 'eski'
        $a = Act @{
            Type        = 'Script'; Description = 'deneme'
            Test        = "[FakeScriptHost]::State['v'] -eq 'yeni'"
            Snapshot    = "[FakeScriptHost]::State['v']"
            Apply       = "[FakeScriptHost]::State['v'] = 'yeni'"
            Revert      = "param(`$Snapshot) [FakeScriptHost]::State['v'] = `$Snapshot"
        }
        $a.Test($ctx) | Should -BeFalse
        Invoke-Cycle $ctx $a { [FakeScriptHost]::State['v'] } | Should -Be 'yeni'
        $ctx.Scripts.WriteCount | Should -Be 2
        $a.Describe() | Should -Be 'Script: deneme'
    }

    It 'çıktı vermeyen betik hata vermez (5.1: sınıf yönteminde boş dönüş tuzağı)' {
        $ctx = New-Ctx
        $a = Act @{ Type = 'Script'; Apply = '$x = 1'; Revert = '$y = 2'; Snapshot = '$z = 3' }
        { $a.Apply($ctx) } | Should -Not -Throw
        $a.Snapshot($ctx)['Value'] | Should -BeNullOrEmpty
        [WindowsScriptHost]::Invoke('1; 2', $null) | Should -Be @(1, 2)
        [WindowsScriptHost]::Invoke('param($s) $s', 'a') | Should -Be 'a'
    }

    It 'IsTruthy: False / 0 metni ve sayısı yanlış; True / 1 / sıfırdan farklı doğru' {
        foreach ($v in @($false, 0, 0.0, '0', 'False', 'false', ' FALSE ', ' 0 ', '', '  ', $null, '0.0')) {
            [ScriptAction]::IsTruthy($v) | Should -BeFalse -Because ("[{0}]" -f $v)
        }
        foreach ($v in @($true, 1, -1, 2.5, '1', 'True', ' true ', 'evet', '5')) {
            [ScriptAction]::IsTruthy($v) | Should -BeTrue -Because ("[{0}]" -f $v)
        }
    }

    It 'Test: betik "False" / "0" döndürürse uygulanmamış sayılır' {
        $ctx = New-Ctx
        foreach ($code in @("'False'", "'0'", '0', '$false', '$null', "''")) {
            (Act @{ Type = 'Script'; Apply = '1'; Revert = '2'; Test = $code }).Test($ctx) | Should -BeFalse -Because $code
        }
        foreach ($code in @("'True'", '1', '$true', "'1'")) {
            (Act @{ Type = 'Script'; Apply = '1'; Revert = '2'; Test = $code }).Test($ctx) | Should -BeTrue -Because $code
        }
    }

    It 'Test yoksa her zaman uygulanacak sayılır; Test yazma sayılmaz' {
        $ctx = New-Ctx
        (Act @{ Type = 'Script'; Apply = '1'; Revert = '2' }).Test($ctx) | Should -BeFalse
        (Act @{ Type = 'Script'; Apply = '1'; Revert = '2'; Test = '$true' }).Test($ctx) | Should -BeTrue
        $ctx.Scripts.WriteCount | Should -Be 0
    }
}

Describe 'VolumeAction' {
    It 'şema: Level 0-100, Mute bool, en az biri' {
        Errs @{ Type = 'Volume'; Level = 15 } | Should -BeNullOrEmpty
        Errs @{ Type = 'Volume'; Level = '{{level}}' } | Should -BeNullOrEmpty
        Errs @{ Type = 'Volume' } | Should -HaveCount 1
        Errs @{ Type = 'Volume'; Level = 101; Mute = 'evet' } | Should -HaveCount 2
    }

    It 'seviye ve sessizi ayarlar; geri alır' {
        $ctx = New-Ctx
        $ctx.Audio.Volume = 64
        $ctx.Audio.Muted = $true
        $a = Act @{ Type = 'Volume'; Level = 15; Mute = $false }
        Invoke-Cycle $ctx $a { '{0}|{1}' -f $ctx.Audio.Volume, $ctx.Audio.Muted } | Should -Be '15|False'
    }

    It 'çıkış aygıtı yoksa atlanır (yazma yok, uyarı)' {
        $ctx = New-Ctx
        $ctx.Audio.Device = $false
        $a = Act @{ Type = 'Volume'; Level = 15 }
        $a.Test($ctx) | Should -BeTrue
        $a.Apply($ctx)
        $ctx.Audio.WriteCount | Should -Be 0
        $ctx.Logger.Count('WARN') | Should -Be 1
    }
}

Describe 'TimerResolutionAction' {
    It 'şema: 5000-156250 arası; Absent iken Resolution verilmez' {
        Errs @{ Type = 'TimerResolution'; Resolution = 5000 } | Should -BeNullOrEmpty
        Errs @{ Type = 'TimerResolution'; Resolution = 100 } | Should -HaveCount 1
        Errs @{ Type = 'TimerResolution'; Ensure = 'Absent'; Resolution = 5000 } | Should -HaveCount 1
    }

    It 'kurar; geri alınca kaldırır' {
        $ctx = New-Ctx
        $a = Act @{ Type = 'TimerResolution'; Resolution = 5000 }
        Invoke-Cycle $ctx $a { '{0}|{1}' -f $ctx.TimerResolution.IsInstalled(), $ctx.TimerResolution.GetResolution() } | Should -Be 'True|5000'
    }

    It 'farklı çözünürlükle kuruluysa yeniden kurar; geri alınca eski çözünürlük döner' {
        $ctx = New-Ctx
        $ctx.TimerResolution.Install(10000)
        $ctx.TimerResolution.WriteCount = 0
        $a = Act @{ Type = 'TimerResolution'; Resolution = 5000 }
        Invoke-Cycle $ctx $a { '{0}|{1}' -f $ctx.TimerResolution.IsInstalled(), $ctx.TimerResolution.GetResolution() } | Should -Be 'True|5000'
        $a.Describe() | Should -Be 'Timer resolution service: 0.5 ms'
    }

    It 'Ensure=Absent kaldırır; geri alınca yeniden kurar' {
        $ctx = New-Ctx
        $ctx.TimerResolution.Install(5000)
        $a = Act @{ Type = 'TimerResolution'; Ensure = 'Absent' }
        Invoke-Cycle $ctx $a { $ctx.TimerResolution.IsInstalled() } | Should -BeFalse
    }
}

Describe 'Bütün eylem türleri motorda' {
    BeforeAll {
        function Get-AllState([ExecutionContext] $Ctx) {
            $lines = New-Object 'System.Collections.Generic.List[string]'
            foreach ($l in @($Ctx.Registry.Dump()) + @($Ctx.Services.Dump()) + @($Ctx.Files.Dump()) + @($Ctx.Power.Dump())) { $lines.Add([string]$l) }
            $lines.Add('task=' + $Ctx.Tasks.GetTaskState('\FAI\T'))
            $lines.Add('appx=' + (@($Ctx.Appx.GetInstalled() | Sort-Object) -join ',') + '|' + (@($Ctx.Appx.GetProvisioned() | Sort-Object) -join ','))
            $lines.Add('pkg=' + (@($Ctx.Packages.Packages.Keys | Sort-Object) -join ','))
            $lines.Add(('audio={0}|{1}' -f $Ctx.Audio.Volume, $Ctx.Audio.Muted))
            $lines.Add(('timer={0}|{1}' -f $Ctx.TimerResolution.Installed, $Ctx.TimerResolution.Resolution))
            $lines.Add('script=' + [FakeScriptHost]::State['m'])
            return ($lines -join "`n")
        }
    }

    It 'dry-run sıfır yazma; uygula hepsini değiştirir; undo (diskten) başlangıç durumunu birebir getirir' {
        [FakeScriptHost]::State.Clear()
        [FakeScriptHost]::State['m'] = 0
        $ctx = New-Ctx
        $ctx.Tasks.Seed('\FAI\T', 'Enabled')
        $ctx.Appx.Seed(@('X.App'), @('X.App'))
        $ctx.Power.Seed('SCHEME_BALANCED', 'SUB_SLEEP', 'STANDBYIDLE', 1800, 600)
        $ctx.Files.SeedText('C:\FAI\eski.txt', 'eski')
        $ctx.Shortcuts.Seed('C:\FAI\Edge.lnk', @{ TargetPath = 'C:\edge.exe' })

        $tweak = [Tweak]::FromHashtable(@{
                Id = 'test.all-types'; Title = 'Bütün türler'; Description = 'test'; Category = 'test'; Risk = 'Safe'
                Params = @{ level = 15 }
                Actions = @(
                    @{ Type = 'ScheduledTask'; Path = '\FAI\T'; State = 'Disabled' }
                    @{ Type = 'Appx'; Name = 'X.App'; Scope = 'User' }
                    @{ Type = 'Winget'; Id = 'Google.Chrome' }
                    # Plan açıkça verilir: aynı tweak etkin planı değiştirdiği için SCHEME_CURRENT sonradan başka planı gösterir.
                    @{ Type = 'Power'; Scheme = 'SCHEME_BALANCED'; Subgroup = 'SUB_SLEEP'; Setting = 'STANDBYIDLE'; AC = 0; DC = 900 }
                    @{ Type = 'Power'; ActiveScheme = 'SCHEME_MIN' }
                    @{ Type = 'File'; Path = 'C:\FAI\eski.txt'; Content = 'yeni' }
                    @{ Type = 'File'; Path = 'C:\FAI\yeni.txt'; Content = 'yeni' }
                    @{ Type = 'Shortcut'; Path = 'C:\FAI\Edge.lnk'; Ensure = 'Absent' }
                    @{ Type = 'Shortcut'; Path = 'C:\FAI\Chrome.lnk'; TargetPath = 'C:\chrome.exe' }
                    @{ Type = 'Script'; Test = "[FakeScriptHost]::State['m'] -eq 1"; Snapshot = "[FakeScriptHost]::State['m']"
                        Apply = "[FakeScriptHost]::State['m'] = 1"; Revert = "param(`$s) [FakeScriptHost]::State['m'] = `$s" }
                    @{ Type = 'Volume'; Level = '{{level}}' }
                    @{ Type = 'TimerResolution'; Resolution = 5000 }
                )
            }, 'test')
        $catalog = @{ 'test.all-types' = $tweak }
        $faiProfile = [Profile]::FromHashtable(@{ name = 'unit'; tweaks = @('test.all-types') }, 'test')
        $initial = Get-AllState $ctx

        $ctx.DryRun = $true
        $dry = Invoke-FaiEngine -Profile $faiProfile -Context $ctx -Catalog $catalog
        $dry.Find('test.all-types').Status | Should -Be 'Planned'
        $dry.Find('test.all-types').Lines | Should -HaveCount 12
        Get-FakeWriteCount $ctx | Should -Be 0
        Get-AllState $ctx | Should -Be $initial

        $ctx.DryRun = $false
        $run = Invoke-FaiEngine -Profile $faiProfile -Context $ctx -Catalog $catalog
        $run.Find('test.all-types').Status | Should -Be 'Applied' -Because ($run.Find('test.all-types').Reason)
        $applied = Get-AllState $ctx
        $applied | Should -Not -Be $initial
        foreach ($a in $tweak.Actions) { $a.Test($ctx) | Should -BeTrue -Because $a.Describe() }

        # Undo: yeni BackupStore → oturum diskten (JSON) okunur.
        $ctx.Backup = [BackupStore]::new($ctx.Backup.Root)
        $undo = Invoke-FaiEngine -Undo -Context $ctx -Catalog $catalog
        $undo.HasFailures() | Should -BeFalse
        Get-AllState $ctx | Should -Be $initial
    }
}

Describe 'Fabrika, arayüzler ve Windows sağlayıcıları' {
    It 'her eylem türü <Tür>Action sınıfına eşlenir' {
        foreach ($t in Get-FaiActionType) {
            ('{0}Action' -f $t) -as [type] | Should -Not -BeNullOrEmpty -Because "$t için sınıf olmalı"
        }
    }

    It 'yeni arayüzlerin taban yöntemleri NotImplementedException atar' {
        { ([IFileProvider]::new()).FileExists('a') } | Should -Throw -ExceptionType ([System.NotImplementedException])
        { ([IShortcutProvider]::new()).ReadShortcut('a') } | Should -Throw -ExceptionType ([System.NotImplementedException])
        { ([IPowerProvider]::new()).GetActiveScheme() } | Should -Throw -ExceptionType ([System.NotImplementedException])
        { ([IScriptHost]::new()).Query('1', $null) } | Should -Throw -ExceptionType ([System.NotImplementedException])
        { ([IAudioProvider]::new()).HasDevice() } | Should -Throw -ExceptionType ([System.NotImplementedException])
        { ([ITimerResolutionProvider]::new()).IsInstalled() } | Should -Throw -ExceptionType ([System.NotImplementedException])
        { ([IAppxProvider]::new()).RestoreInstalled('a') } | Should -Throw -ExceptionType ([System.NotImplementedException])
        { ([IRegistryProvider]::new()).DeleteEmptyKey('a') } | Should -Throw -ExceptionType ([System.NotImplementedException])
        { ([IEdgeProvider]::new()).UninstallEdge() } | Should -Throw -ExceptionType ([System.NotImplementedException])
        { ([ITaskProvider]::new()).RegisterStartupTask('a', 'b', 'c', 'd') } | Should -Throw -ExceptionType ([System.NotImplementedException])
        { ([ISystemControlProvider]::new()).CreateRestorePoint('a') } | Should -Throw -ExceptionType ([System.NotImplementedException])
        { ([ISystemInfoProvider]::new()).GetCoreCount() } | Should -Throw -ExceptionType ([System.NotImplementedException])
        { ([IMemoryAgentProvider]::new()).GetState() } | Should -Throw -ExceptionType ([System.NotImplementedException])
        { ([IPowerProvider]::new()).CreateScheme('a', 'b', 'c') } | Should -Throw -ExceptionType ([System.NotImplementedException])
    }

    It 'her Windows sağlayıcısı kendi arayüzünden türer' {
        $pairs = @{
            WindowsRegistryProvider = 'IRegistryProvider'; WindowsServiceManager = 'IServiceManager'; WindowsTaskProvider = 'ITaskProvider'
            WindowsAppxProvider = 'IAppxProvider'; WindowsPackageProvider = 'IPackageProvider'; WindowsSystemInfoProvider = 'ISystemInfoProvider'
            WindowsPromptProvider = 'IPromptProvider'; WindowsFileProvider = 'IFileProvider'; WindowsShortcutProvider = 'IShortcutProvider'
            WindowsPowerProvider = 'IPowerProvider'; WindowsScriptHost = 'IScriptHost'; WindowsAudioProvider = 'IAudioProvider'
            WindowsTimerResolutionProvider = 'ITimerResolutionProvider'; WindowsEdgeProvider = 'IEdgeProvider'
            WindowsSystemControlProvider = 'ISystemControlProvider'; WindowsMemoryAgentProvider = 'IMemoryAgentProvider'
        }
        foreach ($k in $pairs.Keys) { ($k -as [type]).BaseType.Name | Should -Be $pairs[$k] -Because $k }
    }

    It 'Windows sağlayıcıları arayüzün bütün yöntemlerini ezer' {
        foreach ($name in @('WindowsRegistryProvider', 'WindowsServiceManager', 'WindowsTaskProvider', 'WindowsAppxProvider', 'WindowsPackageProvider',
                'WindowsSystemInfoProvider', 'WindowsPromptProvider', 'WindowsFileProvider', 'WindowsShortcutProvider', 'WindowsPowerProvider',
                'WindowsScriptHost', 'WindowsAudioProvider', 'WindowsTimerResolutionProvider', 'WindowsEdgeProvider', 'WindowsSystemControlProvider',
                'WindowsMemoryAgentProvider')) {
            $t = $name -as [type]
            foreach ($m in $t.BaseType.GetMethods() | Where-Object { $_.DeclaringType -eq $t.BaseType }) {
                $own = $t.GetMethod($m.Name, [type[]]@($m.GetParameters() | ForEach-Object { $_.ParameterType }))
                $own.DeclaringType.Name | Should -Be $name -Because "$name.$($m.Name) ezilmeli"
            }
        }
    }

    It 'kaldırıcı çıkış kodu: 0 ve 3010 (yeniden başlatma gerekli) başarı, diğerleri hata' {
        [WindowsPackageProvider]::IsUninstallerSuccess(0) | Should -BeTrue
        [WindowsPackageProvider]::IsUninstallerSuccess(3010) | Should -BeTrue
        [WindowsPackageProvider]::IsUninstallerSuccess(1) | Should -BeFalse
        [WindowsPackageProvider]::IsUninstallerSuccess(1603) | Should -BeFalse
    }

    It 'saf yardımcılar: kayıt defteri ve görev yolu ayrıştırma' {
        $p = [WindowsRegistryProvider]::SplitPath('hkcu:\Software\FAI_WinOP_Test\')
        $p['Hive'].ToString() | Should -Be 'CurrentUser'
        $p['SubKey'] | Should -Be 'Software\FAI_WinOP_Test'
        { [WindowsRegistryProvider]::SplitPath('HKXX:\a') } | Should -Throw
        [WindowsTaskProvider]::SplitPath('\Microsoft\Windows\A B\Görev') | Should -Be @('\Microsoft\Windows\A B\', 'Görev')
        [WindowsTaskProvider]::SplitPath('\Kok') | Should -Be @('\', 'Kok')
        [WindowsAppSettingsProvider]::SplitName('PersistentSettings\PersonalizationEnabled') | Should -Be @('PersistentSettings', 'PersonalizationEnabled')
        [WindowsAppSettingsProvider]::SplitName('VideoAutoplay') | Should -Be @('', 'VideoAutoplay')
        [WindowsAppSettingsProvider]::KeyPath('A\B') | Should -Be 'LocalState\A\B'
        [WindowsAppSettingsProvider]::KeyPath('') | Should -Be 'LocalState'
    }

    It 'eylemler doğrudan Windows API''sine dokunmaz (kaynak taraması, Faz 2 komutları)' {
        $forbidden = 'Get-ScheduledTask', 'Enable-ScheduledTask', 'Disable-ScheduledTask', 'Get-AppxPackage', 'Remove-AppxPackage',
        'Add-AppxPackage', 'Get-AppxProvisionedPackage', 'Remove-AppxProvisionedPackage', 'winget.exe', 'powercfg.exe', 'Add-Type',
        'WScript.Shell', 'System.IO.File', 'Get-CimInstance', 'Microsoft.Win32', 'Get-MMAgent', 'Enable-MMAgent', 'Disable-MMAgent'
        foreach ($f in Get-ChildItem -LiteralPath (Join-Path $script:FaiRepoRoot 'src/Actions') -Filter '*.ps1') {
            $text = Get-Content -LiteralPath $f.FullName -Raw
            foreach ($cmd in $forbidden) {
                $text | Should -Not -Match ('(?i)\b' + [regex]::Escape($cmd) + '\b') -Because "$($f.Name) sağlayıcıyı atlayıp $cmd kullanmamalı"
            }
        }
    }

    It 'native kaynaklar bundle''a gömülü; AudioEndpoint derlenir' {
        Get-FaiNativeSource -Name 'TimerResolution' | Should -Match 'class TimerResolutionService : ServiceBase'
        $src = Get-FaiNativeSource -Name 'AudioEndpoint'
        $src | Should -Match 'namespace FaiWinOP.Native'
        { Get-FaiNativeSource -Name 'Yok' } | Should -Throw '*Embedded native source not found*'
        if ($null -eq ('FaiWinOP.Native.AudioEndpoint' -as [type])) { Add-Type -TypeDefinition $src -Language CSharp }
        ('FaiWinOP.Native.AudioEndpoint' -as [type]).GetMethod('SetVolume') | Should -Not -BeNullOrEmpty
    }
}

Describe 'RegistryEachAction' {
    BeforeAll {
        $script:Root = 'HKCU:\Software\FAI_WinOP_Test\Each'
        function EachDef([object] $Exclude) {
            $d = @{ Type = 'RegistryEach'; Path = $script:Root; Name = 'Enabled'; Value = 0; Kind = 'DWord' }
            if ($null -ne $Exclude) { $d['Exclude'] = $Exclude }
            return $d
        }
        function Seeded {
            $ctx = New-Ctx
            $ctx.Registry.Seed("$script:Root\App.One", 'Rank', 1, 'DWord')
            $ctx.Registry.Seed("$script:Root\App.Two", 'Enabled', 1, 'DWord')
            $ctx.Registry.Seed("$script:Root\Keep.Me", 'Enabled', 1, 'DWord')
            $ctx.Registry.Seed("$script:Root\App.Zero\Alt", 'X', 1, 'DWord')
            return $ctx
        }
    }

    It 'şema: geçerli tanım hatasız; Registry kuralları ve Exclude denetlenir' {
        Errs (EachDef @('Keep*')) | Should -BeNullOrEmpty
        Errs (EachDef $null) | Should -BeNullOrEmpty
        (Errs (EachDef 'Keep*')) -join "`n" | Should -Match 'Exclude: '
        (Errs (EachDef @('Keep*', ''))) -join "`n" | Should -Match 'Exclude: '
        $bad = EachDef $null
        $bad['Kind'] = 'Dword2'
        $bad['Ensure'] = 'Absent'
        $msgs = (Errs $bad) -join "`n"
        $msgs | Should -Match 'Kind: '
        $msgs | Should -Match 'Ensure: unknown field'
    }

    It 'alt anahtar adları büyük/küçük harfi korunarak listelenir; olmayan anahtar boş' {
        $ctx = Seeded
        @($ctx.Registry.GetSubKeyNames($script:Root)) | Should -Be @('App.One', 'App.Two', 'App.Zero', 'Keep.Me')
        @($ctx.Registry.GetSubKeyNames('HKCU:\Software\Yok')).Count | Should -Be 0
    }

    It 'istisna dışındaki her alt anahtara yazar; geri alma birebir döner (JSON üzerinden)' {
        $ctx = Seeded
        $a = Act (EachDef @('keep*'))
        $a.Test($ctx) | Should -BeFalse
        @($a.Pending($ctx)) | Should -Be @('App.One', 'App.Two', 'App.Zero')
        $null = Invoke-Cycle $ctx $a { $ctx.Registry.Dump() -join "`n" }
        # Revert sonrası Keep.Me hiç değişmedi, App.One'da değer yok (önceden yoktu)
        $ctx.Registry.ValueExists("$script:Root\App.One", 'Enabled') | Should -BeFalse
        $ctx.Registry.GetValue("$script:Root\App.Two", 'Enabled') | Should -Be 1
    }

    It 'Apply istisnaya dokunmaz' {
        $ctx = Seeded
        (Act (EachDef @('Keep.Me'))).Apply($ctx)
        $ctx.Registry.GetValue("$script:Root\Keep.Me", 'Enabled') | Should -Be 1
        $ctx.Registry.GetValue("$script:Root\App.Zero", 'Enabled') | Should -Be 0
    }

    It 'parametreden gelen dizi Exclude içinde düzleştirilir' {
        $t = [Tweak]::FromHashtable(@{
                Id = 'test.each'; Title = 'T'; Description = 'D'; Category = 'test'; Risk = 'Safe'
                Params = @{ ex = @('App.One', 'App.Two') }
                Actions = @(EachDef @('Keep*', '{{ex}}'))
            }, 'test')
        @($t.Actions[0].Patterns()) | Should -Be @('Keep*', 'App.One', 'App.Two')
        $ctx = Seeded
        @($t.Actions[0].Pending($ctx)) | Should -Be @('App.Zero')
        $t2 = $t.WithParams(@{ ex = @() })
        @($t2.Actions[0].Pending($ctx)) | Should -Be @('App.One', 'App.Two', 'App.Zero')
    }

    It 'alt anahtar yoksa ya da hepsi uygunsa Test doğru; Preview değişecekleri sayar' {
        $ctx = New-Ctx
        (Act (EachDef $null)).Test($ctx) | Should -BeTrue
        $ctx = Seeded
        $a = Act (EachDef @('Keep*'))
        $a.Preview($ctx) | Should -Match 'will change 3 subkeys: App.One, App.Two, App.Zero'
        $a.Describe() | Should -Match 'excluding: Keep\*'
    }

    It 'geri alma: arada silinmiş alt anahtarı yeniden oluşturmaz' {
        $ctx = Seeded
        $a = Act (EachDef $null)
        $snap = RoundTrip ($a.Snapshot($ctx))
        $a.Apply($ctx)
        $ctx.Registry.DeleteValue("$script:Root\App.One", 'Rank')
        $ctx.Registry.DeleteValue("$script:Root\App.One", 'Enabled')
        $ctx.Registry.DeleteEmptyKey("$script:Root\App.One")
        $a.Revert($ctx, $snap)
        $ctx.Registry.KeyExists("$script:Root\App.One") | Should -BeFalse
    }
}

Describe 'RegistryEachAction: Include / Match / SubKey süzgeçleri (Faz 7)' {
    BeforeAll {
        $script:Gpu = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
        function GpuCtx {
            $ctx = New-Ctx
            $ctx.Registry.Seed("$script:Gpu\0000", 'ProviderName', 'NVIDIA', 'String')
            $ctx.Registry.Seed("$script:Gpu\0000\UMD", 'X', 1, 'DWord')
            $ctx.Registry.Seed("$script:Gpu\0001", 'ProviderName', 'Intel Corporation', 'String')
            $ctx.Registry.Seed("$script:Gpu\0001\UMD", 'X', 1, 'DWord')
            $ctx.Registry.Seed("$script:Gpu\0002", 'ProviderName', 'Advanced Micro Devices, Inc.', 'String')
            $ctx.Registry.Seed("$script:Gpu\Configuration", 'ProviderName', 'NVIDIA', 'String')
            return $ctx
        }
        function GpuDef([hashtable] $Extra) {
            $d = @{ Type = 'RegistryEach'; Path = $script:Gpu; Name = 'DisableDynamicPstate'; Value = 1; Kind = 'DWord' }
            foreach ($k in $Extra.Keys) { $d[$k] = $Extra[$k] }
            return $d
        }
    }

    It 'şema: Include / Match / SubKey denetlenir' {
        Errs (GpuDef @{ Include = @('[0-9][0-9][0-9][0-9]'); Match = @{ Name = 'ProviderName'; Like = @('NVIDIA*') }; SubKey = 'UMD' }) | Should -BeNullOrEmpty
        Errs (GpuDef @{ Match = @{ Name = 'ProviderName'; Like = 'NVIDIA*' } }) | Should -BeNullOrEmpty
        $m = (Errs (GpuDef @{ Include = 'x'; Match = @{ Name = ''; Like = @(); Fazla = 1 }; SubKey = '\UMD' })) -join "`n"
        $m | Should -Match 'Include: '
        $m | Should -Match 'Match\.Name: '
        $m | Should -Match 'Match\.Like: '
        $m | Should -Match 'Match\.Fazla: unknown field'
        $m | Should -Match 'SubKey: '
    }

    It 'Include + Match yalnız NVIDIA bağdaştırıcısını hedefler; geri alma birebir' {
        $ctx = GpuCtx
        $a = Act (GpuDef @{ Include = @('[0-9][0-9][0-9][0-9]'); Match = @{ Name = 'ProviderName'; Like = @('NVIDIA*') } })
        @($a.Targets($ctx)) | Should -Be @('0000')
        $a.Describe() | Should -Match 'only: \[0-9\]'
        $a.Describe() | Should -Match 'ProviderName: NVIDIA\*'
        $null = Invoke-Cycle $ctx $a { $ctx.Registry.Dump() -join "`n" }
        $a.Apply($ctx)
        $ctx.Registry.GetValue("$script:Gpu\0000", 'DisableDynamicPstate') | Should -Be 1
        $ctx.Registry.ValueExists("$script:Gpu\0001", 'DisableDynamicPstate') | Should -BeFalse
        $ctx.Registry.ValueExists("$script:Gpu\Configuration", 'DisableDynamicPstate') | Should -BeFalse
    }

    It 'SubKey: değer alt anahtarın altındaki (var olan) anahtara yazılır' {
        $ctx = GpuCtx
        $a = Act (GpuDef @{ Include = @('0*'); SubKey = 'UMD' })
        @($a.Targets($ctx)) | Should -Be @('0000', '0001')
        $null = Invoke-Cycle $ctx $a { $ctx.Registry.Dump() -join "`n" }
        $a.Apply($ctx)
        $ctx.Registry.GetValue("$script:Gpu\0001\UMD", 'DisableDynamicPstate') | Should -Be 1
        $ctx.Registry.KeyExists("$script:Gpu\0002\UMD") | Should -BeFalse
        $a.Describe() | Should -Match '\\\*\\UMD\\DisableDynamicPstate'
    }
}

Describe 'Tek seferlik sistem eylemleri: RestorePoint, Reboot, OpenSettings (Faz 7)' {
    It 'şema' {
        Errs @{ Type = 'RestorePoint'; Description = 'FAI_WinOP' } | Should -BeNullOrEmpty
        ((Errs @{ Type = 'RestorePoint' }) -join "`n") | Should -Match 'Description: required'
        ((Errs @{ Type = 'RestorePoint'; Description = ('x' * 65) }) -join "`n") | Should -Match 'Description: '
        Errs @{ Type = 'Reboot'; Firmware = $true; Delay = 0 } | Should -BeNullOrEmpty
        ((Errs @{ Type = 'Reboot'; Firmware = $false; Delay = 900 }) -join "`n") | Should -Match 'Firmware: .*Delay: |Delay: '
        ((Errs @{ Type = 'Reboot'; Firmware = $false }) -join "`n") | Should -Match 'Firmware: '
        Errs @{ Type = 'OpenSettings'; Uri = 'ms-settings:activation'; Message = 'm' } | Should -BeNullOrEmpty
        ((Errs @{ Type = 'OpenSettings'; Uri = 'https://example.com'; Message = '' }) -join "`n") | Should -Match 'Uri: .*Message: |Message: '
    }

    It 'RestorePoint: her zaman bekler, koruma kapalıysa açar, geri alma noktayı silmez' {
        $ctx = New-Ctx
        $ctx.SystemControl.RestoreEnabled = $false
        $a = Act @{ Type = 'RestorePoint'; Description = 'FAI_WinOP' }
        $a.Preview($ctx) | Should -Match 'off, will be turned on'
        $a.Test($ctx) | Should -BeFalse
        $a.Apply($ctx)
        $ctx.SystemControl.RestoreEnabled | Should -BeTrue
        @($ctx.SystemControl.RestorePoints) | Should -Be @('FAI_WinOP')
        $a.Test($ctx) | Should -BeFalse
        $a.Revert($ctx, @{})
        $ctx.SystemControl.RestorePoints.Count | Should -Be 1
    }

    It 'Reboot: gecikmeyle ürün yazılımına yeniden başlatır (varsayılan 10 sn)' {
        $ctx = New-Ctx
        (Act @{ Type = 'Reboot'; Firmware = $true }).Apply($ctx)
        (Act @{ Type = 'Reboot'; Firmware = $true; Delay = 0 }).Apply($ctx)
        @($ctx.SystemControl.Restarts) | Should -Be @(10, 0)
    }

    It 'OpenSettings: sayfayı açar; etkileşimsiz kipte hata' {
        $ctx = New-Ctx
        $a = Act @{ Type = 'OpenSettings'; Uri = 'ms-settings:activation'; Message = 'Anahtarı girin.' }
        $a.Test($ctx) | Should -BeFalse
        $a.Apply($ctx)
        @($ctx.Shell.Opened) | Should -Be @('ms-settings:activation')
        $ctx.Unattended = $true
        { $a.Apply($ctx) } | Should -Throw '*Needs interaction*'
        $ctx.Shell.Opened.Count | Should -Be 1
    }

    It 'sistem bilgisi: mantıksal işlemci ve çekirdek sayısı (Fake varsayılanı 16 / 8)' {
        $ctx = New-Ctx
        $ctx.SystemInfo.GetLogicalProcessorCount() | Should -Be 16
        $ctx.SystemInfo.GetCoreCount() | Should -Be 8
        $ctx.ResumeCommand | Should -Be ''
    }
}

Describe 'Güç planı ve bellek yöneticisi eylemleri: PowerScheme, Hibernate, MMAgent (Faz 7)' {
    BeforeAll {
        $script:Plan = '46414900-5769-4e4f-9000-000000000001'
        $script:Balanced = '381b4222-f694-41f0-9685-ff5bb260df2e'
    }

    It 'şema' {
        Errs @{ Type = 'PowerScheme'; Guid = $script:Plan; Name = 'FAI_WinOP'; Base = 'SCHEME_BALANCED' } | Should -BeNullOrEmpty
        (Errs @{ Type = 'PowerScheme'; Guid = 'SCHEME_MAX'; Name = ''; Base = 'a b' }) | Should -HaveCount 3
        Errs @{ Type = 'Hibernate'; Enabled = $true } | Should -BeNullOrEmpty
        Errs @{ Type = 'Hibernate'; Enabled = 1 } | Should -HaveCount 1
        Errs @{ Type = 'MMAgent'; Feature = 'MemoryCompression'; Enabled = $false } | Should -BeNullOrEmpty
        (Errs @{ Type = 'MMAgent'; Feature = 'Yok'; Enabled = 'h' }) | Should -HaveCount 2
    }

    It 'PowerScheme: Balanced kopyası kurulur, etkin olur; geri alma eski planı etkin yapar ve planı siler' {
        $ctx = New-Ctx
        $ctx.Power.Seed($script:Balanced, 'SUB_SLEEP', 'STANDBYIDLE', 1800, 900)
        $ctx.Power.Active = '99999999-9999-9999-9999-999999999999'
        $ctx.Power.Schemes['99999999-9999-9999-9999-999999999999'] = @{}
        $a = Act @{ Type = 'PowerScheme'; Guid = $script:Plan; Name = 'FAI_WinOP'; Base = $script:Balanced }
        $a.Test($ctx) | Should -BeFalse
        $a.Preview($ctx) | Should -Match 'no plan'
        $after = Invoke-Cycle $ctx $a { $ctx.Power.Dump() -join ';' }
        $after | Should -Match ('etkin=' + $script:Plan)
        $after | Should -Match ([regex]::Escape($script:Plan) + '\|sub_sleep\|standbyidle\|1800\|900')
        $ctx.Power.ResolveScheme($script:Plan) | Should -BeNullOrEmpty
        $ctx.Power.Active | Should -Be '99999999-9999-9999-9999-999999999999'
    }

    It 'PowerScheme: Balanced kopyalanamazsa etkin plan temel alınır (uyarı)' {
        $ctx = New-Ctx
        $ctx.Power.Schemes.Remove($script:Balanced)
        $ctx.Power.NoCopy = @($script:Balanced)
        $ctx.Power.Active = 'a1841308-3541-4fab-bc81-f71556f20b4a'
        $ctx.Power.Seed('SCHEME_MAX', 'SUB_SLEEP', 'STANDBYIDLE', 0, 0)
        $a = Act @{ Type = 'PowerScheme'; Guid = $script:Plan; Name = 'FAI_WinOP'; Base = $script:Balanced }
        $a.Apply($ctx)
        $ctx.Power.Active | Should -Be $script:Plan
        $ctx.Power.GetValue($script:Plan, 'SUB_SLEEP', 'STANDBYIDLE', $true) | Should -Be 0
        @($ctx.Logger.Entries | Where-Object { $_.Message -match 'could not be copied' }).Count | Should -BeGreaterThan 0
    }

    It 'PowerScheme: plan zaten varsa (önceki çalıştırma) geri alma onu silmez, yalnız eski planı etkin yapar' {
        $ctx = New-Ctx
        $ctx.Power.Schemes[$script:Plan] = @{}
        $a = Act @{ Type = 'PowerScheme'; Guid = $script:Plan; Name = 'FAI_WinOP'; Base = $script:Balanced }
        $snap = RoundTrip ($a.Snapshot($ctx))
        $a.Apply($ctx)
        $a.Revert($ctx, $snap)
        $ctx.Power.Active | Should -Be $script:Balanced
        $ctx.Power.ResolveScheme($script:Plan) | Should -Be $script:Plan
    }

    It 'Power: verilen plan henüz yoksa Test hata değil $false, önizleme "oluşturulacak" der' {
        $ctx = New-Ctx
        $a = Act @{ Type = 'Power'; Scheme = $script:Plan; Subgroup = 'SUB_SLEEP'; Setting = 'STANDBYIDLE'; AC = 0 }
        $a.Test($ctx) | Should -BeFalse
        $a.Preview($ctx) | Should -Match 'plan missing, will be created'
    }

    It 'Hibernate ve MMAgent: uygula → geri al' {
        $ctx = New-Ctx
        $h = Act @{ Type = 'Hibernate'; Enabled = $true }
        $h.Test($ctx) | Should -BeFalse
        $h.Preview($ctx) | Should -Match 'current: off'
        [void](Invoke-Cycle $ctx $h { [string]$ctx.Power.GetHibernate() })
        $m = Act @{ Type = 'MMAgent'; Feature = 'MemoryCompression'; Enabled = $false }
        $m.Preview($ctx) | Should -Match 'MemoryCompression → off \[current: on\]'
        $after = Invoke-Cycle $ctx $m { $ctx.MemoryAgent.Dump() -join ';' }
        $after | Should -Match 'MemoryCompression=False'
        $after | Should -Match 'PageCombining=True'
    }

    It 'MMAgent: komut hata verip ayarı kaydettiyse başarı + uyarı; kaydetmediyse hata (Faz 9)' {
        $ctx = New-Ctx
        $m = Act @{ Type = 'MMAgent'; Feature = 'MemoryCompression'; Enabled = $false }
        $ctx.MemoryAgent.Throw['MemoryCompression'] = 'persist'
        { $m.Apply($ctx) } | Should -Not -Throw
        $m.Test($ctx) | Should -BeTrue
        $ctx.Logger.Count('WARN') | Should -Be 1
        $p = Act @{ Type = 'MMAgent'; Feature = 'PageCombining'; Enabled = $false }
        $ctx.MemoryAgent.Throw['PageCombining'] = 'fail'
        { $p.Apply($ctx) } | Should -Throw '*not supported*'
    }

    It 'AppSetting Key: LocalState altındaki anahtara yazar' {
        $ctx = New-Ctx
        $ctx.AppSettings.SeedPackage('Microsoft.WindowsStore_8wekyb3d8bbwe')
        Errs @{ Type = 'AppSetting'; Package = 'Microsoft.WindowsStore_8wekyb3d8bbwe'; Key = '\Kok'; Name = 'A\B'; Kind = 'Bool'; Value = $false } | Should -HaveCount 2
        $a = Act @{ Type = 'AppSetting'; Package = 'Microsoft.WindowsStore_8wekyb3d8bbwe'; Key = 'PersistentSettings'; Name = 'PersonalizationEnabled'; Kind = 'Bool'; Value = $false }
        $a.Describe() | Should -Match 'PersistentSettings\\PersonalizationEnabled'
        [void](Invoke-Cycle $ctx $a { @($ctx.AppSettings.Packages['microsoft.windowsstore_8wekyb3d8bbwe'].Keys | Sort-Object) -join ';' })
        $a.Apply($ctx)
        $ctx.AppSettings.GetValue('Microsoft.WindowsStore_8wekyb3d8bbwe', 'PersistentSettings\PersonalizationEnabled')['Data'][0] | Should -Be 0
    }
}
