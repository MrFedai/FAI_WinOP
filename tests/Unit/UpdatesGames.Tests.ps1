#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }
# Faz 7 (C): Windows Update (WindowsUpdate, UpdatePause, setup.updates-staged, -UpdatesOn / -UpdatesOff) ve oyun başına
# ayarlar (games şeması, benzeşim maskesi, IFEO önceliği, GameAffinity açılış görevi). Yalnız Fake sağlayıcılar.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Load-Fakes.ps1')
    $script:Catalog = Import-FaiTweakCatalog -Path (Join-Path $script:FaiRepoRoot 'tweaks')
    $script:Seq = 0
    $script:UX = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
    $script:Ifeo = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'
    function New-Ctx([switch] $DryRun, [switch] $Unattended) {
        $script:Seq++
        return (New-FakeContext -BackupRoot (Join-Path $TestDrive ('u{0}' -f $script:Seq)) -DryRun:$DryRun -Unattended:$Unattended)
    }
    function Act([hashtable] $Def) { return (New-FaiAction -Definition $Def) }
    function Errs([hashtable] $Def) { return @(Get-FaiActionError -Definition $Def) }
    function RoundTrip([hashtable] $Snapshot) { return [hashtable](ConvertFrom-JsonText -Json ($Snapshot | ConvertTo-Json -Depth 10)) }
    function Get-State([ExecutionContext] $Ctx) {
        return (@($Ctx.Registry.Dump()) + @($Ctx.Files.Dump()) +
            @($Ctx.Tasks.Commands.Keys | Sort-Object | ForEach-Object { '{0}={1} {2}' -f $_, $Ctx.Tasks.Commands[$_]['Execute'], $Ctx.Tasks.Commands[$_]['Arguments'] })) -join "`n"
    }
    function New-GameProfile([object[]] $Games, [object[]] $Tweaks = @()) {
        return [Profile]::FromHashtable(@{ name = 'oyun'; tweaks = @($Tweaks); games = @($Games) }, 'test')
    }
    [FaiClock]::Fixed = [datetime]::new(2026, 11, 24, 10, 30, 0, [System.DateTimeKind]::Utc)
}

AfterAll {
    [FaiClock]::Fixed = $null
}

Describe 'UpdatePause eylemi' {
    It 'şema: Days 1-3650, Ensure=Absent iken Days yok' {
        Errs @{ Type = 'UpdatePause'; Days = 365 } | Should -BeNullOrEmpty
        Errs @{ Type = 'UpdatePause'; Ensure = 'Absent' } | Should -BeNullOrEmpty
        Errs @{ Type = 'UpdatePause'; Days = '{{pauseDays}}' } | Should -BeNullOrEmpty
        (Errs @{ Type = 'UpdatePause' }) | Should -Match 'Days: required'
        (Errs @{ Type = 'UpdatePause'; Days = 0 }) | Should -Match '1 to 3650'
        (Errs @{ Type = 'UpdatePause'; Days = 5; Ensure = 'Absent' }) | Should -Match 'Ensure=Absent'
        (Errs @{ Type = 'WindowsUpdate'; Days = 1 }) | Should -Match 'unknown field'
    }

    It '365 gün: 6 değer UTC biçiminde yazılır, Test sağlanır, geri alma birebir (anahtar zinciri dahil)' {
        $ctx = New-Ctx
        $before = Get-State $ctx
        $a = Act @{ Type = 'UpdatePause'; Days = 365 }
        $a.Test($ctx) | Should -BeFalse
        $snap = RoundTrip ($a.Snapshot($ctx))
        $a.Apply($ctx)
        $a.Test($ctx) | Should -BeTrue
        $ctx.Registry.GetValue($script:UX, 'PauseUpdatesStartTime') | Should -Be '2026-11-24T10:30:00Z'
        $ctx.Registry.GetValue($script:UX, 'PauseUpdatesExpiryTime') | Should -Be '2027-11-24T10:30:00Z'
        $ctx.Registry.GetValue($script:UX, 'PauseQualityUpdatesEndTime') | Should -Be '2027-11-24T10:30:00Z'
        $ctx.Registry.GetValueKind($script:UX, 'PauseFeatureUpdatesStartTime') | Should -Be 'String'
        $a.Preview($ctx) | Should -Match 'expires 2027-11-24'
        $a.Revert($ctx, $snap)
        Get-State $ctx | Should -Be $before
    }

    It 'kısa kalan duraklatma Test''i geçmez; önceki değerler geri gelir' {
        $ctx = New-Ctx
        $ctx.Registry.Seed($script:UX, 'PauseUpdatesExpiryTime', '2026-12-01T00:00:00Z', 'String')
        $before = Get-State $ctx
        $a = Act @{ Type = 'UpdatePause'; Days = 365 }
        $a.Test($ctx) | Should -BeFalse
        $snap = RoundTrip ($a.Snapshot($ctx))
        $a.Apply($ctx)
        $a.Revert($ctx, $snap)
        Get-State $ctx | Should -Be $before
    }

    It 'Ensure=Absent duraklatmayı kaldırır' {
        $ctx = New-Ctx
        (Act @{ Type = 'UpdatePause'; Days = 30 }).Apply($ctx)
        $a = Act @{ Type = 'UpdatePause'; Ensure = 'Absent' }
        $a.Test($ctx) | Should -BeFalse
        $a.Apply($ctx)
        $a.Test($ctx) | Should -BeTrue
        $ctx.Registry.ValueExists($script:UX, 'PauseUpdatesExpiryTime') | Should -BeFalse
    }
}

