#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }
# Faz 4: uygulama kataloğu (apps/catalog.json), profil 'apps', App eylemi (kurulum + otomatik başlatma / masaüstü /
# Başlat düzeni + günlüklü geri alma) ve DefaultBrowser eylemi. Hepsi Fake sağlayıcılara karşı.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Load-Fakes.ps1')
    $script:Seq = 0
    $script:UserDesktop = 'C:\Users\fai\Desktop'
    $script:PublicDesktop = 'C:\Users\Public\Desktop'
    $script:UserPrograms = 'C:\Users\fai\AppData\Roaming\Microsoft\Windows\Start Menu\Programs'
    $script:CommonPrograms = 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs'
    $script:UserStartup = "$script:UserPrograms\Startup"
    $script:Approved = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
    $script:ApprovedLM = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
    $script:RunCU = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    $script:RunLM32 = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
    $script:Choice = 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https'

    $script:TestCatalogJson = @'
{ "apps": [
  { "id": "spotify", "name": "Spotify", "source": "winget", "packageId": "Spotify.Spotify",
    "postInstall": { "removeAutostart": true, "startupRegistryNames": ["Spotify"],
                     "removeDesktopShortcut": true, "desktopShortcutNames": ["Spotify.lnk"],
                     "flattenStartMenu": true, "startMenuFolders": ["Spotify"] } },
  { "id": "steam", "name": "Steam", "source": "winget", "packageId": "Valve.Steam",
    "postInstall": { "removeAutostart": true, "startupRegistryNames": ["Steam*"], "startupFolderNames": ["Steam.lnk"],
                     "startupTaskNames": ["\\Valve\\SteamLogon"],
                     "removeDesktopShortcut": true, "desktopShortcutNames": ["Steam.lnk"] } },
  { "id": "whatsapp", "name": "WhatsApp", "source": "msstore", "packageId": "9NKSQGP7F2NH",
    "postInstall": { "removeDesktopShortcut": true } }
] }
'@
    $script:AppCatalog = @{}
    foreach ($a in (ConvertFrom-JsonText $script:TestCatalogJson)['apps']) { $script:AppCatalog[[string]$a['id']] = $a }

    function New-AppContext([switch] $DryRun, [switch] $Unattended) {
        $script:Seq++
        $ctx = New-FakeContext -BackupRoot (Join-Path $TestDrive ('a{0}' -f $script:Seq)) -DryRun:$DryRun -Unattended:$Unattended
        # Kullanıcının kendi kısayolu: hiçbir koşulda silinmemeli.
        $ctx.Files.SeedText("$script:UserDesktop\Benim.lnk", 'kullanici')
        return $ctx
    }

    # Spotify kurucusunu taklit eder: ortak + kullanıcı masaüstüne kısayol, Run değeri, Başlat klasörü.
    function Register-SpotifyInstaller([ExecutionContext] $Ctx) {
        $files = $Ctx.Files
        $reg = $Ctx.Registry
        $runCU = $script:RunCU
        $up = $script:UserPrograms
        $ud = $script:UserDesktop
        $Ctx.Packages.OnInstall['winget:spotify.spotify'] = {
            $files.SeedText("$ud\Spotify.lnk", 'spotify-lnk')
            $files.SeedText("$ud\Spotify Premium.lnk", 'reklam-lnk')
            $files.SeedText("$up\Spotify\Spotify.lnk", 'spotify-start')
            $files.SeedText("$up\Spotify\Uninstall Spotify.lnk", 'uninstall')
            $files.SeedText("$up\Spotify\Destek.url", 'url')
            $reg.Seed($runCU, 'Spotify', 'C:\Spotify\Spotify.exe /minimized', 'String')
        }.GetNewClosure()
        $Ctx.Packages.OnUninstall['winget:spotify.spotify'] = {
            foreach ($f in @("$ud\Spotify.lnk", "$ud\Spotify Premium.lnk", "$up\Spotify\Spotify.lnk", "$up\Spotify\Uninstall Spotify.lnk", "$up\Spotify\Destek.url")) {
                $files.DeleteFile($f)
            }
            $reg.DeleteValue($runCU, 'Spotify')
        }.GetNewClosure()
    }

    function Get-AppState([ExecutionContext] $Ctx) {
        $pk = @($Ctx.Packages.Packages.Keys | Sort-Object)
        $tasks = @($Ctx.Tasks.Tasks.Keys | Sort-Object | ForEach-Object { "$_=$($Ctx.Tasks.Tasks[$_])" })
        return ((@($Ctx.Registry.Dump()) + @($Ctx.Files.Dump()) + $pk + $tasks) -join "`n")
    }

    function New-AppProfile([object[]] $Apps, [object[]] $Tweaks = @()) {
        return [Profile]::FromHashtable(@{ name = 'uygulama'; tweaks = @($Tweaks); apps = @($Apps) }, 'test')
    }

    function Test-HasError([string[]] $Errors, [string] $Prefix) {
        return [bool](@($Errors | Where-Object { $_.StartsWith($Prefix) }).Count -gt 0)
    }
}

