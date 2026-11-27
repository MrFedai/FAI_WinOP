#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }
# Faz 1 kabul kriterleri (docs/ROADMAP.md): koşul atlama · Caution onay red / kabul · Risk'in -Unattended'da asla uygulanmaması ·
# snapshot → undo başlangıç durumunu birebir geri getirmesi · dry-run'da sıfır yazma. Hepsi Fake sağlayıcılara karşı.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Load-Fakes.ps1')

    $script:Key = 'HKCU:\Software\FAI_WinOP_Test\Unit'
    $script:Seq = 0

    # Yeni bağlam: Fake sağlayıcılar + TestDrive altında ayrı yedek kökü.
    function New-Env {
        param([string[]] $Answers = @(), [switch] $DryRun, [switch] $Unattended)
        $script:Seq++
        $root = Join-Path $TestDrive ("backup{0}" -f $script:Seq)
        return (New-FakeContext -BackupRoot $root -Answers $Answers -DryRun:$DryRun -Unattended:$Unattended)
    }

    # Aynı sağlayıcıları ve yedek kökünü paylaşan ikinci bağlam (örn. dry-run ya da undo için; yeni BackupStore = diskten okur).
    function Copy-Env([ExecutionContext] $From, [switch] $DryRun, [switch] $Unattended, [string[]] $Answers = @()) {
        $c = [ExecutionContext]::new()
        $c.Registry = $From.Registry
        $c.Services = $From.Services
        $c.Tasks = $From.Tasks
        $c.Appx = $From.Appx
        $c.Packages = $From.Packages
        $c.SystemInfo = $From.SystemInfo
        $p = [FakePromptProvider]::new()
        if ($Answers.Count -gt 0) { $p.Enqueue($Answers) }
        $c.Prompt = $p
        $c.Backup = [BackupStore]::new($From.Backup.Root)
        $c.DryRun = $DryRun.IsPresent
        $c.Unattended = $Unattended.IsPresent
        return $c
    }

    function New-Tweak {
        param([string] $Id, [string] $Risk = 'Safe', [object[]] $Conditions = @(), [object[]] $Actions, [string] $Warning = '', [hashtable] $Params = @{})
        $d = @{ Id = $Id; Title = "Tweak $Id"; Description = 'test'; Category = 'test'; Risk = $Risk; Actions = $Actions }
        if ($Conditions.Count -gt 0) { $d['Conditions'] = $Conditions }
        if ($Warning) { $d['Confirm'] = $Warning }
        if ($Params.Count -gt 0) { $d['Params'] = $Params }
        return [Tweak]::FromHashtable($d, 'test')
    }

    function New-Profile([string[]] $Ids, [string[]] $AutoConfirm = @()) {
        $d = @{ name = 'unit'; tweaks = @($Ids) }
        if ($AutoConfirm.Count -gt 0) { $d['autoConfirm'] = @($AutoConfirm) }
        return [Profile]::FromHashtable($d, 'test')
    }

    function New-Catalog([Tweak[]] $Tweaks) {
        $c = @{}
        foreach ($t in $Tweaks) { $c[$t.Id] = $t }
        return $c
    }

    function RegSet([string] $Name, $Value, [string] $Kind = 'DWord') {
        return @{ Type = 'Registry'; Path = $script:Key; Name = $Name; Value = $Value; Kind = $Kind }
    }

    # Bütün Fake durumunun (kayıt defteri + servisler) tek metinlik dökümü.
    function Get-State([ExecutionContext] $Ctx) {
        return ((@($Ctx.Registry.Dump()) + @($Ctx.Services.Dump())) -join "`n")
    }
}

Describe 'Koşul atlama' {
    It 'koşul sağlanmıyorsa tweak atlanır ve hiçbir şey yazılmaz' {
        $ctx = New-Env   # Fake sistemde NVIDIA yok
        $t = New-Tweak -Id 'test.nv' -Conditions @('HasNvidia') -Actions @(RegSet 'Nv' 1)
        $r = Invoke-FaiEngine -Profile (New-Profile @('test.nv')) -Context $ctx -Catalog (New-Catalog $t)

        $r.Find('test.nv').Status | Should -Be 'Skipped'
        $r.Find('test.nv').Reason | Should -Match 'Condition not met: HasNvidia'
        Get-FakeWriteCount $ctx | Should -Be 0
        $ctx.Registry.ValueExists($script:Key, 'Nv') | Should -BeFalse
        $ctx.Backup.SessionsOpened | Should -Be 0
    }

    It 'koşul sağlanıyorsa tweak uygulanır' {
        $ctx = New-Env
        $ctx.SystemInfo.Nvidia = $true
        $t = New-Tweak -Id 'test.nv' -Conditions @('HasNvidia') -Actions @(RegSet 'Nv' 1)
        $r = Invoke-FaiEngine -Profile (New-Profile @('test.nv')) -Context $ctx -Catalog (New-Catalog $t)

        $r.Find('test.nv').Status | Should -Be 'Applied'
        $ctx.Registry.GetValue($script:Key, 'Nv') | Should -Be 1
    }

    It 'birden çok koşuldan biri sağlanmıyorsa atlanır, sebep o koşulu söyler' {
        $ctx = New-Env
        $ctx.SystemInfo.Laptop = $true
        $ctx.SystemInfo.Build = 19045
        $t = New-Tweak -Id 'test.multi' -Conditions @('IsLaptop', @{ MinBuild = 22000 }) -Actions @(RegSet 'M' 1)
        $r = Invoke-FaiEngine -Profile (New-Profile @('test.multi')) -Context $ctx -Catalog (New-Catalog $t)

        $r.Find('test.multi').Status | Should -Be 'Skipped'
        $r.Find('test.multi').Reason | Should -Match 'MinBuild 22000'
        Get-FakeWriteCount $ctx | Should -Be 0
    }

    It 'Not / Edition / MinRamGB koşulları değerlendirilir' {
        $sys = [FakeSystemInfoProvider]::new()
        $sys.Edition = 'Pro'
        $sys.RamGB = 32
        $sys.Laptop = $false
        [Condition]::Parse(@{ Not = 'IsLaptop' }).Test($sys) | Should -BeTrue
        [Condition]::Parse(@{ Edition = @('Core', 'pro') }).Test($sys) | Should -BeTrue -Because 'sürüm adı büyük/küçük harf duyarsız'
        [Condition]::Parse(@{ Edition = 'Core' }).Test($sys) | Should -BeFalse
        [Condition]::Parse(@{ MinRamGB = 16 }).Test($sys) | Should -BeTrue
        [Condition]::Parse(@{ MinRamGB = 64 }).Test($sys) | Should -BeFalse
    }
}