Describe 'WindowsUpdate eylemi ve setup.updates-staged' {
    It 'bekleyenler kurulur, sonra 365 gün duraklatılır; ikinci çalıştırma ZATEN UYGUN; -Undo yalnız duraklatmayı kaldırır' {
        $ctx = New-Ctx
        $ctx.Updates.Seed([string[]]@('KB1', 'KB2'))
        $ctx.Prompt.Enqueue([string[]]@('Y', 'Y'))   # AlwaysConfirm: her çalıştırmada sorulur
        $before = Get-State $ctx
        $p = [Profile]::FromHashtable(@{ name = 'g'; tweaks = @('setup.updates-staged') }, 'test')
        $dry = Invoke-FaiEngine -Profile $p -Context (New-Ctx -DryRun) -Catalog $script:Catalog
        $dry.Find('setup.updates-staged').Status | Should -Be 'Planned'

        $r = Invoke-FaiEngine -Profile $p -Context $ctx -Catalog $script:Catalog
        $r.Find('setup.updates-staged').Status | Should -Be 'Applied' -Because ($r.Render())
        @($ctx.Updates.GetPending()).Count | Should -Be 0
        $ctx.Updates.Installed | Should -Be @('KB1', 'KB2')
        $ctx.Registry.GetValue($script:UX, 'PauseUpdatesExpiryTime') | Should -Be '2027-11-24T10:30:00Z'

        (Invoke-FaiEngine -Profile $p -Context $ctx -Catalog $script:Catalog).Find('setup.updates-staged').Status | Should -Be 'UpToDate'
        $u = Invoke-FaiEngine -Undo -Context $ctx -Catalog $script:Catalog
        $u.HasFailures() | Should -BeFalse -Because ($u.Render())
        Get-State $ctx | Should -Be $before
        $ctx.Updates.Installed.Count | Should -Be 2 -Because 'kurulan güncellemeler geri alınmaz'
    }

    It 'yeniden başlatma gerekirse duraklatma uygulanmaz; ResumeCommand doluysa RunOnce yazılır' {
        $ctx = New-Ctx
        $ctx.Updates.Seed([string[]]@('KB1'))
        $ctx.Prompt.Enqueue([string[]]@('Y', 'Y'))   # AlwaysConfirm: her çalıştırmada sorulur
        $ctx.Updates.RebootAfterInstall = $true
        $ctx.ResumeCommand = 'powershell.exe -File C:\FAI\install.ps1 -Profile fedai'
        $p = [Profile]::FromHashtable(@{ name = 'g'; tweaks = @('setup.updates-staged') }, 'test')
        $r = Invoke-FaiEngine -Profile $p -Context $ctx -Catalog $script:Catalog
        $item = $r.Find('setup.updates-staged')
        $item.Status | Should -Be 'Failed'
        $item.Reason | Should -Match 'a restart is required'
        $item.Reason | Should -Match 'RunOnce'
        $ctx.Registry.ValueExists($script:UX, 'PauseUpdatesExpiryTime') | Should -BeFalse
        $ctx.Registry.GetValue('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce', 'FAI_WinOP') | Should -Be $ctx.ResumeCommand

        # Yeniden başlatma sonrası: bekleyen yok, yeniden başlatma bitti → duraklatma uygulanır.
        $ctx.Updates.RebootPending = $false
        $again = Invoke-FaiEngine -Profile $p -Context $ctx -Catalog $script:Catalog
        $again.Find('setup.updates-staged').Status | Should -Be 'Applied' -Because ($again.Render())
        $ctx.Registry.ValueExists($script:UX, 'PauseUpdatesExpiryTime') | Should -BeTrue
    }

    It 'ResumeCommand boşsa RunOnce yazılmaz, ileti elle tekrar çalıştırmayı söyler' {
        $ctx = New-Ctx
        $ctx.Updates.RebootPending = $true
        $a = Act @{ Type = 'WindowsUpdate' }
        $a.Test($ctx) | Should -BeFalse
        $a.Preview($ctx) | Should -Match 'restart pending'
        { $a.Apply($ctx) } | Should -Throw '*run the profile again*'
        $ctx.Registry.ValueExists('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce', 'FAI_WinOP') | Should -BeFalse
    }

    It 'kurulamayan güncelleme hata verir; önizleme ilk başlıkları gösterir' {
        $ctx = New-Ctx
        $ctx.Updates.Seed([string[]]@('A', 'B', 'C', 'D'))
        $ctx.Updates.FailTitles = @('D')
        $a = Act @{ Type = 'WindowsUpdate' }
        $a.Preview($ctx) | Should -Match '4 pending: A; B; C; …'
        { $a.Apply($ctx) } | Should -Throw '*1 updates failed to install*'
    }
}