Describe 'apps/catalog.json' {
    BeforeAll {
        $script:CatalogPath = Join-Path $script:FaiRepoRoot 'apps/catalog.json'
        $script:RealCatalog = Import-FaiAppCatalog -Path $script:CatalogPath
    }

    It 'şemadan geçer ve 3.2''deki 12 uygulamayı doğrulanmış kimlikleriyle içerir' {
        $expected = @{
            claude = 'Anthropic.Claude'; telegram = 'Telegram.TelegramDesktop'; whatsapp = '9NKSQGP7F2NH'
            discord = 'Discord.Discord'; steam = 'Valve.Steam'; tradingview = 'TradingView.TradingViewDesktop'
            ollama = 'Ollama.Ollama'; vscode = 'Microsoft.VisualStudioCode'; protonvpn = 'Proton.ProtonVPN'
            chrome = 'Google.Chrome'; spotify = 'Spotify.Spotify'; obs = 'OBSProject.OBSStudio'
        }
        foreach ($id in $expected.Keys) {
            $script:RealCatalog.ContainsKey($id) | Should -BeTrue -Because $id
            $script:RealCatalog[$id]['packageId'] | Should -BeExactly $expected[$id]
        }
        $script:RealCatalog['whatsapp']['source'] | Should -Be 'msstore'
    }

    It 'her uygulama tweak''e dönüşür (app.<id>, Safe, tek App eylemi)' {
        foreach ($id in $script:RealCatalog.Keys) {
            $t = ConvertTo-FaiAppTweak -App $script:RealCatalog[$id]
            $t.Id | Should -Be "app.$id"
            $t.Risk | Should -Be 'Safe'
            $t.Actions.Count | Should -Be 1
            $t.Actions[0].Type | Should -Be 'App'
        }
    }

    It 'açık repo: kişisel yol / e-posta yok' {
        $text = Get-Content -LiteralPath $script:CatalogPath -Raw
        $text | Should -Not -Match '(?i)C:\\\\Users\\\\'
        $text | Should -Not -Match '[\w.+-]+@[\w-]+\.[\w.]+'
    }

    It 'apps/_schema.json alan adları doğrulayıcıyla birebir aynı' {
        $schema = Read-JsonFile (Join-Path $script:FaiRepoRoot 'apps/_schema.json')
        $item = $schema['properties']['apps']['items']
        (@($item['properties'].Keys | Sort-Object) -join ',') | Should -Be (@(Get-FaiAppKey | Sort-Object) -join ',')
        (@($item['properties']['postInstall']['properties'].Keys | Sort-Object) -join ',') | Should -Be (@(Get-FaiAppPostInstallKey | Sort-Object) -join ',')
    }
}

