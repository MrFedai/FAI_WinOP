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
        $ctx.Appx.Seed([string[]]@('Microsoft.BingNews', 'Microsoft.WindowsStore'), [string[]]@('Microsoft.BingNews', 'Microsoft.WindowsStore'))
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
        $ctx.Prompt.Enqueue([string[]]@('E', 'E', 'E', 'E', 'E', 'E', 'E', 'E'))
        return $ctx
    }

    function New-CatalogProfile([object[]] $Tweaks) {
        return [Profile]::FromHashtable(@{ name = 'katalog'; tweaks = @($Tweaks) }, 'test')
    }

    function Get-State([ExecutionContext] $Ctx) {
        $apps = @(foreach ($pk in @($Ctx.AppSettings.Packages.Keys | Sort-Object)) {
                foreach ($v in @($Ctx.AppSettings.Packages[$pk].Values | Sort-Object { $_['Name'] })) { '{0}|{1}|{2}|{3}' -f $pk, $v['Name'], $v['Type'], [Convert]::ToBase64String([byte[]]$v['Data']) }
            })
        return (@($Ctx.Registry.Dump()) + @($Ctx.Services.Dump()) + @($Ctx.Tasks.Tasks.Keys | Sort-Object | ForEach-Object { "$_=$($Ctx.Tasks.Tasks[$_])" }) + @('ses=' + $Ctx.Audio.Volume) +
            @($Ctx.Files.Dump()) + $apps) -join "`n"
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
        $line | Should -Match 'değişecek 1 alt anahtar: 0000\]'
        $script:DryReport.Find('graphics.p0-state').Reason | Should -Match 'onay'
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
        $text | Should -Match 'DisableStartupSound = 1 \(DWord\) \[şu an: yok\]'
        $text | Should -Match 'Servis: DiagTrack'
        $text | Should -Match 'Ses'
    }

    It 'bildirimlerde istisnalar ve güvenlik gönderenleri değişecekler listesinde yok' {
        $line = @($script:DryReport.Find('ui.notifications').Lines | Where-Object { $_ -match 'değişecek' })[0]
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
        $r2.Find('setup.edition-pro').Reason | Should -Match 'Etkileşim gerekir'
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

Describe 'docs/TWEAKS.md' {
    It 'katalogdaki her tweak belgede' {
        $doc = Get-Content -LiteralPath (Join-Path $script:FaiRepoRoot 'docs/TWEAKS.md') -Raw
        foreach ($id in $script:Ids) { $doc | Should -Match ('### ' + [regex]::Escape($id)) -Because 'build/TweaksDoc.ps1 çalıştırılmalı' }
    }
}