Describe '-UpdatesOn / -UpdatesOff (Invoke-FaiUpdatesSwitch)' {
    It 'Off duraklatır, On kaldırır; her biri -Undo ile geri alınır' {
        $ctx = New-Ctx
        $before = Get-State $ctx
        $off = Invoke-FaiUpdatesSwitch -Context $ctx -Off -Days 30
        $off.Find('updates.off').Status | Should -Be 'Applied' -Because ($off.Render())
        $ctx.Registry.GetValue($script:UX, 'PauseUpdatesExpiryTime') | Should -Be '2026-12-24T10:30:00Z'
        (Invoke-FaiUpdatesSwitch -Context $ctx -Off -Days 30).Find('updates.off').Status | Should -Be 'UpToDate'

        $on = Invoke-FaiUpdatesSwitch -Context $ctx -On
        $on.Find('updates.on').Status | Should -Be 'Applied'
        $ctx.Registry.ValueExists($script:UX, 'PauseUpdatesExpiryTime') | Should -BeFalse

        (Invoke-FaiEngine -Undo -Context $ctx -Catalog @{}).HasFailures() | Should -BeFalse
        $ctx.Registry.GetValue($script:UX, 'PauseUpdatesExpiryTime') | Should -Be '2026-12-24T10:30:00Z'
        (Invoke-FaiEngine -Undo -Context $ctx -Catalog @{}).HasFailures() | Should -BeFalse
        Get-State $ctx | Should -Be $before
    }

    It 'dry-run hiçbir şey yazmaz' {
        $ctx = New-Ctx -DryRun
        (Invoke-FaiUpdatesSwitch -Context $ctx -Off).Find('updates.off').Status | Should -Be 'Planned'
        Get-FakeWriteCount $ctx | Should -Be 0
    }
}