Describe 'Caution onayı' {
    It 'kullanıcı reddederse (H) tweak uygulanmaz, hiçbir şey yazılmaz, oturum açılmaz' {
        $ctx = New-Env -Answers 'H'
        $t = New-Tweak -Id 'test.caut' -Risk 'Caution' -Warning 'Pil ve ısı artar.' -Actions @(RegSet 'C' 1)
        $r = Invoke-FaiEngine -Profile (New-Profile @('test.caut')) -Context $ctx -Catalog (New-Catalog $t)

        $r.Find('test.caut').Status | Should -Be 'Skipped'
        $r.Find('test.caut').Reason | Should -Match 'declined'
        $ctx.Prompt.Asked.Count | Should -Be 1
        Get-FakeWriteCount $ctx | Should -Be 0
        $ctx.Backup.SessionsOpened | Should -Be 0
    }

    It 'kullanıcı kabul ederse (E) tweak uygulanır' {
        $ctx = New-Env -Answers 'Y'
        $t = New-Tweak -Id 'test.caut' -Risk 'Caution' -Actions @(RegSet 'C' 1)
        $r = Invoke-FaiEngine -Profile (New-Profile @('test.caut')) -Context $ctx -Catalog (New-Catalog $t)

        $r.Find('test.caut').Status | Should -Be 'Applied'
        $ctx.Prompt.Asked.Count | Should -Be 1
        $ctx.Prompt.Asked[0]['Kind'] | Should -Be 'Confirm'
        $ctx.Registry.GetValue($script:Key, 'C') | Should -Be 1
    }

    It 'soru metni tweak başlığını ve Confirm uyarısını içerir' {
        $ctx = New-Env -Answers 'H'
        $t = New-Tweak -Id 'test.caut' -Risk 'Caution' -Warning 'dizüstünde pil ve ısı artar' -Actions @(RegSet 'C' 1)
        [void](Invoke-FaiEngine -Profile (New-Profile @('test.caut')) -Context $ctx -Catalog (New-Catalog $t))
        $ctx.Prompt.Asked[0]['Message'] | Should -Match 'Tweak test\.caut'
        $ctx.Prompt.Asked[0]['Message'] | Should -Match 'dizüstünde pil ve ısı artar'
    }

    It 'her tweak için ayrı sorulur: biri reddedilir, öteki kabul edilir' {
        $ctx = New-Env -Answers 'N', 'Y'
        $a = New-Tweak -Id 'test.a' -Risk 'Caution' -Actions @(RegSet 'A' 1)
        $b = New-Tweak -Id 'test.b' -Risk 'Caution' -Actions @(RegSet 'B' 1)
        $r = Invoke-FaiEngine -Profile (New-Profile @('test.a', 'test.b')) -Context $ctx -Catalog (New-Catalog $a, $b)
        $r.Find('test.a').Status | Should -Be 'Skipped'
        $r.Find('test.b').Status | Should -Be 'Applied'
    }
}

Describe 'Risk ve -Unattended' {
    It 'Risk -Unattended modda ASLA uygulanmaz ve soru da sorulmaz' {
        $ctx = New-Env -Unattended -Answers 'YES'
        $t = New-Tweak -Id 'test.risk' -Risk 'Risk' -Actions @(RegSet 'R' 1)
        $r = Invoke-FaiEngine -Profile (New-Profile @('test.risk')) -Context $ctx -Catalog (New-Catalog $t)

        $r.Find('test.risk').Status | Should -Be 'Skipped'
        $r.Find('test.risk').Reason | Should -Match 'Unattended mode: Risk is never'
        $ctx.Prompt.Asked.Count | Should -Be 0
        Get-FakeWriteCount $ctx | Should -Be 0
        $ctx.Backup.SessionsOpened | Should -Be 0
    }

    It 'Risk -Unattended modda profilde autoConfirm olsa bile uygulanmaz' {
        $ctx = New-Env -Unattended
        $t = New-Tweak -Id 'test.risk' -Risk 'Risk' -Actions @(RegSet 'R' 1)
        $r = Invoke-FaiEngine -Profile (New-Profile @('test.risk') @('test.risk')) -Context $ctx -Catalog (New-Catalog $t)

        $r.Find('test.risk').Status | Should -Be 'Skipped'
        Get-FakeWriteCount $ctx | Should -Be 0
    }

    It 'Caution -Unattended modda profilde autoConfirm yoksa atlanır (soru sorulmaz)' {
        $ctx = New-Env -Unattended -Answers 'Y'
        $t = New-Tweak -Id 'test.caut' -Risk 'Caution' -Actions @(RegSet 'C' 1)
        $r = Invoke-FaiEngine -Profile (New-Profile @('test.caut')) -Context $ctx -Catalog (New-Catalog $t)

        $r.Find('test.caut').Status | Should -Be 'Skipped'
        $r.Find('test.caut').Reason | Should -Match 'needs autoConfirm'
        $ctx.Prompt.Asked.Count | Should -Be 0
        Get-FakeWriteCount $ctx | Should -Be 0
    }

    It 'Caution -Unattended modda profilde autoConfirm varsa uygulanır (soru sorulmaz)' {
        $ctx = New-Env -Unattended
        $t = New-Tweak -Id 'test.caut' -Risk 'Caution' -Actions @(RegSet 'C' 1)
        $r = Invoke-FaiEngine -Profile (New-Profile @('test.caut') @('test.caut')) -Context $ctx -Catalog (New-Catalog $t)

        $r.Find('test.caut').Status | Should -Be 'Applied'
        $ctx.Prompt.Asked.Count | Should -Be 0
        $ctx.Registry.GetValue($script:Key, 'C') | Should -Be 1
    }

    It 'Safe -Unattended modda doğrudan uygulanır' {
        $ctx = New-Env -Unattended
        $t = New-Tweak -Id 'test.safe' -Actions @(RegSet 'S' 1)
        $r = Invoke-FaiEngine -Profile (New-Profile @('test.safe')) -Context $ctx -Catalog (New-Catalog $t)
        $r.Find('test.safe').Status | Should -Be 'Applied'
        $ctx.Prompt.Asked.Count | Should -Be 0
    }

    It 'Risk etkileşimli modda yalnız tam "YES" yazılırsa uygulanır' {
        $ctx = New-Env -Answers 'YES'
        $t = New-Tweak -Id 'test.risk' -Risk 'Risk' -Actions @(RegSet 'R' 1)
        $r = Invoke-FaiEngine -Profile (New-Profile @('test.risk')) -Context $ctx -Catalog (New-Catalog $t)
        $r.Find('test.risk').Status | Should -Be 'Applied'
        $ctx.Prompt.Asked[0]['Kind'] | Should -Be 'ConfirmExact'
    }

    It 'Risk: "Y", "yes" ya da boş yanıt yetmez' {
        foreach ($answer in 'Y', 'yes', 'Yes', 'EVET', '') {
            $ctx = New-Env -Answers $answer
            $t = New-Tweak -Id 'test.risk' -Risk 'Risk' -Actions @(RegSet 'R' 1)
            $r = Invoke-FaiEngine -Profile (New-Profile @('test.risk')) -Context $ctx -Catalog (New-Catalog $t)
            $r.Find('test.risk').Status | Should -Be 'Skipped' -Because "'$answer' yanıtı onay sayılmamalı"
            Get-FakeWriteCount $ctx | Should -Be 0
        }
    }
}

