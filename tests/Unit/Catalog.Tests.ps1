#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }
# Faz 3 kabulü: tweaks/ kataloğu şemadan geçer; dry-run raporu her tweak için okunabilir değişiklik listesi verir;
# uygula → -Undo başlangıç durumunu birebir geri getirir. Ayrıca açık repo kuralı (kişisel veri yok) ve dosya düzeni.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Load-Fakes.ps1')
    $script:TweakRoot = Join-Path $script:FaiRepoRoot 'tweaks'
    $script:Catalog = Import-FaiTweakCatalog -Path $script:TweakRoot
    $script:Ids = @($script:Catalog.Keys | Sort-Object)
    # Tek seferlik tweak'ler: her çalıştırmada yeniden yapılır / geri alınmaz (ZATEN UYGUN olmaz); ayrı test edilir.
    $script:OneShot = @('system.restore-point', 'setup.edition-pro', 'refresh.reboot-to-bios')
    # Araç tweak'leri profille çalışmaz (dry-run'da da atlanır).
    $script:ToolIds = @($script:Ids | Where-Object { $script:Catalog[$_].Tool })
    $script:RepeatIds = @($script:Ids | Where-Object { $script:OneShot -notcontains $_ })
    $script:GpuClass = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
    $script:NotifRoot = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings'
    $script:Seq = 0

    # Gerçek makineye benzer başlangıç: servisler, görevler ve bildirim gönderenleri var.
    function New-SeededContext([switch] $DryRun) {
        $script:Seq++
        $ctx = New-FakeContext -BackupRoot (Join-Path $TestDrive ('c{0}' -f $script:Seq)) -DryRun:$DryRun
        $ctx.Services.Seed('DiagTrack', 'Automatic', 'Running')
        $ctx.Services.Seed('dmwappushservice', 'Manual', 'Stopped')
        $ctx.Tasks.Seed('\Microsoft\Windows\Customer Experience Improvement Program\Consolidator', 'Enabled')
        $ctx.Tasks.Seed('\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser Exp', 'Enabled')
        foreach ($k in @('Logi.GHUB.Systray', '5319275A.WhatsAppDesktop_cv1g1gvanyjgm!App', 'Telegram.TelegramDesktop',
                'Windows.Defender.SecurityCenter', 'Windows.SystemToast.AutoPlay', 'Discord.Discord')) {
            $ctx.Registry.Seed("$script:NotifRoot\$k", 'Rank', 1, 'DWord')
        }
        $ctx.Registry.Seed("$script:NotifRoot\Discord.Discord", 'Enabled', 1, 'DWord')
        $ctx.Registry.Seed('HKCU:\Control Panel\Desktop', 'UserPreferencesMask', @(0x9E, 0x3E, 0x07, 0x80, 0x12, 0x00, 0x00, 0x00), 'Binary')
        $ctx.Registry.Seed('HKCU:\Software\Microsoft\Siuf\Rules', 'PeriodInNanoSeconds', 0, 'QWord')
        # setup.default-browser: Caution onayı + Ayarlar'da kullanıcının basması (Shell.OnOpen taklit eder).
        $choice = 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoiceLatest\ProgId'
        $ctx.Registry.Seed($choice, 'ProgId', 'MSEdgeHTM', 'String')
        $reg = $ctx.Registry
        $ctx.Shell.OnOpen = {
            param($Uri)
            if ($Uri -like '*registeredApp*') { $reg.Seed($choice, 'ProgId', 'ChromeHTML', 'String') }
            elseif ($Uri -eq 'ms-settings:defaultapps') { $reg.Seed($choice, 'ProgId', 'MSEdgeHTM', 'String') }
        }.GetNewClosure()
        # Faz 5: kara listeden bir paket (kullanıcı + provisioned), korunan Store, kurulu Edge + WebView2.
        # ui.widgets-off: pencere öğeleri paketi (korunan kalıpta istisna).
        $appx = [string[]]@('Microsoft.BingNews', 'Microsoft.WindowsStore', 'MicrosoftWindows.Client.WebExperience')
        $ctx.Appx.Seed($appx, $appx)
        $ctx.Edge.EdgeVersion = '131.0.2903.70'
        $ctx.Edge.WebView2Version = '131.0.2903.70'
        # Faz 6: görev çubuğu, hesap resimleri, Not Defteri, Gezgin taklidi.
        Initialize-FakeShellState -Ctx $ctx
        # Faz 7: koşullu tweak'ler bu makinede uygulanabilir olsun (Home sürüm, NVIDIA + Intel ekran kartlı dizüstü).
        $ctx.SystemInfo.Laptop = $true
        $ctx.SystemInfo.Nvidia = $true
        $ctx.SystemInfo.Amd = $true
        $ctx.SystemInfo.Intel = $true
        $ctx.SystemInfo.Edition = 'Core'
        $ctx.Registry.Seed("$script:GpuClass\0000", 'ProviderName', 'NVIDIA', 'String')
        $ctx.Registry.Seed("$script:GpuClass\0001", 'ProviderName', 'Intel Corporation', 'String')
        $ctx.Registry.Seed("$script:GpuClass\Configuration", 'Reset', 0, 'DWord')
        Initialize-Faz7BState -Ctx $ctx
        $ctx.Prompt.Enqueue([string[]]@('Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y', 'Y'))
        return $ctx
    }

    # Faz 7 (B): Ultimate planı etkin, Balanced varsayılanları, AMD bağdaştırıcısı (UMD / power_v1), NVIDIA FTS, Store ayarları.
    function Initialize-Faz7BState([ExecutionContext] $Ctx) {
        $ultimate = '99999999-9999-9999-9999-999999999999'
        $Ctx.Power.Schemes[$ultimate] = @{}
        $Ctx.Power.Active = $ultimate
        foreach ($row in @(
                @('SUB_PROCESSOR', 'PROCTHROTTLEMIN', 5, 5), @('SUB_PROCESSOR', 'PROCTHROTTLEMAX', 100, 100), @('SUB_PROCESSOR', 'CPMINCORES', 10, 10),
                @('SUB_PROCESSOR', 'SYSCOOLPOL', 1, 0), @('2a737441-1930-4402-8d77-b2bebba308a3', '48e6b7a6-50f5-4782-a5d4-53bb8f07e226', 1, 1),
                @('SUB_PCIEXPRESS', 'ASPM', 1, 2), @('SUB_DISK', 'DISKIDLE', 1200, 600),
                @('19cbb8fa-5279-450e-9fac-8a3d5fedd0c1', '12bbebe6-58d6-4636-95bb-3217ef867c1a', 0, 2),
                @('SUB_SLEEP', 'STANDBYIDLE', 1800, 900), @('SUB_SLEEP', 'HIBERNATEIDLE', 10800, 10800))) {
            $Ctx.Power.Seed('381b4222-f694-41f0-9685-ff5bb260df2e', $row[0], $row[1], $row[2], $row[3])
        }
        $Ctx.Registry.Seed("$script:GpuClass\0002", 'ProviderName', 'Advanced Micro Devices, Inc.', 'String')
        $Ctx.Registry.Seed("$script:GpuClass\0002\UMD", 'VSyncControl', [byte[]]@(0x31, 0x00), 'Binary')
        $Ctx.Registry.Seed("$script:GpuClass\0002\power_v1", 'abmlevel', [byte[]]@(0x01, 0x00, 0x00, 0x00), 'Binary')
        $Ctx.Registry.Seed('HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\FTS', 'EnableGR535', 1, 'DWord')
        $Ctx.Registry.Seed('HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters\FTS', 'EnableGR535', 1, 'DWord')
        $stamp = [System.BitConverter]::GetBytes([long]133000000000000000)
        $Ctx.AppSettings.Seed('Microsoft.WindowsStore_8wekyb3d8bbwe', 'VideoAutoplay', 100000011, [byte[]](@([byte]1) + $stamp))
        # Faz 7 (C): bekleyen güncellemeler (setup.updates-staged).
        $Ctx.Updates.Seed([string[]]@('2026-11 Toplu Güncelleştirme (KB5099999)', 'Windows Kötü Amaçlı Yazılım Temizleme Aracı'))
    }

    function New-CatalogProfile([object[]] $Tweaks) {
        return [Profile]::FromHashtable(@{ name = 'katalog'; tweaks = @($Tweaks) }, 'test')
    }

    function Get-State([ExecutionContext] $Ctx) {
        $apps = @(foreach ($pk in @($Ctx.AppSettings.Packages.Keys | Sort-Object)) {
                foreach ($v in @($Ctx.AppSettings.Packages[$pk].Values | Sort-Object { $_['Name'] })) { '{0}|{1}|{2}|{3}' -f $pk, $v['Name'], $v['Type'], [Convert]::ToBase64String([byte[]]$v['Data']) }
            })
        return (@($Ctx.Registry.Dump()) + @($Ctx.Services.Dump()) + @($Ctx.Tasks.Tasks.Keys | Sort-Object | ForEach-Object { "$_=$($Ctx.Tasks.Tasks[$_])" }) + @('ses=' + $Ctx.Audio.Volume) +
            @($Ctx.Files.Dump()) + $apps + @($Ctx.Power.Dump()) + @($Ctx.MemoryAgent.Dump()) + @($Ctx.Tasks.Commands.Keys | Sort-Object)) -join "`n"
    }
}

