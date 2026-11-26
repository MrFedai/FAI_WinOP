#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }
# BackupStore: oturum başına JSON snapshot dosyası; kök yapıcıdan verilir, ilk yazıda oluşur.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Load-Fakes.ps1')
}

Describe 'BackupStore' {
    It 'kök klasör oturum açılana kadar oluşmaz' {
        $store = [BackupStore]::new((Join-Path $TestDrive 'lazy'))
        Test-Path -LiteralPath $store.Root | Should -BeFalse
        $store.ListSessionIds().Count | Should -Be 0
        $store.GetLatest() | Should -BeNullOrEmpty
        $store.SessionsOpened | Should -Be 0
    }

    It 'oturum açınca kök ve oturum dosyası oluşur, SessionsOpened artar' {
        $store = [BackupStore]::new((Join-Path $TestDrive 'open'))
        $s = $store.BeginSession('demo')
        $store.SessionsOpened | Should -Be 1
        Test-Path -LiteralPath $s.Path | Should -BeTrue
        $s.Path | Should -BeLike (Join-Path $TestDrive 'open*')
    }

    It 'aynı milisaniyede açılan oturumlar çakışmaz ve açılış sırasıyla listelenir' {
        $store = [BackupStore]::new((Join-Path $TestDrive 'many'))
        $ids = 1..15 | ForEach-Object { $store.BeginSession('p').Id }
        ($ids | Sort-Object -Unique).Count | Should -Be 15
        $listed = $store.ListSessionIds()
        ($listed -join ',') | Should -Be ($ids -join ',')
        $store.GetLatest().Id | Should -Be $ids[-1]
    }

    It 'JSON gidiş-dönüşünde türler korunur (DWord, QWord, String, Binary, MultiString, boş dizi)' {
        $store = [BackupStore]::new((Join-Path $TestDrive 'rt'))
        $s = $store.BeginSession('demo')
        $s.AddEntry('t.one', 0, @{ Type = 'Registry'; Path = 'HKCU:\X'; Name = 'N'; Value = 1; Kind = 'DWord' }, @{
                Exists = $true; Value = 5; Kind = 'DWord'
            })
        $s.AddEntry('t.one', 1, @{ Type = 'Registry'; Path = 'HKCU:\X'; Name = 'Q'; Value = 1; Kind = 'QWord' }, @{
                Exists = $true; Value = 4294967296; Kind = 'QWord'
            })
        $s.AddEntry('t.one', 2, @{ Type = 'Registry'; Path = 'HKCU:\X'; Name = 'B'; Value = @(1); Kind = 'Binary' }, @{
                Exists = $true; Value = [byte[]](0, 255); Kind = 'Binary'
            })
        $s.AddEntry('t.one', 3, @{ Type = 'Registry'; Path = 'HKCU:\X'; Name = 'M'; Value = @('a'); Kind = 'MultiString' }, @{
                Exists = $true; Value = @('tek'); Kind = 'MultiString'
            })
        $s.AddEntry('t.one', 4, @{ Type = 'Registry'; Path = 'HKCU:\X'; Name = 'E'; Value = @(); Kind = 'MultiString' }, @{
                Exists = $true; Value = @(); Kind = 'MultiString'
            })
        $s.AddEntry('t.one', 5, @{ Type = 'Registry'; Path = 'HKCU:\X'; Name = 'S'; Value = 'x'; Kind = 'String' }, @{ Exists = $false })

        $back = ([BackupStore]::new($store.Root)).Load($s.Id)
        $back.Id | Should -Be $s.Id
        $back.ProfileName | Should -Be 'demo'
        $back.Entries.Count | Should -Be 6
        $back.Entries[0]['TweakId'] | Should -Be 't.one'
        $back.Entries[0]['Action'] | Should -BeOfType [hashtable]
        $back.Entries[1]['Snapshot']['Value'] | Should -Be 4294967296
        $back.Entries[5]['Snapshot']['Exists'] | Should -BeFalse

        # Revert'in kullandığı dönüştürücü, JSON'dan dönen Object[] değerleri doğru .NET türüne çevirir.
        $bin = ConvertTo-FaiRegistryValue $back.Entries[2]['Snapshot']['Value'] 'Binary'
        , $bin | Should -BeOfType [byte[]]
        ($bin -join ',') | Should -Be '0,255'
        $multi = ConvertTo-FaiRegistryValue $back.Entries[3]['Snapshot']['Value'] 'MultiString'
        $multi.Count | Should -Be 1
        $multi[0] | Should -Be 'tek'
        $empty = ConvertTo-FaiRegistryValue $back.Entries[4]['Snapshot']['Value'] 'MultiString'
        $empty.Count | Should -Be 0
    }

    It 'Türkçe karakterler snapshot dosyasında bozulmaz' {
        $store = [BackupStore]::new((Join-Path $TestDrive 'tr'))
        $s = $store.BeginSession('türkçe')
        $s.AddEntry('t.tr', 0, @{ Type = 'Registry'; Path = 'HKCU:\X'; Name = 'N'; Value = 'x'; Kind = 'String' }, @{
                Exists = $true; Value = 'Açılış sesi şğüöçİı'; Kind = 'String'
            })
        $back = ([BackupStore]::new($store.Root)).Load($s.Id)
        $back.Entries[0]['Snapshot']['Value'] | Should -Be 'Açılış sesi şğüöçİı'
        $back.ProfileName | Should -Be 'türkçe'
    }

    It 'GetLatest geri alınmış oturumları atlar' {
        $store = [BackupStore]::new((Join-Path $TestDrive 'undone'))
        $first = $store.BeginSession('a')
        $second = $store.BeginSession('b')
        $store.GetLatest().Id | Should -Be $second.Id
        $second.MarkUndone()
        $store.GetLatest().Id | Should -Be $first.Id
        $first.MarkUndone()
        $store.GetLatest() | Should -BeNullOrEmpty
    }

    It 'olmayan oturum kimliği hata verir' {
        $store = [BackupStore]::new((Join-Path $TestDrive 'none'))
        { $store.Load('yok') } | Should -Throw '*Yedek oturumu yok*'
    }
}