Describe 'Snapshot → Undo' {
    BeforeAll {
        # Başlangıç: bir değer var (Existing=1), bir değer silinecek (Obsolete), servis çalışıyor; New* değerleri yok.
        function New-SeededEnv {
            $ctx = New-Env
            $ctx.Registry.Seed($script:Key, 'Existing', 1, 'DWord')
            $ctx.Registry.Seed($script:Key, 'Obsolete', 'eski', 'String')
            $ctx.Registry.Seed($script:Key, 'Untouched', 7, 'DWord')
            $ctx.Registry.Seed('HKCU:\Software\FAI_WinOP_Test\Other', 'Blob', @(9, 8), 'Binary')
            $ctx.Services.Seed('FaiSvc', 'Automatic', 'Running')
            return $ctx
        }
        function New-BigTweak {
            return (New-Tweak -Id 'test.big' -Actions @(
                    (RegSet 'Existing' 2)
                    (RegSet 'NewString' 'Açılış' 'String')
                    (RegSet 'NewQWord' 4294967296 'QWord')
                    (RegSet 'NewMulti' @('a', 'b') 'MultiString')
                    (RegSet 'NewBinary' @(1, 2, 255) 'Binary')
                    (RegSet 'NewExpand' '%USERPROFILE%\x' 'ExpandString')
                    @{ Type = 'Registry'; Path = $script:Key; Name = 'Obsolete'; Ensure = 'Absent' }
                    @{ Type = 'Service'; Name = 'FaiSvc'; StartType = 'Disabled'; State = 'Stopped' }
                ))
        }
    }

    It 'uygulama durumu değiştirir; Undo başlangıç durumunu birebir geri getirir' {
        $ctx = New-SeededEnv
        $before = Get-State $ctx
        $cat = New-Catalog (New-BigTweak)

        $r = Invoke-FaiEngine -Profile (New-Profile @('test.big')) -Context $ctx -Catalog $cat
        $r.Find('test.big').Status | Should -Be 'Applied'
        Get-State $ctx | Should -Not -Be $before
        $ctx.Registry.GetValue($script:Key, 'Existing') | Should -Be 2
        $ctx.Registry.ValueExists($script:Key, 'Obsolete') | Should -BeFalse
        $ctx.Services.GetStatus('FaiSvc') | Should -Be 'Stopped'

        # Undo: yeni BackupStore (diskten okur), aynı sağlayıcılar
        $undoCtx = Copy-Env $ctx
        $u = Invoke-FaiEngine -Context $undoCtx -Catalog $cat -Undo
        $u.Count('Reverted') | Should -Be 8
        $u.HasFailures() | Should -BeFalse
        Get-State $undoCtx | Should -Be $before
    }

    It 'önceden olmayan değer Undo''da silinir (her tür için)' {
        $ctx = New-SeededEnv
        $cat = New-Catalog (New-BigTweak)
        [void](Invoke-FaiEngine -Profile (New-Profile @('test.big')) -Context $ctx -Catalog $cat)
        foreach ($n in 'NewString', 'NewQWord', 'NewMulti', 'NewBinary', 'NewExpand') {
            $ctx.Registry.ValueExists($script:Key, $n) | Should -BeTrue -Because "$n uygulamadan sonra var olmalı"
        }
        [void](Invoke-FaiEngine -Context (Copy-Env $ctx) -Catalog $cat -Undo)
        foreach ($n in 'NewString', 'NewQWord', 'NewMulti', 'NewBinary', 'NewExpand') {
            $ctx.Registry.ValueExists($script:Key, $n) | Should -BeFalse -Because "$n önceden yoktu, Undo silmeli"
        }
    }

    It 'silinen değer Undo''da türü ve içeriğiyle geri gelir' {
        $ctx = New-SeededEnv
        $cat = New-Catalog (New-BigTweak)
        [void](Invoke-FaiEngine -Profile (New-Profile @('test.big')) -Context $ctx -Catalog $cat)
        $ctx.Registry.ValueExists($script:Key, 'Obsolete') | Should -BeFalse
        [void](Invoke-FaiEngine -Context (Copy-Env $ctx) -Catalog $cat -Undo)
        $ctx.Registry.GetValue($script:Key, 'Obsolete') | Should -Be 'eski'
        $ctx.Registry.GetValueKind($script:Key, 'Obsolete') | Should -Be 'String'
    }

    It 'dokunulmayan değerler uygulamadan ve Undo''dan etkilenmez' {
        $ctx = New-SeededEnv
        $cat = New-Catalog (New-BigTweak)
        [void](Invoke-FaiEngine -Profile (New-Profile @('test.big')) -Context $ctx -Catalog $cat)
        $ctx.Registry.GetValue($script:Key, 'Untouched') | Should -Be 7
        [void](Invoke-FaiEngine -Context (Copy-Env $ctx) -Catalog $cat -Undo)
        $ctx.Registry.GetValue($script:Key, 'Untouched') | Should -Be 7
        $ctx.Registry.GetValue('HKCU:\Software\FAI_WinOP_Test\Other', 'Blob').Count | Should -Be 2
    }

    It 'aynı değeri değiştiren ardışık eylemler TERS sırada geri alınır' {
        $ctx = New-SeededEnv
        $t = New-Tweak -Id 'test.chain' -Actions @((RegSet 'Existing' 10), (RegSet 'Existing' 20), (RegSet 'Existing' 30))
        $cat = New-Catalog $t
        [void](Invoke-FaiEngine -Profile (New-Profile @('test.chain')) -Context $ctx -Catalog $cat)
        $ctx.Registry.GetValue($script:Key, 'Existing') | Should -Be 30

        $ctx.Registry.WriteLog.Clear()
        [void](Invoke-FaiEngine -Context (Copy-Env $ctx) -Catalog $cat -Undo)
        $ctx.Registry.GetValue($script:Key, 'Existing') | Should -Be 1 -Because '10 ve 20 ara durumlardan geçip ilk değere dönmeli'
    }

    It 'Undo rapordaki sıra uygulamanın tersidir' {
        $ctx = New-SeededEnv
        $a = New-Tweak -Id 'test.first' -Actions @((RegSet 'Existing' 5))
        $b = New-Tweak -Id 'test.second' -Actions @((RegSet 'NewA' 1), (RegSet 'NewB' 1))
        $cat = New-Catalog $a, $b
        [void](Invoke-FaiEngine -Profile (New-Profile @('test.first', 'test.second')) -Context $ctx -Catalog $cat)
        $u = Invoke-FaiEngine -Context (Copy-Env $ctx) -Catalog $cat -Undo
        ($u.Items | ForEach-Object { '{0}#{1}' -f $_.TweakId, $_.Title }) -join ' | ' |
            Should -Be 'test.second#action 2 | test.second#action 1 | test.first#action 1'
    }

    It 'Undo en son geri alınmamış oturumu alır; ikinci Undo bir önceki oturumu' {
        $ctx = New-SeededEnv
        $initial = Get-State $ctx
        $t1 = New-Tweak -Id 'test.one' -Actions @((RegSet 'Existing' 2))
        $t2 = New-Tweak -Id 'test.two' -Actions @((RegSet 'Existing' 3))
        $cat = New-Catalog $t1, $t2

        [void](Invoke-FaiEngine -Profile (New-Profile @('test.one')) -Context $ctx -Catalog $cat)
        $afterOne = Get-State $ctx
        [void](Invoke-FaiEngine -Profile (New-Profile @('test.two')) -Context $ctx -Catalog $cat)
        $ctx.Backup.ListSessionIds().Count | Should -Be 2

        [void](Invoke-FaiEngine -Context (Copy-Env $ctx) -Catalog $cat -Undo)
        Get-State $ctx | Should -Be $afterOne
        [void](Invoke-FaiEngine -Context (Copy-Env $ctx) -Catalog $cat -Undo)
        Get-State $ctx | Should -Be $initial
    }

    It 'geri alınan oturum işaretlenir; geri alınacak oturum kalmayınca Undo bunu söyler' {
        $ctx = New-SeededEnv
        $cat = New-Catalog (New-BigTweak)
        [void](Invoke-FaiEngine -Profile (New-Profile @('test.big')) -Context $ctx -Catalog $cat)
        $undoCtx = Copy-Env $ctx
        [void](Invoke-FaiEngine -Context $undoCtx -Catalog $cat -Undo)
        $undoCtx.Backup.GetLatest() | Should -BeNullOrEmpty

        $again = Copy-Env $ctx
        $writesBefore = Get-FakeWriteCount $again
        $r = Invoke-FaiEngine -Context $again -Catalog $cat -Undo
        $r.Find('(session)').Title | Should -Match 'No session to undo'
        Get-FakeWriteCount $again | Should -Be $writesBefore
    }

    It 'Undo belirli bir oturum kimliğiyle de çalışır' {
        $ctx = New-SeededEnv
        $t1 = New-Tweak -Id 'test.one' -Actions @((RegSet 'Existing' 2))
        $cat = New-Catalog $t1
        [void](Invoke-FaiEngine -Profile (New-Profile @('test.one')) -Context $ctx -Catalog $cat)
        $id = $ctx.Backup.ListSessionIds()[0]
        [void](Invoke-FaiEngine -Context (Copy-Env $ctx) -Catalog $cat -Undo -Session $id)
        $ctx.Registry.GetValue($script:Key, 'Existing') | Should -Be 1
    }

    It 'yarım kalan (hata veren) tweak da Undo ile geri alınır' {
        $ctx = New-SeededEnv
        $before = Get-State $ctx
        $ctx.Registry.FailOnName = 'Boom'
        $t = New-Tweak -Id 'test.half' -Actions @((RegSet 'Existing' 99), (RegSet 'Boom' 1), (RegSet 'After' 1))
        $cat = New-Catalog $t
        $r = Invoke-FaiEngine -Profile (New-Profile @('test.half')) -Context $ctx -Catalog $cat

        $r.Find('test.half').Status | Should -Be 'Failed'
        $r.Find('test.half').Reason | Should -Match 'Simulated write error'
        $ctx.Registry.GetValue($script:Key, 'Existing') | Should -Be 99
        $ctx.Registry.ValueExists($script:Key, 'After') | Should -BeFalse -Because 'hatadan sonraki eylem çalışmamalı'

        $ctx.Registry.FailOnName = ''
        [void](Invoke-FaiEngine -Context (Copy-Env $ctx) -Catalog $cat -Undo)
        Get-State $ctx | Should -Be $before
    }

    It 'snapshot uygulamadan ÖNCE diske yazılır' {
        $ctx = New-SeededEnv
        $ctx.Registry.FailOnName = 'Existing'
        $t = New-Tweak -Id 'test.early' -Actions @((RegSet 'Existing' 2))
        [void](Invoke-FaiEngine -Profile (New-Profile @('test.early')) -Context $ctx -Catalog (New-Catalog $t))
        $s = $ctx.Backup.Load($ctx.Backup.ListSessionIds()[0])
        $s.Entries.Count | Should -Be 1
        $s.Entries[0]['Snapshot']['Value'] | Should -Be 1
    }

    It 'zaten hedef durumda olan tweak için snapshot / oturum üretilmez (ZATEN UYGUN)' {
        $ctx = New-SeededEnv
        $t = New-Tweak -Id 'test.same' -Risk 'Caution' -Actions @((RegSet 'Existing' 1))
        $r = Invoke-FaiEngine -Profile (New-Profile @('test.same')) -Context $ctx -Catalog (New-Catalog $t)
        $r.Find('test.same').Status | Should -Be 'UpToDate'
        $ctx.Prompt.Asked.Count | Should -Be 0 -Because 'yapılacak iş yoksa soru sorulmaz'
        $ctx.Backup.SessionsOpened | Should -Be 0
        Get-FakeWriteCount $ctx | Should -Be 0
    }

    It 'denetimde uygun olup önceki eylemce bozulan eylem yine uygulanır; Undo başlangıca döner' {
        # Edge kaldırıcısı microsoft-edge sınıfını siler: baştaki denetimde uygun sayılan değer kaybolmamalı.
        $ctx = New-SeededEnv
        $before = Get-State $ctx
        $t = New-Tweak -Id 'test.side' -Actions @(
            @{ Type = 'Registry'; Path = $script:Key; Name = 'Existing'; Ensure = 'Absent' }
            (RegSet 'Existing' 1)
            (RegSet 'Untouched' 7)
        )
        $cat = New-Catalog $t
        $r = Invoke-FaiEngine -Profile (New-Profile @('test.side')) -Context $ctx -Catalog $cat
        $r.Find('test.side').Status | Should -Be 'Applied'
        $r.Find('test.side').Lines.Count | Should -Be 2 -Because 'bozulmayan 3. eylem yeniden uygulanmaz'
        $ctx.Registry.GetValue($script:Key, 'Existing') | Should -Be 1

        [void](Invoke-FaiEngine -Context (Copy-Env $ctx) -Catalog $cat -Undo)
        Get-State $ctx | Should -Be $before
    }
}