Describe 'Tweak kataloğu (tweaks/)' {
    It 'Faz 3 tweakleri katalogda' {
        foreach ($id in @('sound.startup-sound-off', 'sound.volume', 'privacy.telemetry', 'privacy.app-permissions',
                'privacy.search-ads', 'ui.explorer', 'ui.visual-effects', 'ui.notifications')) {
            $script:Catalog.ContainsKey($id) | Should -BeTrue -Because $id
        }
    }

    It 'dosya yolu kimlikle uyumlu: tweaks/<Category>/<ad>.psd1, Id = <Category>.<ad>' {
        foreach ($f in Get-ChildItem -LiteralPath $script:TweakRoot -Recurse -File -Filter '*.psd1') {
            $data = Import-PowerShellDataFile -LiteralPath $f.FullName
            $data['Category'] | Should -Be $f.Directory.Name -Because $f.FullName
            $data['Id'] | Should -Be ('{0}.{1}' -f $f.Directory.Name, $f.BaseName) -Because $f.FullName
        }
    }

    It 'her tweak açıklamalı ve başlıklı' {
        foreach ($id in $script:Ids) {
            $script:Catalog[$id].Description.Length | Should -BeGreaterThan 60 -Because $id
            $script:Catalog[$id].Title | Should -Not -BeNullOrEmpty
        }
    }

    It 'açık repo: tweak dosyalarında kişisel yol / kullanıcı adı yok' {
        foreach ($f in Get-ChildItem -LiteralPath $script:TweakRoot -Recurse -File -Filter '*.psd1') {
            $text = Get-Content -LiteralPath $f.FullName -Raw
            $text | Should -Not -Match '(?i)[a-z]:\\Users\\' -Because $f.Name
            $text | Should -Not -Match '(?i)HKU:\\S-1-5-21' -Because $f.Name
        }
    }

    It 'privacy.telemetry açıklaması sürüm farkını anlatır' {
        $d = $script:Catalog['privacy.telemetry'].Description
        $d | Should -Match 'Enterprise'
        $d | Should -Match 'Home'
        $d | Should -Match 'Pro'
    }

    It 'privacy.app-permissions kamera ve mikrofonu kapatmaz' {
        foreach ($a in $script:Catalog['privacy.app-permissions'].Actions) {
            if ($a.Definition['Path'] -match '\\(webcam|microphone)$') { $a.Definition['Value'] | Should -Be 'Allow' }
        }
    }
}