Describe 'Benzeşim maskesi (Get-FaiAffinityMask)' {
    It '<Logical>/<Cores> SmtOff=<Smt> ExcludeCore0=<Ex> → <Mask>' -TestCases @(
        @{ Logical = 16; Cores = 8; Smt = $false; Ex = $false; Mask = 0xFFFF }
        @{ Logical = 16; Cores = 8; Smt = $true; Ex = $false; Mask = 0x5555 }
        @{ Logical = 16; Cores = 8; Smt = $false; Ex = $true; Mask = 0xFFFC }
        @{ Logical = 16; Cores = 8; Smt = $true; Ex = $true; Mask = 0x5554 }
        @{ Logical = 8; Cores = 8; Smt = $false; Ex = $false; Mask = 0xFF }
        @{ Logical = 8; Cores = 8; Smt = $true; Ex = $false; Mask = 0xFF }
        @{ Logical = 8; Cores = 8; Smt = $false; Ex = $true; Mask = 0xFE }
        @{ Logical = 8; Cores = 8; Smt = $true; Ex = $true; Mask = 0xFE }
        @{ Logical = 20; Cores = 14; Smt = $false; Ex = $false; Mask = 0xFFFFF }
        @{ Logical = 20; Cores = 14; Smt = $true; Ex = $false; Mask = 0xFF555 }
        @{ Logical = 20; Cores = 14; Smt = $false; Ex = $true; Mask = 0xFFFFC }
        @{ Logical = 20; Cores = 14; Smt = $true; Ex = $true; Mask = 0xFF554 }
        @{ Logical = 12; Cores = 6; Smt = $false; Ex = $false; Mask = 0xFFF }
        @{ Logical = 12; Cores = 6; Smt = $true; Ex = $false; Mask = 0x555 }
        @{ Logical = 12; Cores = 6; Smt = $false; Ex = $true; Mask = 0xFFC }
        @{ Logical = 12; Cores = 6; Smt = $true; Ex = $true; Mask = 0x554 }
    ) {
        Get-FaiAffinityMask -Logical $Logical -Cores $Cores -SmtOff:$Smt -ExcludeCore0:$Ex | Should -Be ([long]$Mask)
    }

    It '64 mantıksal işlemci: en üst bit dahil; 64 üstü ve boş maske hata' {
        Get-FaiAffinityMask -Logical 64 -Cores 64 | Should -Be ([long]-1)
        { Get-FaiAffinityMask -Logical 128 -Cores 64 } | Should -Throw '*64*'
        { Get-FaiAffinityMask -Logical 1 -Cores 1 -ExcludeCore0 } | Should -Throw '*empty*'
        { Get-FaiAffinityMask -Logical 2 -Cores 2 -SmtOff -ExcludeCore0 } | Should -Not -Throw
        { Get-FaiAffinityMask -Logical 2 -Cores 1 -SmtOff -ExcludeCore0 } | Should -Throw '*empty*'
        { Get-FaiAffinityMask -Logical 24 -Cores 8 } | Should -Throw '*ratio*'
    }
}