Describe 'Dry-run' {
    It 'hiçbir sağlayıcıya yazma çağrısı yapılmaz, durum değişmez' {
        $ctx = New-Env -DryRun
        $ctx.Registry.Seed($script:Key, 'Existing', 1, 'DWord')
        $ctx.Services.Seed('FaiSvc', 'Automatic', 'Running')
        $ctx.Tasks.Seed('\FAI\Task', 'Enabled')
        $ctx.Appx.Seed(@('Some.App'), @('Some.App'))
        $before = Get-State $ctx
        $cat = New-Catalog (New-Tweak -Id 'test.big' -Actions @(
                (RegSet 'Existing' 2), (RegSet 'New' 'x' 'String'),
                @{ Type = 'Service'; Name = 'FaiSvc'; StartType = 'Disabled'; State = 'Stopped' }))

        $r = Invoke-FaiEngine -Profile (New-Profile @('test.big')) -Context $ctx -Catalog $cat

        $r.Find('test.big').Status | Should -Be 'Planned'
        $ctx.Registry.WriteCount | Should -Be 0
        $ctx.Services.WriteCount | Should -Be 0
        $ctx.Tasks.WriteCount | Should -Be 0
        $ctx.Appx.WriteCount | Should -Be 0
        $ctx.Packages.WriteCount | Should -Be 0
        Get-FakeWriteCount $ctx | Should -Be 0
        Get-State $ctx | Should -Be $before
    }

    It 'BackupStore oturumu da açılmaz (oturum sayısı 0, yedek klasörü oluşmaz)' {
        $ctx = New-Env -DryRun
        $cat = New-Catalog (New-Tweak -Id 'test.one' -Actions @((RegSet 'A' 1)))
        [void](Invoke-FaiEngine -Profile (New-Profile @('test.one')) -Context $ctx -Catalog $cat)
        $ctx.Backup.SessionsOpened | Should -Be 0
        Test-Path -LiteralPath $ctx.Backup.Root | Should -BeFalse
        $ctx.Backup.ListSessionIds().Count | Should -Be 0
    }

    It 'rapor her tweak için "şu an → olacak" değişiklik listesi verir' {
        $ctx = New-Env -DryRun
        $ctx.Registry.Seed($script:Key, 'Existing', 1, 'DWord')
        $cat = New-Catalog (New-Tweak -Id 'test.one' -Actions @((RegSet 'Existing' 2), (RegSet 'New' 'x' 'String')))
        $r = Invoke-FaiEngine -Profile (New-Profile @('test.one')) -Context $ctx -Catalog $cat
        $lines = $r.Find('test.one').Lines
        $lines.Count | Should -Be 2
        $lines[0] | Should -Match 'Existing = 2 \(DWord\) \[current: 1\]'
        $lines[1] | Should -Match 'New = x \(String\) \[current: none\]'
        $r.Render() | Should -Match 'PREVIEW'
    }

    It 'Caution / Risk için soru sormaz; sorulacağını rapora yazar' {
        $ctx = New-Env -DryRun -Answers 'Y', 'YES'
        $c = New-Tweak -Id 'test.caut' -Risk 'Caution' -Actions @((RegSet 'C' 1))
        $k = New-Tweak -Id 'test.risk' -Risk 'Risk' -Actions @((RegSet 'R' 1))
        $r = Invoke-FaiEngine -Profile (New-Profile @('test.caut', 'test.risk')) -Context $ctx -Catalog (New-Catalog $c, $k)
        $ctx.Prompt.Asked.Count | Should -Be 0
        $r.Find('test.caut').Status | Should -Be 'Planned'
        $r.Find('test.caut').Reason | Should -Match 'confirm'
        $r.Find('test.risk').Status | Should -Be 'Planned'
        $r.Find('test.risk').Reason | Should -Match 'YES'
        Get-FakeWriteCount $ctx | Should -Be 0
    }

    It 'dry-run + Unattended: Risk ve autoConfirm''siz Caution atlanır olarak önizlenir' {
        $ctx = New-Env -DryRun -Unattended
        $c = New-Tweak -Id 'test.caut' -Risk 'Caution' -Actions @((RegSet 'C' 1))
        $k = New-Tweak -Id 'test.risk' -Risk 'Risk' -Actions @((RegSet 'R' 1))
        $r = Invoke-FaiEngine -Profile (New-Profile @('test.caut', 'test.risk')) -Context $ctx -Catalog (New-Catalog $c, $k)
        $r.Find('test.caut').Status | Should -Be 'Skipped'
        $r.Find('test.risk').Status | Should -Be 'Skipped'
    }

    It 'koşulu sağlanmayan tweak dry-run''da da atlanır olarak görünür' {
        $ctx = New-Env -DryRun
        $t = New-Tweak -Id 'test.nv' -Conditions @('HasNvidia') -Actions @((RegSet 'Nv' 1))
        $r = Invoke-FaiEngine -Profile (New-Profile @('test.nv')) -Context $ctx -Catalog (New-Catalog $t)
        $r.Find('test.nv').Status | Should -Be 'Skipped'
    }

    It 'Undo -DryRun: sıfır yazma, durum aynı, oturum geri alınmış sayılmaz' {
        $ctx = New-Env
        $ctx.Registry.Seed($script:Key, 'Existing', 1, 'DWord')
        $cat = New-Catalog (New-Tweak -Id 'test.one' -Actions @((RegSet 'Existing' 2), (RegSet 'New' 1)))
        [void](Invoke-FaiEngine -Profile (New-Profile @('test.one')) -Context $ctx -Catalog $cat)
        $applied = Get-State $ctx
        $writes = Get-FakeWriteCount $ctx

        $dry = Copy-Env $ctx -DryRun
        $r = Invoke-FaiEngine -Context $dry -Catalog $cat -Undo
        $r.Count('Planned') | Should -Be 2
        Get-FakeWriteCount $dry | Should -Be $writes
        Get-State $dry | Should -Be $applied
        $dry.Backup.SessionsOpened | Should -Be 0
        (Copy-Env $ctx).Backup.GetLatest() | Should -Not -BeNullOrEmpty
    }

    It 'Undo -DryRun: önizleme snapshot''taki önceki değeri gösterir (dönülecek durum), sıfır yazma' {
        $ctx = New-Env
        $ctx.Registry.Seed($script:Key, 'Existing', 7, 'DWord')
        $cat = New-Catalog (New-Tweak -Id 'test.one' -Actions @((RegSet 'Existing' 2), (RegSet 'New' 1)))
        [void](Invoke-FaiEngine -Profile (New-Profile @('test.one')) -Context $ctx -Catalog $cat)
        $writes = Get-FakeWriteCount $ctx

        $dry = Copy-Env $ctx -DryRun
        $r = Invoke-FaiEngine -Context $dry -Catalog $cat -Undo
        $text = ($r.Items | ForEach-Object { $_.Lines }) -join "`n"
        $text | Should -Match 'will revert to value 7 \(DWord\) restored'
        $text | Should -Match 'will revert to value deleted'
        Get-FakeWriteCount $dry | Should -Be $writes
    }
}