Describe 'Katalog dry-run raporu' {
    BeforeAll {
        $script:DryCtx = New-SeededContext -DryRun
        $script:DryReport = Invoke-FaiEngine -Profile (New-CatalogProfile $script:Ids) -Context $script:DryCtx -Catalog $script:Catalog
    }

    It 'hiçbir sağlayıcıya yazmaz' {
        Get-FakeWriteCount $script:DryCtx | Should -Be 0
    }

    It 'araç tweak''leri profille çalışmaz: atlanır' {
        $script:ToolIds | Should -Contain 'refresh.reboot-to-bios'
        foreach ($id in $script:ToolIds) { $script:DryReport.Find($id).Status | Should -Be 'Skipped' -Because $id }
    }

    It 'P0 tweak''i yalnız NVIDIA sınıf anahtarına yazar, onay her çalıştırmada' {
        $line = @($script:DryReport.Find('graphics.p0-state').Lines)[0]
        $line | Should -Match 'will change 1 subkeys: 0000\]'
        $script:DryReport.Find('graphics.p0-state').Reason | Should -Match 'confirm'
    }

    It 'her tweak ÖNİZLEME ve en az bir okunabilir değişiklik satırı' {
        foreach ($id in @($script:Ids | Where-Object { $script:ToolIds -notcontains $_ })) {
            $item = $script:DryReport.Find($id)
            $item | Should -Not -BeNullOrEmpty -Because $id
            $item.Status | Should -Be 'Planned' -Because "$id ($($item.Reason))"
            @($item.Lines).Count | Should -BeGreaterThan 0 -Because $id
            foreach ($l in $item.Lines) { $l | Should -Match '\S' }
        }
    }

    It 'rapor metni değişikliği ve şu anki değeri gösterir' {
        $text = $script:DryReport.Render()
        $text | Should -Match 'DisableStartupSound = 1 \(DWord\) \[current: none\]'
        $text | Should -Match 'Service: DiagTrack'
        $text | Should -Match 'Ses'
    }

    It 'bildirimlerde istisnalar ve güvenlik gönderenleri değişecekler listesinde yok' {
        $line = @($script:DryReport.Find('ui.notifications').Lines | Where-Object { $_ -match 'will change' })[0]
        $line | Should -Match 'Logi\.GHUB\.Systray'
        $line | Should -Match 'Discord\.Discord'
        $line | Should -Not -Match 'WhatsAppDesktop'
        $line | Should -Not -Match 'TelegramDesktop'
        $line | Should -Not -Match 'SecurityCenter'
    }
}

