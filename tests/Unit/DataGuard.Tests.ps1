#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }
# Veri klasörü (%ProgramData%\FAI_WinOP) koruması: izin, sahip denetimi, bağlantı reddi (FakeFileSecurityProvider).

BeforeAll {
    . (Join-Path $PSScriptRoot 'Load-Fakes.ps1')

    $script:Root = 'C:\ProgramData\FAI_WinOP'
    $script:Shared = 'C:\ProgramData\FAI_WinOP\shared'
    $script:Admins = 'S-1-5-32-544'
    $script:System = 'S-1-5-18'
    $script:Users = 'S-1-5-32-545'
    $script:User = 'S-1-5-21-1000-1000-1000-1001'

    # Önceden korunmuş (doğru izinli) veri klasörü.
    function New-Protected {
        $s = [FakeFileSecurityProvider]::new()
        [void](Protect-FaiDataDirectory -Security $s -Path $script:Root)
        $s.WriteLog.Clear()
        $s.WriteCount = 0
        return $s
    }
}

Describe 'Protect-FaiDataDirectory: izin' {
    It 'klasör yoksa açar: kalıtım kapalı, yalnız SYSTEM + Administrators, sahip Administrators' {
        $s = [FakeFileSecurityProvider]::new()
        $r = Protect-FaiDataDirectory -Security $s -Path $script:Root
        $acl = $s.GetAcl($script:Root)
        $acl['Protected'] | Should -BeTrue
        $acl['Owner'] | Should -Be $script:Admins
        $sids = @($acl['Rules'] | ForEach-Object { '{0}={1}' -f $_['Sid'], $_['Access'] }) | Sort-Object
        ($sids -join ',') | Should -Be "$script:System=Full,$script:Admins=Full"
        Test-FaiRestrictedAcl -Acl $acl | Should -BeTrue
        @($r['Quarantined']).Count | Should -Be 0
        @($r['AclFixed']).Count | Should -Be 0
    }

    It "'shared' alt klasörü ayrıca Users okuma alır (yazma yok)" {
        $s = [FakeFileSecurityProvider]::new()
        [void](Protect-FaiDataDirectory -Security $s -Path $script:Root)
        $acl = $s.GetAcl($script:Shared)
        Test-FaiRestrictedAcl -Acl $acl -ReaderSid @($script:Users) | Should -BeTrue
        @($acl['Rules'] | Where-Object { $_['Sid'] -eq $script:Users })[0]['Access'] | Should -Be 'Read'
    }

    It 'var olan klasörün yanlış izni (kalıtılmış, Users yazar) düzeltilir ve bildirilir' {
        $s = [FakeFileSecurityProvider]::new()
        $s.SeedDirectory($script:Root, $script:Admins)
        Test-FaiRestrictedAcl -Acl $s.GetAcl($script:Root) | Should -BeFalse
        $r = Protect-FaiDataDirectory -Security $s -Path $script:Root
        Test-FaiRestrictedAcl -Acl $s.GetAcl($script:Root) | Should -BeTrue
        @($r['AclFixed']) | Should -Contain $script:Root
        @($r['Quarantined']).Count | Should -Be 0
    }

    It 'izin doğruysa yazma yapılmaz' {
        $s = New-Protected
        $r = Protect-FaiDataDirectory -Security $s -Path $script:Root
        $s.WriteCount | Should -Be 0
        @($r['AclFixed']).Count | Should -Be 0
    }

    It 'Test-FaiRestrictedAcl fazla kuralı, kalıtılmış kuralı ve yanlış sahibi reddeder' {
        $ok = @{ Protected = $true; Owner = $script:Admins; Rules = @(
                @{ Sid = $script:System; Access = 'Full'; Deny = $false; Inherited = $false; Inherits = $true },
                @{ Sid = $script:Admins; Access = 'Full'; Deny = $false; Inherited = $false; Inherits = $true }) }
        Test-FaiRestrictedAcl -Acl $ok | Should -BeTrue
        $extra = $ok.Clone(); $extra['Rules'] = @($ok['Rules']) + @(@{ Sid = $script:Users; Access = 'Read'; Deny = $false; Inherited = $false; Inherits = $true })
        Test-FaiRestrictedAcl -Acl $extra | Should -BeFalse
        $owner = $ok.Clone(); $owner['Owner'] = $script:User
        Test-FaiRestrictedAcl -Acl $owner | Should -BeFalse
        $open = $ok.Clone(); $open['Protected'] = $false
        Test-FaiRestrictedAcl -Acl $open | Should -BeFalse
        $inh = $ok.Clone(); $inh['Rules'] = @(@{ Sid = $script:System; Access = 'Full'; Deny = $false; Inherited = $true; Inherits = $true }, $ok['Rules'][1])
        Test-FaiRestrictedAcl -Acl $inh | Should -BeFalse
    }
}