Describe 'Motor — diğer davranışlar' {
    It 'profildeki katalogda olmayan tweak Failed olur, öteki tweak''ler uygulanmaya devam eder' {
        $ctx = New-Env
        $cat = New-Catalog (New-Tweak -Id 'test.ok' -Actions @((RegSet 'Ok' 1)))
        $r = Invoke-FaiEngine -Profile (New-Profile @('test.missing', 'test.ok')) -Context $ctx -Catalog $cat
        $r.Find('test.missing').Status | Should -Be 'Failed'
        $r.Find('test.ok').Status | Should -Be 'Applied'
        $r.HasFailures() | Should -BeTrue
    }

    It 'hata veren tweak sonrakileri durdurmaz' {
        $ctx = New-Env
        $ctx.Registry.FailOnName = 'Boom'
        $a = New-Tweak -Id 'test.boom' -Actions @((RegSet 'Boom' 1))
        $b = New-Tweak -Id 'test.fine' -Actions @((RegSet 'Fine' 1))
        $r = Invoke-FaiEngine -Profile (New-Profile @('test.boom', 'test.fine')) -Context $ctx -Catalog (New-Catalog $a, $b)
        $r.Find('test.boom').Status | Should -Be 'Failed'
        $r.Find('test.fine').Status | Should -Be 'Applied'
    }

    It 'profil parametresi tweak varsayılanını geçersiz kılar; tanımsız parametre Failed olur' {
        $ctx = New-Env
        $t = New-Tweak -Id 'test.param' -Params @{ level = 15 } -Actions @((RegSet 'Level' '{{level}}'))
        $cat = New-Catalog $t
        $p = [Profile]::FromHashtable(@{ name = 'p'; tweaks = @(@{ id = 'test.param'; params = @{ level = 40 } }) }, 'test')
        [void](Invoke-FaiEngine -Profile $p -Context $ctx -Catalog $cat)
        $ctx.Registry.GetValue($script:Key, 'Level') | Should -Be 40

        $ctx2 = New-Env
        $bad = [Profile]::FromHashtable(@{ name = 'p'; tweaks = @(@{ id = 'test.param'; params = @{ nope = 1 } }) }, 'test')
        $r = Invoke-FaiEngine -Profile $bad -Context $ctx2 -Catalog $cat
        $r.Find('test.param').Status | Should -Be 'Failed'
        $r.Find('test.param').Reason | Should -Match 'undefined parameter'
        Get-FakeWriteCount $ctx2 | Should -Be 0
    }

    It 'olmayan servis için ServiceAction no-op: uygulanmaz, Undo hata vermez' {
        $ctx = New-Env
        $t = New-Tweak -Id 'test.nosvc' -Actions @(@{ Type = 'Service'; Name = 'Yok'; StartType = 'Disabled' })
        $cat = New-Catalog $t
        $r = Invoke-FaiEngine -Profile (New-Profile @('test.nosvc')) -Context $ctx -Catalog $cat
        $r.Find('test.nosvc').Status | Should -Be 'UpToDate'
        Get-FakeWriteCount $ctx | Should -Be 0
    }

    It 'rapor özeti durum sayılarını verir' {
        $ctx = New-Env
        $a = New-Tweak -Id 'test.a' -Actions @((RegSet 'A' 1))
        $b = New-Tweak -Id 'test.b' -Conditions @('HasNvidia') -Actions @((RegSet 'B' 1))
        $r = Invoke-FaiEngine -Profile (New-Profile @('test.a', 'test.b')) -Context $ctx -Catalog (New-Catalog $a, $b)
        $r.Summary() | Should -Be 'Summary: APPLIED: 1 · SKIPPED: 1'
    }

    It 'günlükçü uygulama ve atlama kayıtlarını tutar' {
        $ctx = New-Env
        $a = New-Tweak -Id 'test.a' -Actions @((RegSet 'A' 1))
        [void](Invoke-FaiEngine -Profile (New-Profile @('test.a')) -Context $ctx -Catalog (New-Catalog $a))
        # @(): 5.1'de tek PSCustomObject'in .Count'u yok ($null)
        @($ctx.Logger.Entries | Where-Object { $_.Message -match 'test\.a: applied' }).Count | Should -Be 1
    }
}