Describe 'Katalog: uygula → geri al' {
    It 'bütün katalog uygulanır, ikinci çalıştırma ZATEN UYGUN, -Undo başlangıç durumunu birebir getirir' {
        $ctx = New-SeededContext
        $before = Get-State $ctx
        $profileAll = New-CatalogProfile $script:RepeatIds

        $r = Invoke-FaiEngine -Profile $profileAll -Context $ctx -Catalog $script:Catalog
        $r.HasFailures() | Should -BeFalse -Because ($r.Render())
        $r.Count('Applied') | Should -Be $script:RepeatIds.Count
        $ctx.Registry.GetValue("$script:GpuClass\0000", 'DisableDynamicPstate') | Should -Be 1
        $ctx.Registry.ValueExists("$script:GpuClass\0001", 'DisableDynamicPstate') | Should -BeFalse
        $ctx.Registry.ValueExists("$script:GpuClass\Configuration", 'DisableDynamicPstate') | Should -BeFalse

        $ctx.Registry.GetValue("$script:NotifRoot\Logi.GHUB.Systray", 'Enabled') | Should -Be 0
        $ctx.Registry.GetValue("$script:NotifRoot\Discord.Discord", 'Enabled') | Should -Be 0
        $ctx.Registry.ValueExists("$script:NotifRoot\5319275A.WhatsAppDesktop_cv1g1gvanyjgm!App", 'Enabled') | Should -BeFalse
        $ctx.Registry.ValueExists("$script:NotifRoot\Windows.Defender.SecurityCenter", 'Enabled') | Should -BeFalse
        $ctx.Services.GetStartType('DiagTrack') | Should -Be 'Disabled'
        $ctx.Audio.GetVolume() | Should -Be 15

        $again = Invoke-FaiEngine -Profile $profileAll -Context $ctx -Catalog $script:Catalog
        $again.Count('UpToDate') | Should -Be $script:RepeatIds.Count -Because ($again.Render())

        $u = Invoke-FaiEngine -Undo -Context $ctx -Catalog $script:Catalog
        $u.HasFailures() | Should -BeFalse -Because ($u.Render())
        Get-State $ctx | Should -Be $before
    }

    It 'tek seferlik tweak''ler: geri yükleme noktası ilk adım, sürüm sayfası açılır, BIOS yalnız AllowTools ile' {
        $ctx = New-SeededContext
        $ctx.SystemControl.RestoreEnabled = $false
        $p = [Profile]::FromHashtable(@{ name = 'tek'; tweaks = @('setup.edition-pro', 'refresh.reboot-to-bios', 'system.restore-point'); apps = @() }, 'test')
        $r = Invoke-FaiEngine -Profile $p -Context $ctx -Catalog $script:Catalog
        $r.HasFailures() | Should -BeFalse -Because ($r.Render())
        $r.Items[0].TweakId | Should -Be 'system.restore-point'
        $r.Find('system.restore-point').Status | Should -Be 'Applied'
        $ctx.SystemControl.RestoreEnabled | Should -BeTrue
        @($ctx.SystemControl.RestorePoints) | Should -Be @('FAI_WinOP')
        $r.Find('setup.edition-pro').Status | Should -Be 'Applied'
        @($ctx.Shell.Opened) | Should -Contain 'ms-settings:activation'
        $r.Find('refresh.reboot-to-bios').Status | Should -Be 'Skipped'
        $ctx.SystemControl.Restarts.Count | Should -Be 0

        $again = Invoke-FaiEngine -Profile $p -Context $ctx -Catalog $script:Catalog
        $again.Find('system.restore-point').Status | Should -Be 'Applied'
        $ctx.SystemControl.RestorePoints.Count | Should -Be 2

        $tool = Invoke-FaiEngine -Profile ([Profile]::FromHashtable(@{ name = 'arac'; tweaks = @('refresh.reboot-to-bios') }, 'test')) -Context $ctx -Catalog $script:Catalog -AllowTools
        $tool.Find('refresh.reboot-to-bios').Status | Should -Be 'Applied' -Because ($tool.Render())
        @($ctx.SystemControl.Restarts) | Should -Be @(10)

        $u = Invoke-FaiEngine -Undo -Context $ctx -Catalog $script:Catalog
        $u.HasFailures() | Should -BeFalse -Because ($u.Render())
    }

    It 'sürüm Pro ise edition-pro atlanır; etkileşimsiz kipte hata verir' {
        $ctx = New-SeededContext
        $ctx.SystemInfo.Edition = 'Pro'
        $r = Invoke-FaiEngine -Profile (New-CatalogProfile @('setup.edition-pro')) -Context $ctx -Catalog $script:Catalog
        $r.Find('setup.edition-pro').Status | Should -Be 'Skipped'
        $ctx2 = New-SeededContext
        $ctx2.Unattended = $true
        $p = [Profile]::FromHashtable(@{ name = 'u'; tweaks = @('setup.edition-pro'); autoConfirm = @('setup.edition-pro') }, 'test')
        $r2 = Invoke-FaiEngine -Profile $p -Context $ctx2 -Catalog $script:Catalog
        $r2.Find('setup.edition-pro').Status | Should -Be 'Failed'
        $r2.Find('setup.edition-pro').Reason | Should -Match 'Needs interaction'
    }

    It 'profil parametreleri: ses seviyesi ve bildirim istisnaları geçersiz kılınır' {
        $ctx = New-SeededContext
        $p = New-CatalogProfile @(
            @{ id = 'sound.volume'; params = @{ level = 40 } }
            @{ id = 'ui.notifications'; params = @{ exceptions = @('Discord*') } }
        )
        $r = Invoke-FaiEngine -Profile $p -Context $ctx -Catalog $script:Catalog
        $r.HasFailures() | Should -BeFalse -Because ($r.Render())
        $ctx.Audio.GetVolume() | Should -Be 40
        $ctx.Registry.GetValue("$script:NotifRoot\Discord.Discord", 'Enabled') | Should -Be 1
        $ctx.Registry.GetValue("$script:NotifRoot\5319275A.WhatsAppDesktop_cv1g1gvanyjgm!App", 'Enabled') | Should -Be 0
    }
}