Describe 'Profil games şeması' {
    It 'geçerli liste kabul edilir' {
        @(Get-FaiProfileError -Data @{ name = 'x'; tweaks = @(); games = @(@{ exe = 'cs2.exe'; priority = 'High'; smtOff = $true }, @{ exe = 'Game X.EXE'; excludeCore0 = $true }) }) |
            Should -BeNullOrEmpty
    }

    It 'hatalar: yol, bilinmeyen alan, öncelik, bool, ayarsız, yinelenen' {
        $errs = @(Get-FaiProfileError -Data @{ name = 'x'; tweaks = @(); games = @(
                    @{ exe = 'C:\Games\a.exe'; priority = 'High' }
                    @{ exe = 'b.exe'; priority = 'RealTime'; affinity = 3 }
                    @{ exe = 'c.exe'; smtOff = 'evet' }
                    @{ exe = 'd.exe' }
                    @{ exe = 'E.exe'; priority = 'Idle' }
                    @{ exe = 'e.exe'; priority = 'Idle' }
                    'f.exe'
                ) })
        $text = $errs -join "`n"
        $text | Should -Match 'games\[0\]\.exe: must be a file name only'
        $text | Should -Match 'games\[1\]\.affinity: unknown field'
        $text | Should -Match 'games\[1\]\.priority:'
        $text | Should -Match 'games\[2\]\.smtOff: must be true or false'
        $text | Should -Match 'games\[3\]: at least one setting'
        $text | Should -Match 'games\[5\]\.exe: .* more than once'
        $text | Should -Match 'games\[6\]: must be an \{ exe'
        @(Get-FaiProfileError -Data @{ name = 'x'; tweaks = @(); games = 'a.exe' }) | Should -Match 'games: must be an array'
    }
}