Describe 'Faz 7 tweak alanları: First, AlwaysConfirm, Tool ve eylem koşulu When' {
    BeforeAll {
        function New-FlagTweak([string] $Id, [hashtable] $Extra, [object[]] $Actions) {
            $d = @{ Id = $Id; Title = "Tweak $Id"; Description = 'test'; Category = 'test'; Risk = 'Safe'; Actions = $Actions }
            foreach ($k in $Extra.Keys) { $d[$k] = $Extra[$k] }
            return [Tweak]::FromHashtable($d, 'test')
        }
    }

    It 'şema: bayraklar mantıksal olmalı; When koşul sözdizimiyle doğrulanır' {
        $base = @{ Id = 'test.f'; Title = 'T'; Description = 'D'; Category = 'test'; Risk = 'Safe'; Actions = @(RegSet 'A' 1) }
        $bad = $base.Clone()
        $bad['First'] = 'evet'
        $bad['Tool'] = 1
        $msgs = (Get-FaiTweakError -Data $bad) -join "`n"
        $msgs | Should -Match 'First: '
        $msgs | Should -Match 'Tool: '
        $ok = $base.Clone()
        $ok['AlwaysConfirm'] = $true
        $ok['Actions'] = @(@{ Type = 'Registry'; Path = $script:Key; Name = 'A'; Value = 1; Kind = 'DWord'; When = @{ Not = 'IsLaptop' } })
        Get-FaiTweakError -Data $ok | Should -BeNullOrEmpty
        $ok['Actions'] = @(@{ Type = 'Registry'; Path = $script:Key; Name = 'A'; Value = 1; Kind = 'DWord'; When = 'IsDesktop' })
        ((Get-FaiTweakError -Data $ok) -join "`n") | Should -Match 'Actions\[0\]\.When: unknown condition'
    }

    It 'First işaretli tweak profildeki sırasından bağımsız önce işlenir' {
        $ctx = New-Env
        $cat = New-Catalog @(
            (New-FlagTweak 'test.a' @{} @(RegSet 'A' 1))
            (New-FlagTweak 'test.first' @{ First = $true } @(RegSet 'F' 1))
        )
        $r = Invoke-FaiEngine -Profile (New-Profile @('test.a', 'test.first')) -Context $ctx -Catalog $cat
        @($r.Items | ForEach-Object { $_.TweakId }) | Should -Be @('test.first', 'test.a')
        $r.Count('Applied') | Should -Be 2
    }

    It 'AlwaysConfirm: autoConfirm''e rağmen her çalıştırmada sorulur; -Unattended''da atlanır (P0 kabulü)' {
        $t = New-FlagTweak 'test.p0' @{ Risk = 'Caution'; AlwaysConfirm = $true; Confirm = 'pil ve ısı' } @(RegSet 'P0' 1)
        $cat = New-Catalog @($t)
        $p = New-Profile @('test.p0') -AutoConfirm @('test.p0')

        $ctx = New-Env -Answers @('H')
        $r = Invoke-FaiEngine -Profile $p -Context $ctx -Catalog $cat
        $r.Find('test.p0').Status | Should -Be 'Skipped'
        $ctx.Prompt.Asked.Count | Should -Be 1
        $ctx.Prompt.Asked[0]['Message'] | Should -Match 'pil ve ısı'

        $ctx2 = Copy-Env $ctx -Answers @('Y')
        (Invoke-FaiEngine -Profile $p -Context $ctx2 -Catalog $cat).Find('test.p0').Status | Should -Be 'Applied'
        $ctx2.Prompt.Asked.Count | Should -Be 1

        $ctx.Registry.DeleteValue($script:Key, 'P0')
        $u = Copy-Env $ctx -Unattended
        $ru = Invoke-FaiEngine -Profile $p -Context $u -Catalog $cat
        $ru.Find('test.p0').Status | Should -Be 'Skipped'
        $ru.Find('test.p0').Reason | Should -Match 'Unattended'
        $ctx.Registry.ValueExists($script:Key, 'P0') | Should -BeFalse

        # Aynı Caution tweak AlwaysConfirm olmadan autoConfirm ile sorulmadan uygulanır.
        $plain = New-Catalog @(New-FlagTweak 'test.p0' @{ Risk = 'Caution' } @(RegSet 'P0' 1))
        (Invoke-FaiEngine -Profile $p -Context (Copy-Env $ctx -Unattended) -Catalog $plain).Find('test.p0').Status | Should -Be 'Applied'
    }

    It 'Tool: profille atlanır, AllowTools ile çalışır' {
        $ctx = New-Env
        $cat = New-Catalog @(New-FlagTweak 'test.tool' @{ Tool = $true } @(RegSet 'T' 1))
        $r = Invoke-FaiEngine -Profile (New-Profile @('test.tool')) -Context $ctx -Catalog $cat
        $r.Find('test.tool').Status | Should -Be 'Skipped'
        $r.Find('test.tool').Reason | Should -Match 'Tool'
        Get-FakeWriteCount $ctx | Should -Be 0
        $r2 = Invoke-FaiEngine -Profile (New-Profile @('test.tool')) -Context $ctx -Catalog $cat -AllowTools
        $r2.Find('test.tool').Status | Should -Be 'Applied'
    }

    It 'When: koşulu sağlanmayan eylem atlanır, oturum kaydında When yok, -Undo birebir' {
        $acts = @(
            (RegSet 'Her' 1)
            @{ Type = 'Registry'; Path = $script:Key; Name = 'Dizustu'; Value = 1; Kind = 'DWord'; When = 'IsLaptop' }
        )
        $cat = New-Catalog @(New-FlagTweak 'test.when' @{} $acts)
        $cat['test.when'].Actions[1].When.Name | Should -Be 'IsLaptop'
        $cat['test.when'].Actions[1].Definition.ContainsKey('When') | Should -BeFalse

        $ctx = New-Env
        $before = $ctx.Registry.Dump() -join "`n"
        $r = Invoke-FaiEngine -Profile (New-Profile @('test.when')) -Context $ctx -Catalog $cat
        @($r.Find('test.when').Lines).Count | Should -Be 1
        $ctx.Registry.ValueExists($script:Key, 'Dizustu') | Should -BeFalse
        (Invoke-FaiEngine -Profile (New-Profile @('test.when')) -Context $ctx -Catalog $cat).Find('test.when').Status | Should -Be 'UpToDate'

        $ctx.SystemInfo.Laptop = $true
        $dry = Invoke-FaiEngine -Profile (New-Profile @('test.when')) -Context (Copy-Env $ctx -DryRun) -Catalog $cat
        @($dry.Find('test.when').Lines) -join "`n" | Should -Match 'Dizustu'
        (Invoke-FaiEngine -Profile (New-Profile @('test.when')) -Context $ctx -Catalog $cat).Find('test.when').Status | Should -Be 'Applied'
        $ctx.Registry.GetValue($script:Key, 'Dizustu') | Should -Be 1
        $s = $ctx.Backup.GetLatest()
        $s.Entries[0]['Action'].ContainsKey('When') | Should -BeFalse

        $u1 = Invoke-FaiEngine -Undo -Context $ctx -Catalog $cat
        $u1.HasFailures() | Should -BeFalse
        $u2 = Invoke-FaiEngine -Undo -Context $ctx -Catalog $cat
        $u2.HasFailures() | Should -BeFalse
        $ctx.Registry.Dump() -join "`n" | Should -Be $before
    }
}