Describe 'power.plan (Faz 7 kabulü)' {
    It 'dizüstü: kendi plan etkin, prizde uyku yok, pilde uyku ve hazırda bekletme açık; -Undo eski plana döner, plan silinir' {
        $ctx = New-SeededContext
        $plan = '46414900-5769-4e4f-9000-000000000001'
        $r = Invoke-FaiEngine -Profile (New-CatalogProfile @('power.plan')) -Context $ctx -Catalog $script:Catalog
        $r.HasFailures() | Should -BeFalse -Because ($r.Render())
        $ctx.Power.Active | Should -Be $plan
        $ctx.Power.Names[$plan] | Should -Be 'FAI_WinOP'
        $ctx.Power.GetValue($plan, 'SUB_SLEEP', 'STANDBYIDLE', $true) | Should -Be 0
        $ctx.Power.GetValue($plan, 'SUB_SLEEP', 'STANDBYIDLE', $false) | Should -BeGreaterThan 0
        $ctx.Power.GetValue($plan, 'SUB_SLEEP', 'HIBERNATEIDLE', $false) | Should -BeGreaterThan 0
        $ctx.Power.GetValue($plan, 'SUB_PROCESSOR', 'PROCTHROTTLEMIN', $true) | Should -Be 100
        $ctx.Power.GetValue($plan, 'SUB_PROCESSOR', 'PROCTHROTTLEMIN', $false) | Should -Be 5 -Because 'pilde Balanced varsayılanı kalır'
        $ctx.Power.GetHibernate() | Should -BeTrue

        $u = Invoke-FaiEngine -Undo -Context $ctx -Catalog $script:Catalog
        $u.HasFailures() | Should -BeFalse -Because ($u.Render())
        $ctx.Power.Active | Should -Be '99999999-9999-9999-9999-999999999999'
        $ctx.Power.ResolveScheme($plan) | Should -BeNullOrEmpty
        $ctx.Power.GetHibernate() | Should -BeFalse
    }

    It 'masaüstü: hazırda bekletme eylemi atlanır, plan yine kurulur; parametreler saniye' {
        $ctx = New-SeededContext
        $ctx.SystemInfo.Laptop = $false
        $p = New-CatalogProfile @(@{ id = 'power.plan'; params = @{ sleepOnBatterySec = 600 } })
        $r = Invoke-FaiEngine -Profile $p -Context $ctx -Catalog $script:Catalog
        $r.HasFailures() | Should -BeFalse -Because ($r.Render())
        $ctx.Power.GetHibernate() | Should -BeFalse
        $ctx.Power.GetValue('46414900-5769-4e4f-9000-000000000001', 'SUB_SLEEP', 'STANDBYIDLE', $false) | Should -Be 600
        @($ctx.Power.WriteLog | Where-Object { $_ -like 'SetHibernate*' }).Count | Should -Be 0
    }
}