Describe 'Get-FaiAppCatalogError' {
    It 'hataları alan yoluyla listeler' {
        $bad = ConvertFrom-JsonText @'
{ "apps": [
  { "id": "Büyük", "name": "x", "source": "apt", "packageId": "A.B", "extra": 1 },
  { "id": "ok", "name": "", "source": "winget", "packageId": "a.b",
    "postInstall": { "removeAutostart": "evet", "desktopShortcutNames": ["Kisayol"], "startupFolderNames": ["x.exe"],
                     "startupRegistryNames": ["a.lnk"], "bilinmeyen": true } },
  { "id": "ok", "name": "y", "source": "winget", "packageId": "C D" }
] }
'@
        $e = @(Get-FaiAppCatalogError $bad)
        Test-HasError $e 'apps[0].extra: bilinmeyen alan' | Should -BeTrue -Because ($e -join '; ')
        Test-HasError $e 'apps[0].id:' | Should -BeTrue
        Test-HasError $e 'apps[0].source: winget ya da msstore' | Should -BeTrue
        Test-HasError $e 'apps[1].name: boş olmayan metin' | Should -BeTrue
        Test-HasError $e 'apps[1].packageId: ''a.b'' başka uygulamada da var' | Should -BeTrue
        Test-HasError $e 'apps[1].postInstall.removeAutostart: true ya da false' | Should -BeTrue
        Test-HasError $e 'apps[1].postInstall.bilinmeyen: bilinmeyen alan' | Should -BeTrue
        Test-HasError $e 'apps[1].postInstall.startupFolderNames[0]: .lnk' | Should -BeTrue
        Test-HasError $e 'apps[1].postInstall.startupRegistryNames[0]: Run değeri' | Should -BeTrue
        Test-HasError $e 'apps[2].id: ''ok'' birden çok kez' | Should -BeTrue
        Test-HasError $e 'apps[2].packageId: paket kimliği' | Should -BeTrue
    }

    It 'eylem düzeyi kuralları (kısayol adı, görev yolu, klasör adı) da denetlenir' {
        $bad = ConvertFrom-JsonText @'
{ "apps": [ { "id": "a", "name": "A", "source": "winget", "packageId": "A.A",
  "postInstall": { "removeAutostart": true, "startupTaskNames": ["Gorev"],
                   "removeDesktopShortcut": true, "desktopShortcutNames": ["*.lnk"],
                   "flattenStartMenu": true, "startMenuFolders": ["..\\Sistem"] } } ] }
'@
        $e = @(Get-FaiAppCatalogError $bad)
        ($e -join "`n") | Should -Match 'DisableTasks\[0\]: görev yolu'
        ($e -join "`n") | Should -Match 'RemoveShortcuts\[0\]: joker'
        ($e -join "`n") | Should -Match 'FlattenFolders\[0\]: joker ve yol'
    }

    It 'kök ve apps biçimi' {
        @(Get-FaiAppCatalogError (ConvertFrom-JsonText '[1]'))[0] | Should -Match '^\(kök\)'
        Test-HasError @(Get-FaiAppCatalogError @{ }) 'apps: zorunlu' | Should -BeTrue
        Test-HasError @(Get-FaiAppCatalogError @{ apps = 'x' }) 'apps: dizi' | Should -BeTrue
    }
}

Describe 'Profil apps' {
    It 'metin ve { id, keepAutostart } kabul edilir, sıra korunur' {
        $p = [Profile]::FromHashtable((ConvertFrom-JsonText '{"name":"p","tweaks":[],"apps":["chrome",{"id":"telegram","keepAutostart":true}]}'), 'test')
        $p.Apps.Count | Should -Be 2
        $p.Apps[0]['Id'] | Should -Be 'chrome'
        $p.Apps[0]['KeepAutostart'] | Should -BeFalse
        $p.Apps[1]['Id'] | Should -Be 'telegram'
        $p.Apps[1]['KeepAutostart'] | Should -BeTrue
    }

    It 'geçersiz girdiler alan yoluyla raporlanır' {
        $e = @(Get-FaiProfileError (ConvertFrom-JsonText '{"name":"p","tweaks":[],"apps":["Chrome","a","a",{"id":"b","keepAutostart":"evet","x":1},{"keep":true},3]}'))
        Test-HasError $e 'apps[0]: ''Chrome'' geçerli bir uygulama kimliği değil' | Should -BeTrue -Because ($e -join '; ')
        Test-HasError $e 'apps[2]: ''a'' birden çok kez' | Should -BeTrue
        Test-HasError $e 'apps[3].keepAutostart: true ya da false' | Should -BeTrue
        Test-HasError $e 'apps[3].x: bilinmeyen alan' | Should -BeTrue
        Test-HasError $e 'apps[4].id: zorunlu alan eksik' | Should -BeTrue
        Test-HasError $e 'apps[5]: uygulama kimliği' | Should -BeTrue
    }
}