Describe 'v0.1.1 geri alma sağlamlığı: kayıt başına geri alındı, -SkipFailed, devam aynı oturuma' {
    BeforeAll {
        # A, B, C = 1; tweak üçünü 2 yapar. B'nin geri alınması (SetValue B 1) FailOnName ile patlatılır.
        function New-ThreeEnv {
            $ctx = New-Env
            foreach ($n in 'A', 'B', 'C') { $ctx.Registry.Seed($script:Key, $n, 1, 'DWord') }
            $cat = New-Catalog (New-Tweak -Id 'test.three' -Actions @((RegSet 'A' 2), (RegSet 'B' 2), (RegSet 'C' 2)))
            [void](Invoke-FaiEngine -Profile (New-Profile @('test.three')) -Context $ctx -Catalog $cat 6>$null)
            return @{ Ctx = $ctx; Cat = $cat; Id = $ctx.Backup.ListSessionIds()[0] }
        }
        function New-ResumeCatalog {
            return (New-Catalog @((New-Tweak -Id 'test.r1' -Actions @((RegSet 'A' 2))), (New-Tweak -Id 'test.r2' -Actions @((RegSet 'B' 2)))))
        }
    }

    It 'başarısız kayıt oturumu açık bırakır; yeniden -Undo yalnız kalanları dener' {
        $g = New-ThreeEnv
        $g.Ctx.Registry.FailOnName = 'B'
        $u1ctx = Copy-Env $g.Ctx
        $u1 = Invoke-FaiEngine -Undo -Context $u1ctx -Catalog $g.Cat 6>$null
        @($u1.Items | Where-Object { $_.Status -eq 'Reverted' }).Count | Should -Be 2
        @($u1.Items | Where-Object { $_.Status -eq 'Failed' }).Count | Should -Be 1
        $u1ctx.Prompt.Asked.Count | Should -Be 1 -Because 'etkileşimli kipte atlama sorulur (yanıt yok = hayır)'
        $s = ([BackupStore]::new($g.Ctx.Backup.Root)).Load($g.Id)
        $s.IsUndone() | Should -BeFalse
        $s.IsEntryUndone(0) | Should -BeTrue
        $s.IsEntryUndone(1) | Should -BeFalse
        $s.IsEntryUndone(2) | Should -BeTrue

        # Geri alınan değerler sonradan değişirse ikinci deneme onlara dokunmamalı.
        $g.Ctx.Registry.Seed($script:Key, 'A', 5, 'DWord')
        $g.Ctx.Registry.Seed($script:Key, 'C', 5, 'DWord')
        $g.Ctx.Registry.FailOnName = ''
        $u2 = Invoke-FaiEngine -Undo -Context (Copy-Env $g.Ctx) -Catalog $g.Cat 6>$null
        $u2.HasFailures() | Should -BeFalse
        @($u2.Items | Where-Object { $_.Status -eq 'Reverted' }).Count | Should -Be 1
        $u2.Find('(session)').Reason | Should -Be '2 entries'
        $g.Ctx.Registry.GetValue($script:Key, 'B') | Should -Be 1
        $g.Ctx.Registry.GetValue($script:Key, 'A') | Should -Be 5
        $g.Ctx.Registry.GetValue($script:Key, 'C') | Should -Be 5
        ([BackupStore]::new($g.Ctx.Backup.Root)).GetLatest() | Should -BeNullOrEmpty
    }

    It '-Unattended: soru sorulmaz, atlanmaz, oturum açık kalır' {
        $g = New-ThreeEnv
        $g.Ctx.Registry.FailOnName = 'B'
        $uctx = Copy-Env $g.Ctx -Unattended
        $r = Invoke-FaiEngine -Undo -Context $uctx -Catalog $g.Cat 6>$null
        $r.HasFailures() | Should -BeTrue
        $uctx.Prompt.Asked.Count | Should -Be 0
        ([BackupStore]::new($g.Ctx.Backup.Root)).GetLatest().Id | Should -Be $g.Id
    }

    It '-SkipFailed hatalıyı atlar, oturumu kapatır, atlananı raporda gösterir' {
        $g = New-ThreeEnv
        $g.Ctx.Registry.FailOnName = 'B'
        $uctx = Copy-Env $g.Ctx -Unattended
        $r = Invoke-FaiEngine -Undo -SkipFailed -Context $uctx -Catalog $g.Cat 6>$null
        $r.HasFailures() | Should -BeFalse
        $uctx.Prompt.Asked.Count | Should -Be 0
        $row = @($r.Items | Where-Object { $_.TweakId -eq 'test.three' -and $_.Status -eq 'Skipped' })
        $row.Count | Should -Be 1
        $row[0].Title | Should -Be 'action 2'
        $row[0].Reason | Should -BeLike 'could not revert, skipped: *Simulated write error*'
        @($r.Items | Where-Object { $_.Title -like 'Failed entries skipped*' }).Count | Should -Be 1
        $s = ([BackupStore]::new($g.Ctx.Backup.Root)).Load($g.Id)
        $s.IsUndone() | Should -BeTrue
        [string]$s.Entries[1]['UndoSkippedAt'] | Should -Not -BeNullOrEmpty
        $g.Ctx.Registry.GetValue($script:Key, 'A') | Should -Be 1
        $g.Ctx.Registry.GetValue($script:Key, 'C') | Should -Be 1
    }

    It 'etkileşimli onay (Y) hatalıları atlar ve oturumu kapatır' {
        $g = New-ThreeEnv
        $g.Ctx.Registry.FailOnName = 'B'
        $uctx = Copy-Env $g.Ctx -Answers @('y')
        $r = Invoke-FaiEngine -Undo -Context $uctx -Catalog $g.Cat 6>$null
        $uctx.Prompt.Asked[0].Message | Should -BeLike '*Entries not reverted: 1 (test.three)*'
        $r.HasFailures() | Should -BeFalse
        ([BackupStore]::new($g.Ctx.Backup.Root)).GetLatest() | Should -BeNullOrEmpty
    }

    It 'oturum dosyası eylem başına bir kez yazılır (snapshot uygulamadan önce, ikinci tam yazım yok)' {
        $ctx = New-Env
        $cat = New-Catalog (New-Tweak -Id 'test.two' -Actions @((RegSet 'X' 1), (RegSet 'Y' 1)))
        $engine = [Engine]::new($ctx, $cat)
        [void]$engine.Run((New-Profile @('test.two')))
        $engine.Session.SaveCount | Should -Be 3 -Because 'oturum açılışı + eylem başına bir kayıt'
    }

    It 'devam: -Session ile aynı oturuma yazar, tek -Undo hepsini geri alır, devam komutuna kimlik eklenir' {
        $ctx = New-Env
        $ctx.Registry.Seed($script:Key, 'A', 1, 'DWord')
        $ctx.Registry.Seed($script:Key, 'B', 1, 'DWord')
        $before = Get-State $ctx
        $cat = New-ResumeCatalog
        $c1 = Copy-Env $ctx
        $c1.ResumeCommand = 'powershell.exe -File "x.ps1" -Profile "p"'
        [void](Invoke-FaiEngine -Profile (New-Profile @('test.r1')) -Context $c1 -Catalog $cat 6>$null)
        $id = $ctx.Backup.ListSessionIds()[0]
        $c1.ResumeCommand | Should -Be ('powershell.exe -File "x.ps1" -Profile "p" -Session "{0}"' -f $id)

        $c2 = Copy-Env $ctx
        $c2.ResumeCommand = $c1.ResumeCommand
        [void](Invoke-FaiEngine -Profile (New-Profile @('test.r2')) -Context $c2 -Catalog $cat -Session $id 6>$null)
        $c2.Backup.SessionsOpened | Should -Be 0
        $ctx.Backup.ListSessionIds() | Should -Be @($id)
        ([regex]::Matches($c2.ResumeCommand, '-Session')).Count | Should -Be 1
        ([BackupStore]::new($ctx.Backup.Root)).Load($id).Entries.Count | Should -Be 2

        $r = Invoke-FaiEngine -Undo -Context (Copy-Env $ctx) -Catalog $cat 6>$null
        $r.HasFailures() | Should -BeFalse
        Get-State $ctx | Should -Be $before
    }

    It 'devam: <Case> oturuma yazılmaz; yeni oturum, raporda uyarı' -ForEach @(
        @{ Case = 'geri alınmış' }, @{ Case = 'güvenilmeyen' }, @{ Case = 'olmayan' }
    ) {
        $ctx = New-Env
        $cat = New-ResumeCatalog
        [void](Invoke-FaiEngine -Profile (New-Profile @('test.r1')) -Context $ctx -Catalog $cat 6>$null)
        $id = $ctx.Backup.ListSessionIds()[0]
        $c2 = Copy-Env $ctx
        if ($Case -eq 'geri alınmış') { [void](Invoke-FaiEngine -Undo -Context (Copy-Env $ctx) -Catalog $cat 6>$null) }
        if ($Case -eq 'güvenilmeyen') {
            $sec = [FakeFileSecurityProvider]::new()
            $sec.SeedFile((Join-Path $ctx.Backup.Root ($id + '.json')), 'S-1-5-21-1000-1000-1000-1001')
            $c2.Backup.Security = $sec
        }
        $want = $id
        if ($Case -eq 'olmayan') { $want = '20990101-000000-000-00' }
        $r = Invoke-FaiEngine -Profile (New-Profile @('test.r2')) -Context $c2 -Catalog $cat -Session $want 6>$null
        $c2.Backup.SessionsOpened | Should -Be 1
        $ctx.Backup.ListSessionIds().Count | Should -Be 2
        $r.Find('(backup)').Title | Should -Be 'Resume session not used'
        $r.Find('test.r2').Status | Should -Be 'Applied'
    }
}