Describe 'Faz 7 (B) tweak''leri' {
    It 'AMD ayarları yalnız AMD bağdaştırıcısına; NVIDIA FTS yalnız var olan anahtara; arka plan istisnası; Store alt anahtarı' {
        $ctx = New-SeededContext
        $ids = @('graphics.amd-settings', 'graphics.nvidia-settings', 'setup.background-apps-off', 'setup.store-optimize', 'setup.mmagent-off')
        $r = Invoke-FaiEngine -Profile (New-CatalogProfile $ids) -Context $ctx -Catalog $script:Catalog
        $r.HasFailures() | Should -BeFalse -Because ($r.Render())
        $ctx.Registry.GetValue("$script:GpuClass\0002", 'KMD_DeLagEnabled') | Should -Be 1
        $ctx.Registry.ValueExists("$script:GpuClass\0000", 'KMD_DeLagEnabled') | Should -BeFalse
        ([byte[]]$ctx.Registry.GetValue("$script:GpuClass\0002\UMD", 'VSyncControl')) | Should -Be @(0x30, 0x00)
        ([byte[]]$ctx.Registry.GetValue("$script:GpuClass\0002\power_v1", 'abmlevel')) | Should -Be @(0, 0, 0, 0)
        $ctx.Registry.KeyExists("$script:GpuClass\0001\UMD") | Should -BeFalse
        $ctx.Registry.GetValue('HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters\FTS', 'EnableGR535') | Should -Be 0
        @($ctx.Registry.GetValue('HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy', 'LetAppsRunInBackground_ForceAllowTheseApps')) | Should -Be @('5319275A.WhatsAppDesktop_cv1g1gvanyjgm')
        $ctx.AppSettings.GetValue('Microsoft.WindowsStore_8wekyb3d8bbwe', 'PersistentSettings\PersonalizationEnabled') | Should -Not -BeNullOrEmpty
        $ctx.MemoryAgent.Features['MemoryCompression'] | Should -BeFalse
        $ctx.MemoryAgent.Features['PageCombining'] | Should -BeTrue
    }

    It 'NVIDIA sürücüsü yoksa (FTS anahtarı yok) hata yok, anahtar oluşturulmaz; az RAM''de mmagent atlanır' {
        $ctx = New-FakeContext -BackupRoot (Join-Path $TestDrive 'nofts')
        $ctx.SystemInfo.Nvidia = $true
        $ctx.SystemInfo.RamGB = 8
        $r = Invoke-FaiEngine -Profile (New-CatalogProfile @('graphics.nvidia-settings', 'setup.mmagent-off')) -Context $ctx -Catalog $script:Catalog
        $r.HasFailures() | Should -BeFalse -Because ($r.Render())
        $ctx.Registry.KeyExists('HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm') | Should -BeFalse
        $r.Find('setup.mmagent-off').Status | Should -Be 'Skipped'
    }
}

Describe 'docs/TWEAKS.md' {
    It 'katalogdaki her tweak belgede' {
        $doc = Get-Content -LiteralPath (Join-Path $script:FaiRepoRoot 'docs/TWEAKS.md') -Raw
        foreach ($id in $script:Ids) { $doc | Should -Match ('### ' + [regex]::Escape($id)) -Because 'build/TweaksDoc.ps1 çalıştırılmalı' }
    }
}