Describe 'App eylemi: temiz kurulum' {
    It 'kurar; yeni masaüstü kısayollarını siler, otomatik başlatmayı kapatır, Başlat klasörünü düzleştirir; -Undo başlangıca döner' {
        $ctx = New-AppContext
        Register-SpotifyInstaller $ctx
        $before = Get-AppState $ctx

        $r = Invoke-FaiEngine -Profile (New-AppProfile @('spotify')) -Context $ctx -Catalog @{} -AppCatalog $script:AppCatalog
        $r.HasFailures() | Should -BeFalse -Because ($r.Render())
        $r.Count('Applied') | Should -Be 1

        $ctx.Packages.IsInstalled('Spotify.Spotify', 'winget') | Should -BeTrue
        # masaüstü: kurucunun bıraktığı iki kısayol (biri adı katalogda olmayan) gitti, kullanıcınınki kaldı
        @($ctx.Files.ListFiles($script:UserDesktop)) | Should -Be @("$script:UserDesktop\Benim.lnk")
        # Run değeri silinmez; StartupApproved'da kapalı
        $ctx.Registry.ValueExists($script:RunCU, 'Spotify') | Should -BeTrue
        $mark = [byte[]]$ctx.Registry.GetValue("$script:Approved\Run", 'Spotify')
        $mark[0] | Should -Be 3
        # Başlat: kısayol köke, kaldırma kısayolu ve .url silindi
        [System.Text.Encoding]::UTF8.GetString($ctx.Files.ReadBytes("$script:UserPrograms\Spotify.lnk")) | Should -Be 'spotify-start'
        @($ctx.Files.ListFiles("$script:UserPrograms\Spotify")).Count | Should -Be 0
        $ctx.Files.WriteLog | Should -Contain "DeleteEmptyDirectory $script:UserPrograms\Spotify"

        $again = Invoke-FaiEngine -Profile (New-AppProfile @('spotify')) -Context $ctx -Catalog @{} -AppCatalog $script:AppCatalog
        $again.Count('UpToDate') | Should -Be 1 -Because ($again.Render())

        $u = Invoke-FaiEngine -Undo -Context $ctx -Catalog @{}
        $u.HasFailures() | Should -BeFalse -Because ($u.Render())
        $ctx.Packages.IsInstalled('Spotify.Spotify', 'winget') | Should -BeFalse
        # taşınan kısayol ve StartupApproved değeri geri alındı; kurucunun dosyalarını kaldırıcı sildi
        $ctx.Files.FileExists("$script:UserPrograms\Spotify.lnk") | Should -BeFalse
        $ctx.Registry.ValueExists("$script:Approved\Run", 'Spotify') | Should -BeFalse
        Get-AppState $ctx | Should -Be $before
    }

    It 'günlük oturum dosyasına yazılır (Apply sonrası yeniden kayıt)' {
        $ctx = New-AppContext
        Register-SpotifyInstaller $ctx
        [void](Invoke-FaiEngine -Profile (New-AppProfile @('spotify')) -Context $ctx -Catalog @{} -AppCatalog $script:AppCatalog)
        $sess = $ctx.Backup.GetLatest()
        $snap = [hashtable]$sess.Entries[0]['Snapshot']
        $snap['Installed'] | Should -BeFalse
        @($snap['Journal']).Count | Should -BeGreaterThan 4
        @($snap['Journal'] | Where-Object { $_['Kind'] -eq 'Value' }).Count | Should -Be 1
    }
}