Describe 'BackupStore: sahip denetimi (Security)' {
    BeforeAll {
        $script:User = 'S-1-5-21-1000-1000-1000-1001'
        # Oturumları gerçek diske yazar, sahiplerini sahte güvenlik sağlayıcısına tohumlar.
        function New-GuardedStore([string] $Name) {
            $store = [BackupStore]::new((Join-Path $TestDrive $Name))
            $first = $store.BeginSession('a')
            $second = $store.BeginSession('b')
            $sec = [FakeFileSecurityProvider]::new()
            $sec.SeedFile($first.Path, 'S-1-5-32-544')
            $sec.SeedFile($second.Path, $script:User)
            $store.Security = $sec
            return @{ Store = $store; First = $first; Second = $second; Security = $sec }
        }
    }

    It 'sahibi kullanıcı olan oturum Load ile okunmaz, açık hata' {
        $g = New-GuardedStore 'guard-load'
        { $g.Store.Load($g.Second.Id) } | Should -Throw '*güvenilmez*'
        $g.Store.Load($g.First.Id).Id | Should -Be $g.First.Id
    }

    It 'GetLatest güvenilmeyen son oturumu atlar, uyarı bırakır, öncekini döndürür' {
        $g = New-GuardedStore 'guard-latest'
        $g.Store.GetLatest().Id | Should -Be $g.First.Id
        @($g.Store.Warnings).Count | Should -Be 1
        @($g.Store.Warnings)[0] | Should -BeLike "*$($g.Second.Id).json*"
    }

    It 'bağlantı (symlink) olan oturum dosyası güvenilmez' {
        $g = New-GuardedStore 'guard-link'
        $g.Security.SeedLink($g.First.Path, 'File', 'S-1-5-32-544')
        { $g.Store.Load($g.First.Id) } | Should -Throw '*güvenilmez*'
        $g.Store.GetLatest() | Should -BeNullOrEmpty
        @($g.Store.Warnings).Count | Should -Be 2
    }

    It '-Undo: güvenilmeyen oturum kullanılmaz, raporda uyarı satırı olur' {
        $ctx = New-FakeContext -BackupRoot (Join-Path $TestDrive 'guard-undo')
        $first = $ctx.Backup.BeginSession('a')
        $second = $ctx.Backup.BeginSession('b')
        $sec = [FakeFileSecurityProvider]::new()
        $sec.SeedFile($first.Path, 'S-1-5-18')
        $sec.SeedFile($second.Path, $script:User)
        $ctx.Backup.Security = $sec
        $report = Invoke-FaiEngine -Undo -Context $ctx -Catalog @{} -AppCatalog @{} 6>$null
        $report.Heading | Should -BeLike "*$($first.Id)*"
        $row = @($report.Items | Where-Object { $_.TweakId -eq '(yedek)' })
        $row.Count | Should -Be 1
        $row[0].Status | Should -Be 'Skipped'
        $row[0].Reason | Should -BeLike "*$($second.Id).json*"
    }
}