Describe 'gaming.per-game (motor + GameAffinity)' {
    It 'GameAffinity şeması' {
        Errs @{ Type = 'GameAffinity'; Games = @(@{ Exe = 'a.exe'; Mask = 3 }); TaskPath = '\FAI_WinOP\GameAffinity'; ScriptPath = '%ProgramData%\FAI_WinOP\GameAffinity.ps1' } | Should -BeNullOrEmpty
        $e = Errs @{ Type = 'GameAffinity'; Games = @(@{ Exe = 'C:\a.exe'; Mask = 0 }); TaskPath = 'x'; ScriptPath = 'rel.ps1' }
        ($e -join "`n") | Should -Match 'Exe: must be a file name only'
        ($e -join "`n") | Should -Match 'Mask: must be a non-zero integer'
        ($e -join "`n") | Should -Match 'TaskPath'
        ($e -join "`n") | Should -Match 'ScriptPath'
    }

    It 'üretilen tweak: öncelik IFEO, maske gereken oyunlar tek GameAffinity eyleminde; maske yoksa eylem yok' {
        $t = ConvertTo-FaiGamesTweak -Games @(@{ exe = 'cs2.exe'; priority = 'High'; smtOff = $true; excludeCore0 = $true }, @{ exe = 'b.exe'; priority = 'AboveNormal' }) -Logical 16 -Cores 8
        $t.Id | Should -Be 'gaming.per-game'
        $t.Actions.Count | Should -Be 3
        $t.Actions[0].Definition['Path'] | Should -Be "$script:Ifeo\cs2.exe\PerfOptions"
        $t.Actions[0].Definition['Value'] | Should -Be 3
        $t.Actions[1].Definition['Value'] | Should -Be 6
        $t.Actions[2].Definition['Type'] | Should -Be 'GameAffinity'
        @($t.Actions[2].Definition['Games'])[0]['Mask'] | Should -Be ([long]0x5554)
        $t.Actions[2].Describe() | Should -Match 'cs2\.exe = 0x5554'
        (ConvertTo-FaiGamesTweak -Games @(@{ exe = 'b.exe'; priority = 'Idle' }) -Logical 8 -Cores 8).Actions.Count | Should -Be 1
    }

    It 'betik: maskeler gömülü, WQL yalnız listedeki exe''ler, CRLF' {
        $s = Get-FaiGameAffinityScript -Games @(@{ Exe = 'CS2.exe'; Mask = 21844 }, @{ Exe = 'b.exe'; Mask = 3 })
        $s | Should -Match "'cs2\.exe' = \[long\]21844"
        $s | Should -Match "WHERE ProcessName='cs2\.exe' OR ProcessName='b\.exe'"
        $s | Should -Match 'Win32_ProcessStartTrace'
        $s | Should -Match "`r`n"
        { [scriptblock]::Create($s) } | Should -Not -Throw
    }

    It 'profil games: dry-run sıfır yazma → uygula → ZATEN UYGUN → -Undo birebir; görev süresiz' {
        $games = @(@{ exe = 'cs2.exe'; priority = 'High'; smtOff = $true }, @{ exe = 'valorant.exe'; excludeCore0 = $true })
        $p = New-GameProfile $games
        $dctx = New-Ctx -DryRun
        $dry = Invoke-FaiEngine -Profile $p -Context $dctx -Catalog $script:Catalog
        $dry.Find('gaming.per-game').Status | Should -Be 'Planned'
        @($dry.Find('gaming.per-game').Lines).Count | Should -Be 2
        Get-FakeWriteCount $dctx | Should -Be 0

        $ctx = New-Ctx
        $ctx.SystemInfo.LogicalProcessors = 12
        $ctx.SystemInfo.Cores = 6
        $before = Get-State $ctx
        $r = Invoke-FaiEngine -Profile $p -Context $ctx -Catalog $script:Catalog
        $r.Find('gaming.per-game').Status | Should -Be 'Applied' -Because ($r.Render())
        $ctx.Registry.GetValue("$script:Ifeo\cs2.exe\PerfOptions", 'CpuPriorityClass') | Should -Be 3
        $cmd = $ctx.Tasks.Commands['\fai_winop\gameaffinity']
        $cmd['NoTimeLimit'] | Should -BeTrue
        $cmd['Arguments'] | Should -Match 'GameAffinity\.ps1'
        $script = [System.Text.Encoding]::UTF8.GetString($ctx.Files.ReadBytes((Expand-FaiPath '%ProgramData%\FAI_WinOP\GameAffinity.ps1')))
        $script | Should -Match "'cs2\.exe' = \[long\]1365"
        $script | Should -Match "'valorant\.exe' = \[long\]4092"

        (Invoke-FaiEngine -Profile $p -Context $ctx -Catalog $script:Catalog).Find('gaming.per-game').Status | Should -Be 'UpToDate'
        $u = Invoke-FaiEngine -Undo -Context $ctx -Catalog $script:Catalog
        $u.HasFailures() | Should -BeFalse -Because ($u.Render())
        Get-State $ctx | Should -Be $before
    }

    It 'games tweak''lerden sonra, layout''tan önce işlenir' {
        $p = [Profile]::FromHashtable(@{ name = 'o'; tweaks = @('sound.startup-sound-off'); games = @(@{ exe = 'a.exe'; priority = 'High' }); layout = @{ taskbar = @{ alignment = 'center' } } }, 'test')
        $r = Invoke-FaiEngine -Profile $p -Context (New-Ctx -DryRun) -Catalog $script:Catalog
        $ids = @($r.Items | ForEach-Object { $_.TweakId })
        [array]::IndexOf($ids, 'gaming.per-game') | Should -BeGreaterThan ([array]::IndexOf($ids, 'sound.startup-sound-off'))
        [array]::IndexOf($ids, 'gaming.per-game') | Should -BeLessThan ([array]::IndexOf($ids, 'layout.profile'))
    }

    It 'işlemci bilgisi uygun değilse (ör. 128 mantıksal) gaming.per-game Failed, diğerleri sürer' {
        $ctx = New-Ctx
        $ctx.SystemInfo.LogicalProcessors = 128
        $ctx.SystemInfo.Cores = 64
        $p = New-GameProfile @(@{ exe = 'a.exe'; smtOff = $true }) @('sound.startup-sound-off')
        $r = Invoke-FaiEngine -Profile $p -Context $ctx -Catalog $script:Catalog
        $r.Find('gaming.per-game').Status | Should -Be 'Failed'
        $r.Find('sound.startup-sound-off').Status | Should -Be 'Applied'
    }
}