Describe 'App eylemi: kurulu uygulama' {
    It 'kalıntıları temizler (HKLM Run32, Başlangıç klasörü, görev, ortak masaüstü); -Undo birebir geri getirir, kaldırmaz' {
        $ctx = New-AppContext
        $ctx.Packages.Seed('Valve.Steam', 'winget')
        $ctx.Files.SeedText("$script:PublicDesktop\Steam.lnk", 'steam-ortak')
        $ctx.Files.SeedText("$script:UserStartup\Steam.lnk", 'steam-baslangic')
        $ctx.Registry.Seed($script:RunLM32, 'SteamService', 'C:\Steam\steam.exe -silent', 'String')
        $ctx.Registry.Seed("$script:ApprovedLM\Run32", 'SteamService', [byte[]](2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), 'Binary')
        $ctx.Tasks.Seed('\Valve\SteamLogon', 'Enabled')
        $before = Get-AppState $ctx

        $r = Invoke-FaiEngine -Profile (New-AppProfile @('steam')) -Context $ctx -Catalog @{} -AppCatalog $script:AppCatalog
        $r.HasFailures() | Should -BeFalse -Because ($r.Render())
        $ctx.Packages.WriteLog.Count | Should -Be 0 -Because 'zaten kurulu'
        $ctx.Files.FileExists("$script:PublicDesktop\Steam.lnk") | Should -BeFalse
        ([byte[]]$ctx.Registry.GetValue("$script:ApprovedLM\Run32", 'SteamService'))[0] | Should -Be 3
        ([byte[]]$ctx.Registry.GetValue("$script:Approved\StartupFolder", 'Steam.lnk'))[0] | Should -Be 3
        $ctx.Tasks.GetTaskState('\Valve\SteamLogon') | Should -Be 'Disabled'
        $ctx.Files.FileExists("$script:UserStartup\Steam.lnk") | Should -BeTrue -Because 'başlangıç kısayolu silinmez, kapatılır'

        $u = Invoke-FaiEngine -Undo -Context $ctx -Catalog @{}
        $u.HasFailures() | Should -BeFalse -Because ($u.Render())
        Get-AppState $ctx | Should -Be $before
    }

    It 'keepAutostart: otomatik başlatma kurallarına dokunmaz' {
        $ctx = New-AppContext
        $ctx.Packages.Seed('Valve.Steam', 'winget')
        $ctx.Tasks.Seed('\Valve\SteamLogon', 'Enabled')
        $r = Invoke-FaiEngine -Profile (New-AppProfile @(@{ id = 'steam'; keepAutostart = $true })) -Context $ctx -Catalog @{} -AppCatalog $script:AppCatalog
        $r.Count('UpToDate') | Should -Be 1 -Because ($r.Render())
        $ctx.Tasks.GetTaskState('\Valve\SteamLogon') | Should -Be 'Enabled'
        $ctx.Registry.WriteCount | Should -Be 0
    }

    It 'jokersiz ad Run değeri yokken de önceden kapatılır; joker yalnız var olanı eşler' {
        $ctx = New-AppContext
        $ctx.Packages.Seed('Valve.Steam', 'winget')
        $act = New-FaiAction @{ Type = 'App'; Id = 'Valve.Steam'; DisableStartup = @('Steam*', 'Tam Ad') }
        $targets = @($act.StartupTargets($ctx))
        $targets.Count | Should -Be 1
        $targets[0]['Name'] | Should -Be 'Tam Ad'
        $targets[0]['Path'] | Should -Be "$script:Approved\Run"
    }
}

Describe 'App eylemi: dry-run, msstore, rapor' {
    It 'dry-run hiçbir sağlayıcıya yazmaz, ÖNİZLEME satırı kurulumu söyler' {
        $ctx = New-AppContext -DryRun
        $r = Invoke-FaiEngine -Profile (New-AppProfile @('spotify', 'whatsapp')) -Context $ctx -Catalog @{} -AppCatalog $script:AppCatalog
        Get-FakeWriteCount $ctx | Should -Be 0
        $r.Count('Planned') | Should -Be 2
        ($r.Items[0].Lines -join ' ') | Should -Match 'kurulu değil → kurulur'
        ($r.Items[1].Lines -join ' ') | Should -Match '\(msstore\): 9NKSQGP7F2NH'
    }

    It 'kurulu uygulamanın dry-run satırı somut işleri listeler' {
        $ctx = New-AppContext -DryRun
        $ctx.Packages.Seed('Spotify.Spotify', 'winget')
        $ctx.Files.SeedText("$script:UserDesktop\Spotify.lnk", 'x')
        $ctx.Files.SeedText("$script:CommonPrograms\Spotify\Spotify.lnk", 'x')
        $r = Invoke-FaiEngine -Profile (New-AppProfile @('spotify')) -Context $ctx -Catalog @{} -AppCatalog $script:AppCatalog
        $line = $r.Items[0].Lines -join ' '
        $line | Should -Match "başlangıçta kapatılır: Run 'Spotify'"
        $line | Should -Match ([regex]::Escape("silinir: $script:UserDesktop\Spotify.lnk"))
        $line | Should -Match 'düzleştirilir: .*Spotify \(1 dosya\)'
        Get-FakeWriteCount $ctx | Should -Be 0
    }

    It 'uygulamalar tweak''lerden sonra işlenir; katalogda olmayan uygulama Failed' {
        $ctx = New-AppContext
        $tweakCatalog = Import-FaiTweakCatalog -Path (Join-Path $script:FaiFixtures 'Tweaks/valid')
        $first = @($tweakCatalog.Keys)[0]
        $r = Invoke-FaiEngine -Profile (New-AppProfile @('whatsapp', 'yok') @($first)) -Context $ctx -Catalog $tweakCatalog -AppCatalog $script:AppCatalog
        $r.Items[0].TweakId | Should -Be $first
        $r.Items[1].TweakId | Should -Be 'app.whatsapp'
        $r.Items[1].Status | Should -Be 'Applied'
        $r.Items[2].TweakId | Should -Be 'app.yok'
        $r.Items[2].Status | Should -Be 'Failed'
        $r.Items[2].Reason | Should -Match 'kataloğunda yok'
        $ctx.Packages.IsInstalled('9NKSQGP7F2NH', 'msstore') | Should -BeTrue
    }
}