Describe 'Protect-FaiDataDirectory: sahip denetimi' {
    It 'yönetici olmayan sahibin kök klasörü kenara alınır, yenisi açılır' {
        $s = [FakeFileSecurityProvider]::new()
        $s.SeedDirectory($script:Root, $script:User)
        $s.SeedFile("$script:Root\backup\x.json", $script:User)
        $r = Protect-FaiDataDirectory -Security $s -Path $script:Root
        @($r['Quarantined']).Count | Should -Be 1
        @($r['Quarantined'])[0] | Should -Match '^C:\\ProgramData\\FAI_WinOP\.untrusted-\d{14}$'
        $s.GetOwnerSid($script:Root) | Should -Be $script:Admins
        $s.GetItemType("$script:Root\backup\x.json") | Should -Be ''
        Test-FaiRestrictedAcl -Acl $s.GetAcl($script:Root) | Should -BeTrue
    }

    It 'yedek oturumu / betik: sahibi kullanıcıysa kenara alınır; SYSTEM ve Administrators dosyaları kalır' {
        $s = New-Protected
        $s.SeedDirectory("$script:Root\backup", $script:Admins)
        $s.SeedFile("$script:Root\backup\20260101-000000-000-00.json", $script:User)
        $s.SeedFile("$script:Root\backup\20260102-000000-000-00.json", $script:Admins)
        $s.SeedFile("$script:Root\BloatCleanup.ps1", $script:User)
        $s.SeedFile("$script:Root\GameAffinity.ps1", $script:System)
        $r = Protect-FaiDataDirectory -Security $s -Path $script:Root
        $q = @($r['Quarantined'])
        $q.Count | Should -Be 2
        ($q -join ';') | Should -Match '20260101-000000-000-00\.json\.untrusted-\d{14}'
        ($q -join ';') | Should -Match 'BloatCleanup\.ps1\.untrusted-\d{14}'
        $s.GetItemType("$script:Root\backup\20260101-000000-000-00.json") | Should -Be ''
        $s.GetItemType("$script:Root\backup\20260102-000000-000-00.json") | Should -Be 'File'
        $s.GetItemType("$script:Root\GameAffinity.ps1") | Should -Be 'File'
    }

    It 'sahibi okunamayan öğe güvenilmez' {
        $s = New-Protected
        $s.SeedFile("$script:Root\x.ps1", '')
        $r = Protect-FaiDataDirectory -Security $s -Path $script:Root
        @($r['Quarantined']).Count | Should -Be 1
    }

    It 'kenara alınmış öğeler yeniden taşınmaz' {
        $s = New-Protected
        $s.SeedFile("$script:Root\a.ps1.untrusted-20260101000000", $script:User)
        $r = Protect-FaiDataDirectory -Security $s -Path $script:Root
        @($r['Quarantined']).Count | Should -Be 0
        $s.WriteCount | Should -Be 0
    }

    It 'aynı adda kenara alınmış öğe varsa sonuna sıra eklenir' {
        $s = New-Protected
        $stamp = Get-Date -Format 'yyyyMMddHHmmss'
        $s.SeedFile("$script:Root\a.ps1.untrusted-$stamp", $script:Admins)
        $s.SeedFile("$script:Root\a.ps1", $script:User)
        $moved = Move-FaiUntrustedItem -Security $s -Path "$script:Root\a.ps1"
        $moved | Should -Match '\.untrusted-\d{14}-1$'
    }
}

Describe 'Protect-FaiDataDirectory: yeniden ayrıştırma noktası' {
    It 'kök junction ise kenara alınır (hedefine izin yazılmaz), gerçek klasör açılır' {
        $s = [FakeFileSecurityProvider]::new()
        $s.SeedLink($script:Root, 'Directory', $script:Admins)
        $r = Protect-FaiDataDirectory -Security $s -Path $script:Root
        @($r['Quarantined']).Count | Should -Be 1
        $s.IsReparsePoint($script:Root) | Should -BeFalse
        $s.GetItemType($script:Root) | Should -Be 'Directory'
        @($s.WriteLog | Where-Object { $_ -like 'SetRestrictedAcl*' -and $_ -like '*untrusted*' }).Count | Should -Be 0
    }

    It 'kök yerinde dosya varsa kenara alınır' {
        $s = [FakeFileSecurityProvider]::new()
        $s.SeedFile($script:Root, $script:Admins)
        $r = Protect-FaiDataDirectory -Security $s -Path $script:Root
        @($r['Quarantined']).Count | Should -Be 1
        $s.GetItemType($script:Root) | Should -Be 'Directory'
    }

    It 'sahibi Administrators olsa da alt öğe bağlantıysa kenara alınır, içine girilmez' {
        $s = New-Protected
        $s.SeedLink("$script:Root\backup", 'Directory', $script:Admins)
        $s.SeedFile("$script:Root\backup\inner.json", $script:User)
        $s.SeedLink("$script:Root\shared\install.ps1", 'File', $script:System)
        $r = Protect-FaiDataDirectory -Security $s -Path $script:Root
        $q = @($r['Quarantined'])
        $q.Count | Should -Be 2
        @($s.CallLog | Where-Object { $_ -like 'GetEntries*backup*' }).Count | Should -Be 0
        $s.GetItemType("$script:Root\shared\install.ps1") | Should -Be ''
    }

    It "'shared' bağlantıysa kenara alınır ve yeniden açılır" {
        $s = New-Protected
        $s.Items.Remove([FakeFileSecurityProvider]::Norm($script:Shared))
        $s.SeedLink($script:Shared, 'Directory', $script:Admins)
        $r = Protect-FaiDataDirectory -Security $s -Path $script:Root
        @($r['Quarantined']).Count | Should -Be 1
        $s.IsReparsePoint($script:Shared) | Should -BeFalse
        Test-FaiRestrictedAcl -Acl $s.GetAcl($script:Shared) -ReaderSid @($script:Users) | Should -BeTrue
    }

    It 'IsTrusted: bağlantı, yok, yanlış sahip false; SYSTEM / Administrators true' {
        $s = [FakeFileSecurityProvider]::new()
        $s.SeedFile('C:\a', $script:System)
        $s.SeedFile('C:\b', $script:Admins)
        $s.SeedFile('C:\c', $script:User)
        $s.SeedLink('C:\d', 'File', $script:Admins)
        $s.IsTrusted('C:\a') | Should -BeTrue
        $s.IsTrusted('C:\b') | Should -BeTrue
        $s.IsTrusted('C:\c') | Should -BeFalse
        $s.IsTrusted('C:\d') | Should -BeFalse
        $s.IsTrusted('C:\yok') | Should -BeFalse
    }
}
