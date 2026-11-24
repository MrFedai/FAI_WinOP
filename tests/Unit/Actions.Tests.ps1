#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }
# RegistryAction / ServiceAction: Test · Snapshot · Apply · Revert, yalnız Fake sağlayıcı üzerinden.
# Ayrıca arayüz tabanları (NotImplemented) ve Fake sağlayıcı davranışları.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Load-Fakes.ps1')
    $script:Key = 'HKCU:\Software\FAI_WinOP_Test\Actions'
    function New-Ctx { return (New-FakeContext -BackupRoot (Join-Path $TestDrive 'b')) }
    function New-Reg([hashtable] $Def) { $Def['Type'] = 'Registry'; return [RegistryAction]::new($Def) }
}

Describe 'RegistryAction' {
    It 'Test: değer yok → $false; hedefle aynı → $true; tür farklıysa $false' {
        $ctx = New-Ctx
        $a = New-Reg @{ Path = $script:Key; Name = 'V'; Value = 1; Kind = 'DWord' }
        $a.Test($ctx) | Should -BeFalse
        $ctx.Registry.Seed($script:Key, 'V', 1, 'DWord')
        $a.Test($ctx) | Should -BeTrue
        $ctx.Registry.Seed($script:Key, 'V', 1, 'QWord')
        $a.Test($ctx) | Should -BeFalse
    }

    It 'Test: Ensure=Absent değer yoksa $true, varsa $false' {
        $ctx = New-Ctx
        $a = New-Reg @{ Path = $script:Key; Name = 'V'; Ensure = 'Absent' }
        $a.Test($ctx) | Should -BeTrue
        $ctx.Registry.Seed($script:Key, 'V', 1, 'DWord')
        $a.Test($ctx) | Should -BeFalse
    }

    It 'Test: dizi değerleri (Binary, MultiString) eleman eleman karşılaştırılır' {
        $ctx = New-Ctx
        $ctx.Registry.Seed($script:Key, 'B', @(1, 2), 'Binary')
        (New-Reg @{ Path = $script:Key; Name = 'B'; Value = @(1, 2); Kind = 'Binary' }).Test($ctx) | Should -BeTrue
        (New-Reg @{ Path = $script:Key; Name = 'B'; Value = @(1, 3); Kind = 'Binary' }).Test($ctx) | Should -BeFalse
    }

    It 'Snapshot: var olan değerin içeriğini ve türünü, olmayanın yokluğunu yakalar; yazma yapmaz' {
        $ctx = New-Ctx
        $ctx.Registry.Seed($script:Key, 'V', 'metin', 'ExpandString')
        $a = New-Reg @{ Path = $script:Key; Name = 'V'; Value = 1; Kind = 'DWord' }
        $s = $a.Snapshot($ctx)
        $s['Exists'] | Should -BeTrue
        $s['Value'] | Should -Be 'metin'
        $s['Kind'] | Should -Be 'ExpandString'
        $missing = (New-Reg @{ Path = $script:Key; Name = 'Yok'; Value = 1; Kind = 'DWord' }).Snapshot($ctx)
        $missing['Exists'] | Should -BeFalse
        $ctx.Registry.WriteCount | Should -Be 0
    }

    It 'Apply + Revert: her tür için başlangıç durumu birebir döner' {
        $ctx = New-Ctx
        $ctx.Registry.Seed($script:Key, 'Old', 'eski', 'String')
        $before = $ctx.Registry.Dump() -join "`n"
        $defs = @(
            @{ Name = 'Old'; Value = 5; Kind = 'DWord' }
            @{ Name = 'Q'; Value = 4294967296; Kind = 'QWord' }
            @{ Name = 'S'; Value = 'x'; Kind = 'String' }
            @{ Name = 'X'; Value = '%PATH%'; Kind = 'ExpandString' }
            @{ Name = 'M'; Value = @('a', 'b'); Kind = 'MultiString' }
            @{ Name = 'B'; Value = @(1, 2, 3); Kind = 'Binary' }
        )
        $snaps = @()
        $actions = @()
        foreach ($d in $defs) {
            $d['Path'] = $script:Key
            $a = New-Reg $d
            $snaps += , $a.Snapshot($ctx)
            $a.Apply($ctx)
            $actions += $a
        }
        ($ctx.Registry.Dump() -join "`n") | Should -Not -Be $before
        $ctx.Registry.GetValueKind($script:Key, 'B') | Should -Be 'Binary'
        for ($i = $actions.Count - 1; $i -ge 0; $i--) { $actions[$i].Revert($ctx, $snaps[$i]) }
        ($ctx.Registry.Dump() -join "`n") | Should -Be $before
    }

    It 'Ensure=Absent: Apply siler, Revert değeri türüyle geri koyar' {
        $ctx = New-Ctx
        $ctx.Registry.Seed($script:Key, 'V', @(7, 8), 'Binary')
        $a = New-Reg @{ Path = $script:Key; Name = 'V'; Ensure = 'Absent' }
        $s = $a.Snapshot($ctx)
        $a.Apply($ctx)
        $ctx.Registry.ValueExists($script:Key, 'V') | Should -BeFalse
        $a.Revert($ctx, $s)
        $ctx.Registry.GetValueKind($script:Key, 'V') | Should -Be 'Binary'
        ($ctx.Registry.GetValue($script:Key, 'V') -join ',') | Should -Be '7,8'
    }

    It 'Revert: snapshot''ta olmayan değer yoksa yazma yapmaz' {
        $ctx = New-Ctx
        $a = New-Reg @{ Path = $script:Key; Name = 'V'; Value = 1; Kind = 'DWord' }
        $a.Revert($ctx, @{ Exists = $false })
        $ctx.Registry.WriteCount | Should -Be 0
    }

    It 'Describe / Preview Türkçe ve tek satır' {
        $ctx = New-Ctx
        $a = New-Reg @{ Path = $script:Key; Name = 'V'; Value = 1; Kind = 'DWord' }
        $a.Describe() | Should -Match '^Kayıt defteri: .*\\V = 1 \(DWord\)$'
        $a.Preview($ctx) | Should -Match '\[şu an: yok\]$'
        (New-Reg @{ Path = $script:Key; Name = 'V'; Ensure = 'Absent' }).Describe() | Should -Match 'silinir$'
    }

    It 'sağlayıcı yol büyük/küçük harfini ve sondaki ters eğik çizgiyi yok sayar' {
        $ctx = New-Ctx
        $ctx.Registry.Seed('HKCU:\Software\Foo\', 'V', 1, 'DWord')
        $ctx.Registry.ValueExists('hkcu:\software\FOO', 'v') | Should -BeTrue
        $ctx.Registry.KeyExists('HKCU:\SOFTWARE\foo') | Should -BeTrue
    }
}

Describe 'ServiceAction' {
    BeforeAll {
        function New-Svc([hashtable] $Def) { $Def['Type'] = 'Service'; return [ServiceAction]::new($Def) }
    }

    It 'Apply + Revert: başlangıç türü ve durum birebir döner' {
        $ctx = New-Ctx
        $ctx.Services.Seed('Svc', 'Automatic', 'Running')
        $before = $ctx.Services.Dump() -join "`n"
        $a = New-Svc @{ Name = 'Svc'; StartType = 'Disabled'; State = 'Stopped' }
        $a.Test($ctx) | Should -BeFalse
        $snap = $a.Snapshot($ctx)
        $a.Apply($ctx)
        $a.Test($ctx) | Should -BeTrue
        $ctx.Services.GetStartType('Svc') | Should -Be 'Disabled'
        $ctx.Services.GetStatus('Svc') | Should -Be 'Stopped'
        $a.Revert($ctx, $snap)
        ($ctx.Services.Dump() -join "`n") | Should -Be $before
    }

    It 'yalnız StartType verilirse durum değişmez' {
        $ctx = New-Ctx
        $ctx.Services.Seed('Svc', 'Automatic', 'Running')
        (New-Svc @{ Name = 'Svc'; StartType = 'Manual' }).Apply($ctx)
        $ctx.Services.GetStatus('Svc') | Should -Be 'Running'
        $ctx.Services.WriteCount | Should -Be 1
    }

    It 'zaten hedef durumdaysa Apply yazma yapmaz' {
        $ctx = New-Ctx
        $ctx.Services.Seed('Svc', 'Disabled', 'Stopped')
        (New-Svc @{ Name = 'Svc'; StartType = 'Disabled'; State = 'Stopped' }).Apply($ctx)
        $ctx.Services.WriteCount | Should -Be 0
    }

    It 'olmayan servis: Test $true, Snapshot Exists=false, Apply / Revert yazma yapmaz' {
        $ctx = New-Ctx
        $a = New-Svc @{ Name = 'Yok'; StartType = 'Disabled' }
        $a.Test($ctx) | Should -BeTrue
        $a.Snapshot($ctx)['Exists'] | Should -BeFalse
        $a.Apply($ctx)
        $a.Revert($ctx, @{ Exists = $false })
        $ctx.Services.WriteCount | Should -Be 0
        $a.Preview($ctx) | Should -Match 'servis yok'
    }

    It 'Revert: durdurulmuş ve devre dışı servisi çalışır / otomatik hale geri getirir' {
        $ctx = New-Ctx
        $ctx.Services.Seed('Svc', 'Disabled', 'Stopped')
        $a = New-Svc @{ Name = 'Svc'; StartType = 'Automatic'; State = 'Running' }
        $snap = $a.Snapshot($ctx)
        $a.Apply($ctx)
        $ctx.Services.GetStatus('Svc') | Should -Be 'Running'
        $a.Revert($ctx, $snap)
        $ctx.Services.GetStartType('Svc') | Should -Be 'Disabled'
        $ctx.Services.GetStatus('Svc') | Should -Be 'Stopped'
    }
}

Describe 'Eylem fabrikası' {
    It 'Type alanına göre doğru sınıfı üretir; bilinmeyen tür hata verir' {
        (New-FaiAction @{ Type = 'Registry'; Path = 'HKCU:\a'; Name = 'n'; Value = 1; Kind = 'DWord' }).GetType().Name | Should -Be 'RegistryAction'
        (New-FaiAction @{ Type = 'Service'; Name = 's'; State = 'Running' }).GetType().Name | Should -Be 'ServiceAction'
        { New-FaiAction @{ Type = 'Teleport' } } | Should -Throw '*Bilinmeyen eylem türü*'
    }

    It 'eylemler doğrudan Windows cmdlet''i çağırmaz (kaynak taraması)' {
        $forbidden = 'Set-ItemProperty', 'New-ItemProperty', 'Remove-ItemProperty', 'Set-Service', 'Stop-Service', 'Start-Service',
        'Get-ItemProperty', 'reg.exe', 'sc.exe', 'Get-Service', 'New-Item', 'Remove-Item'
        foreach ($f in Get-ChildItem -LiteralPath (Join-Path $script:FaiRepoRoot 'src/Actions') -Filter '*.ps1') {
            $text = Get-Content -LiteralPath $f.FullName -Raw
            foreach ($cmd in $forbidden) {
                $text | Should -Not -Match ('(?i)\b' + [regex]::Escape($cmd) + '\b') -Because "$($f.Name) sağlayıcıyı atlayıp $cmd çağırmamalı"
            }
        }
    }
}

Describe 'Arayüz tabanları ve Fake sağlayıcılar' {
    It 'arayüz taban sınıfı yöntemleri NotImplementedException atar' {
        { ([IRegistryProvider]::new()).ValueExists('a', 'b') } | Should -Throw -ExceptionType ([System.NotImplementedException])
        { ([IServiceManager]::new()).ServiceExists('a') } | Should -Throw -ExceptionType ([System.NotImplementedException])
        { ([ITaskProvider]::new()).GetTaskState('a') } | Should -Throw -ExceptionType ([System.NotImplementedException])
        { ([IAppxProvider]::new()).GetInstalled() } | Should -Throw -ExceptionType ([System.NotImplementedException])
        { ([IPackageProvider]::new()).IsInstalled('a', 'winget') } | Should -Throw -ExceptionType ([System.NotImplementedException])
        { ([ISystemInfoProvider]::new()).IsLaptop() } | Should -Throw -ExceptionType ([System.NotImplementedException])
        { ([IPromptProvider]::new()).Confirm('a') } | Should -Throw -ExceptionType ([System.NotImplementedException])
        { ([ActionBase]::new()).Describe() } | Should -Throw -ExceptionType ([System.NotImplementedException])
    }

    It 'her Fake sağlayıcı kendi arayüzünden türer ve yazma çağrılarını sayar' {
        $ctx = New-Ctx
        $ctx.Tasks.Seed('\A\B', 'Enabled')
        $ctx.Tasks.GetTaskState('\a\b') | Should -Be 'Enabled'
        $ctx.Tasks.GetTaskState('\yok') | Should -Be ''
        $ctx.Tasks.SetTaskEnabled('\A\B', $false)
        $ctx.Tasks.GetTaskState('\A\B') | Should -Be 'Disabled'
        $ctx.Tasks.WriteCount | Should -Be 1

        $ctx.Appx.Seed(@('X.App'), @('X.App'))
        $ctx.Appx.GetInstalled() | Should -Contain 'X.App'
        $ctx.Appx.RemoveInstalled('X.App')
        $ctx.Appx.GetInstalled().Count | Should -Be 0
        $ctx.Appx.GetProvisioned().Count | Should -Be 1
        $ctx.Appx.WriteCount | Should -Be 1

        $ctx.Packages.IsInstalled('Foo.Bar', 'winget') | Should -BeFalse
        $ctx.Packages.Install('Foo.Bar', 'winget')
        $ctx.Packages.IsInstalled('foo.bar', 'winget') | Should -BeTrue
        $ctx.Packages.IsInstalled('Foo.Bar', 'msstore') | Should -BeFalse
        $ctx.Packages.WriteCount | Should -Be 1

        Get-FakeWriteCount $ctx | Should -Be 3
    }

    It 'FakePromptProvider: yanıt listesi biterse güvenli varsayılan (reddet)' {
        $p = [FakePromptProvider]::new()
        $p.Enqueue(@('E'))
        $p.Confirm('x') | Should -BeTrue
        $p.Confirm('y') | Should -BeFalse
        $p.ConfirmExact('z', 'EVET') | Should -BeFalse
        $p.Asked.Count | Should -Be 3
    }
}

Describe 'Reporter' {
    It 'Render durum etiketlerini, nedenleri, satırları ve özeti içerir' {
        $r = [Reporter]::new()
        $r.Heading = 'Başlık'
        [void]$r.Add('a.b', 'Başlık A', 'Applied', '', [string[]]@('satır 1'))
        [void]$r.Add('c.d', 'Başlık C', 'Skipped', 'sebep', [string[]]@())
        $text = $r.Render()
        $text | Should -Match 'Başlık'
        $text | Should -Match '\[UYGULANDI\] a\.b'
        $text | Should -Match '· satır 1'
        $text | Should -Match '\[ATLANDI\] c\.d — Başlık C \(sebep\)'
        $text | Should -Match 'Özet: UYGULANDI: 1 · ATLANDI: 1'
        $r.HasFailures() | Should -BeFalse
    }
}

Describe 'Logger' {
    It 'bellekte tutar, dosyaya UTF-8 yazar, düzeyleri sayar' {
        $path = Join-Path $TestDrive 'log/run.log'
        $l = [Logger]::new($path, $true)
        $l.Info('Açılış sesi')
        $l.Warn('uyarı')
        $l.Error('hata')
        $l.Count('INFO') | Should -Be 1
        $l.Count('ERROR') | Should -Be 1
        $l.Entries.Count | Should -Be 3
        (Get-Content -LiteralPath $path -Raw -Encoding UTF8) | Should -Match 'Açılış sesi'
    }
}