Describe 'DefaultBrowser eylemi' {
    BeforeAll {
        $script:Def = @{ Type = 'DefaultBrowser'; ProgId = 'ChromeHTML'; AppName = 'Google Chrome' }
    }

    It 'UserChoiceLatest öncelikli, yoksa UserChoice okunur' {
        $ctx = New-AppContext
        $act = New-FaiAction $script:Def
        [DefaultBrowserAction]::Current($ctx) | Should -Be ''
        $ctx.Registry.Seed("$script:Choice\UserChoice", 'ProgId', 'ChromeHTML', 'String')
        $act.Test($ctx) | Should -BeTrue
        $ctx.Registry.Seed("$script:Choice\UserChoiceLatest\ProgId", 'ProgId', 'MSEdgeHTM', 'String')
        $act.Test($ctx) | Should -BeFalse
    }

    It 'Ayarlar adresi uygulama adını kaçışlar, kapsamı kullanır' {
        (New-FaiAction $script:Def).SettingsUri() | Should -Be 'ms-settings:defaultapps?registeredAppMachine=Google%20Chrome'
        $userDef = $script:Def.Clone()
        $userDef['Scope'] = 'User'
        (New-FaiAction $userDef).SettingsUri() | Should -Match 'registeredAppUser='
    }

    It 'etkileşimli: sayfayı açar, kullanıcı seçince başarılı; seçmezse hata' {
        $ctx = New-AppContext
        $ctx.Registry.Seed("$script:Choice\UserChoiceLatest\ProgId", 'ProgId', 'MSEdgeHTM', 'String')
        $act = New-FaiAction $script:Def
        $ctx.Prompt.Enqueue([string[]]@('E'))
        { $act.Apply($ctx) } | Should -Throw '*değişmedi*'
        $ctx.Shell.Opened | Should -Contain 'ms-settings:defaultapps?registeredAppMachine=Google%20Chrome'

        $reg = $ctx.Registry
        $choice = $script:Choice
        $ctx.Shell.OnOpen = { $reg.Seed("$choice\UserChoiceLatest\ProgId", 'ProgId', 'ChromeHTML', 'String') }.GetNewClosure()
        $ctx.Prompt.Enqueue([string[]]@('E'))
        { $act.Apply($ctx) } | Should -Not -Throw
        $act.Test($ctx) | Should -BeTrue
    }

    It 'etkileşimsiz kipte soru sormaz, sayfayı açıp hata verir' {
        $ctx = New-AppContext -Unattended
        $act = New-FaiAction $script:Def
        { $act.Apply($ctx) } | Should -Throw '*Etkileşimsiz*'
        $ctx.Prompt.Asked.Count | Should -Be 0
        $ctx.Shell.Opened.Count | Should -Be 1
    }

    It 'geri alma programla yapılmaz: önceki farklıysa sayfa açılır, uyarı yazılır, hata yok' {
        $ctx = New-AppContext
        $ctx.Registry.Seed("$script:Choice\UserChoiceLatest\ProgId", 'ProgId', 'ChromeHTML', 'String')
        $act = New-FaiAction $script:Def
        { $act.Revert($ctx, @{ ProgId = 'MSEdgeHTM' }) } | Should -Not -Throw
        $ctx.Shell.Opened | Should -Contain 'ms-settings:defaultapps'
        $act.Revert($ctx, @{ ProgId = 'ChromeHTML' })
        $ctx.Shell.Opened.Count | Should -Be 1
    }

    It 'şema: ProgId / AppName zorunlu, Scope Machine | User' {
        $e = @(Get-FaiActionError @{ Type = 'DefaultBrowser'; ProgId = 'a b'; Scope = 'Herkes' })
        ($e -join "`n") | Should -Match 'ProgId: ProgID'
        ($e -join "`n") | Should -Match 'AppName: zorunlu'
        ($e -join "`n") | Should -Match 'Scope: Machine ya da User'
    }
}
