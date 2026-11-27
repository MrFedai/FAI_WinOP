#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }
# Faz 6: masaüstü ve görev çubuğu düzeni. Yeni eylemler (RegistryByte, TaskbarPins, SolidImage, AppSetting, File Base64),
# motorun kabuk yenilemesi (Refresh) ve profil düzeni: Export-FaiLayout → -Undo → profil uygula döngüsü düzeni birebir
# geri getirir (kabul kriteri). Gezgin, FakeDesktopProvider.OnRefresh ile taklit edilir (Enable-FakeShellLayout).

BeforeAll {
    . (Join-Path $PSScriptRoot 'Load-Fakes.ps1')
    # Windows ortam değişkenleri (Linux'ta tanımsız): FakeFileProvider bilinen klasörleriyle aynı.
    $script:SavedEnv = @{}
    foreach ($kv in @(@('ProgramData', 'C:\ProgramData'), @('APPDATA', 'C:\Users\fai\AppData\Roaming'), @('LOCALAPPDATA', 'C:\Users\fai\AppData\Local'), @('SystemRoot', 'C:\Windows'))) {
        $script:SavedEnv[$kv[0]] = [Environment]::GetEnvironmentVariable($kv[0])
        [Environment]::SetEnvironmentVariable($kv[0], $kv[1])
    }
    $script:Catalog = Import-FaiTweakCatalog -Path (Join-Path $script:FaiRepoRoot 'tweaks')
    $script:Seq = 0
    $script:Taskband = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband'
    $script:Policy = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'
    $script:PinDir = Expand-FaiPath '%APPDATA%\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar'
    $script:Chrome = '%ProgramData%\Microsoft\Windows\Start Menu\Programs\Google Chrome.lnk'
    $script:Notepad = 'Microsoft.WindowsNotepad_8wekyb3d8bbwe'

    function New-Ctx([switch] $DryRun) {
        $script:Seq++
        return (New-FakeContext -BackupRoot (Join-Path $TestDrive ('l{0}' -f $script:Seq)) -DryRun:$DryRun)
    }
    function New-ShellCtx([switch] $DryRun) {
        $ctx = New-Ctx -DryRun:$DryRun
        Initialize-FakeShellState -Ctx $ctx
        return $ctx
    }
    function Act([hashtable] $Def) { return (New-FaiAction -Definition $Def) }
    function Errs([hashtable] $Def) { return @(Get-FaiActionError -Definition $Def) }
    function RoundTrip([hashtable] $Snapshot) { return [hashtable](ConvertFrom-JsonText -Json ($Snapshot | ConvertTo-Json -Depth 10)) }
    function Pins([ExecutionContext] $Ctx) { return (@([TaskbarPinsAction]::Current($Ctx) | ForEach-Object { [string]$_['Label'] }) -join ',') }
    function New-Profile([hashtable] $Data) { return [Profile]::FromHashtable($Data, 'test') }

    # Düzenle ilgili durum: kayıt defteri + dosyalar (yedek oturumları hariç).
    function Get-LayoutState([ExecutionContext] $Ctx) { return ((@($Ctx.Registry.Dump()) + @($Ctx.Files.Dump())) -join "`n") }
}

AfterAll {
    foreach ($k in @($script:SavedEnv.Keys)) { [Environment]::SetEnvironmentVariable($k, $script:SavedEnv[$k]) }
}

Describe 'RegistryByteAction' {
    It 'şema: Offset, Value ve Mask denetlenir' {
        Errs @{ Type = 'RegistryByte'; Path = 'HKCU:\X'; Name = 'S'; Offset = 8; Value = 1 } | Should -BeNullOrEmpty
        Errs @{ Type = 'RegistryByte'; Path = 'HKCU:\X'; Name = 'S'; Offset = 8; Mask = 1; Value = $true } | Should -BeNullOrEmpty
        (Errs @{ Type = 'RegistryByte'; Path = 'HKCU:\X'; Name = 'S'; Value = 1 }) -join ' ' | Should -Match 'Offset: required'
        (Errs @{ Type = 'RegistryByte'; Path = 'HKCU:\X'; Name = 'S'; Offset = -1; Value = 1 }) -join ' ' | Should -Match 'Offset'
        (Errs @{ Type = 'RegistryByte'; Path = 'HKCU:\X'; Name = 'S'; Offset = 1; Value = 300 }) -join ' ' | Should -Match 'Value: must be an integer from 0 to 255'
        (Errs @{ Type = 'RegistryByte'; Path = 'X'; Name = 'S'; Offset = 1; Value = 1 }) -join ' ' | Should -Match 'Path'
    }

    It 'maskeli bit değişir, baytın ve değerin geri kalanı korunur; geri alma eski baytı yazar' {
        $ctx = New-ShellCtx
        $path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
        $before = [byte[]]$ctx.Registry.GetValue($path, 'Settings')
        $a = Act @{ Type = 'RegistryByte'; Path = $path; Name = 'Settings'; Offset = 8; Mask = 1; Value = $true }
        $a.Test($ctx) | Should -BeFalse
        $snap = RoundTrip ($a.Snapshot($ctx))
        $a.Apply($ctx)
        $after = [byte[]]$ctx.Registry.GetValue($path, 'Settings')
        $after[8] | Should -Be 0x03
        $after[12] | Should -Be 0x03
        $after.Length | Should -Be $before.Length
        $a.Test($ctx) | Should -BeTrue
        $a.Revert($ctx, $snap)
        ([byte[]]$ctx.Registry.GetValue($path, 'Settings'))[8] | Should -Be 0x02
    }

    It 'değer yoksa uygulanamaz (Windows oluşturur): Snapshot hata verir' {
        $ctx = New-Ctx
        $a = Act @{ Type = 'RegistryByte'; Path = 'HKCU:\Yok'; Name = 'Settings'; Offset = 8; Value = 3 }
        $a.Test($ctx) | Should -BeFalse
        { $a.Snapshot($ctx) } | Should -Throw '*Windows creates the value*'
        $a.Preview($ctx) | Should -Match 'current: none'
    }
}

Describe 'TaskbarPinsAction' {
    It 'şema: tek alanlı AppId / Link / Aumid' {
        Errs @{ Type = 'TaskbarPins'; Pins = @(@{ AppId = 'Microsoft.Windows.Explorer' }, @{ Link = $script:Chrome }, @{ Aumid = 'Microsoft.WindowsStore_8wekyb3d8bbwe!App' }) } | Should -BeNullOrEmpty
        Errs @{ Type = 'TaskbarPins'; Pins = @() } | Should -BeNullOrEmpty
        (Errs @{ Type = 'TaskbarPins'; Pins = @(@{ AppId = 'Chrome' }) }) -join ' ' | Should -Match 'unknown id'
        (Errs @{ Type = 'TaskbarPins'; Pins = @(@{ Link = 'C:\a.exe' }) }) -join ' ' | Should -Match '\.lnk'
        (Errs @{ Type = 'TaskbarPins'; Pins = @(@{ Aumid = 'Store' }) }) -join ' ' | Should -Match 'Aumid'
        (Errs @{ Type = 'TaskbarPins'; Pins = @(@{ Link = $script:Chrome; Aumid = 'a_0123456789abc!App' }) }) -join ' ' | Should -Match 'exactly one field'
    }

    It 'mevcut sabitlemeler Favorites sırasıyla okunur (kısayollar + Store AUMID)' {
        $ctx = New-ShellCtx
        Pins $ctx | Should -Be 'File Explorer.lnk,Microsoft Edge.lnk,Microsoft.WindowsStore_8wekyb3d8bbwe!App'
    }

    It 'uygular: yalnız istenenler kalır, ilke ve XML tek seferlik (sonra eski haline döner); geri alma birebir' {
        $ctx = New-ShellCtx
        $before = Get-LayoutState $ctx
        $a = Act @{ Type = 'TaskbarPins'; Pins = @(@{ AppId = 'Microsoft.Windows.Explorer' }, @{ Link = $script:Chrome }) }
        $a.Test($ctx) | Should -BeFalse
        $a.Preview($ctx) | Should -Match 'current: File Explorer\.lnk, Microsoft Edge\.lnk'
        $snap = RoundTrip ($a.Snapshot($ctx))
        $a.Apply($ctx)
        Pins $ctx | Should -Be 'File Explorer.lnk,Google Chrome.lnk'
        $a.Test($ctx) | Should -BeTrue
        $ctx.Registry.ValueExists($script:Policy, 'StartLayoutFile') | Should -BeFalse
        $ctx.Registry.ValueExists($script:Policy, 'LockedStartLayout') | Should -BeFalse
        $ctx.Files.FileExists((Expand-FaiPath '%ProgramData%\FAI_WinOP\shared\TaskbarLayout.xml')) | Should -BeFalse
        @($ctx.Desktop.Refreshed) | Should -Contain 'Shell'
        $a.Revert($ctx, $snap)
        Get-LayoutState $ctx | Should -Be $before
    }

    It 'XML: Store uygulaması UWA, kısayolu olmayan uygulama atlanır (önizlemede yazar)' {
        $ctx = New-ShellCtx
        $a = Act @{ Type = 'TaskbarPins'; Pins = @(@{ Aumid = 'Microsoft.WindowsStore_8wekyb3d8bbwe!App' }, @{ Link = '%ProgramData%\Microsoft\Windows\Start Menu\Programs\Yok.lnk' }) }
        $xml = $a.LayoutXml($ctx)
        $xml | Should -Match '<taskbar:UWA AppUserModelID="Microsoft\.WindowsStore_8wekyb3d8bbwe!App" />'
        $xml | Should -Not -Match 'Yok\.lnk'
        $xml | Should -Match 'PinListPlacement="Replace"'
        $a.Preview($ctx) | Should -Match '1 shortcuts not found, will be skipped'
    }

    It 'etkileşimli kabuk yoksa hata verir ve hiçbir şey yazmaz' {
        $ctx = New-ShellCtx
        $ctx.Desktop.ShellRunning = $false
        $a = Act @{ Type = 'TaskbarPins'; Pins = @(@{ AppId = 'Microsoft.Windows.Explorer' }) }
        { $a.Apply($ctx) } | Should -Throw '*Interactive shell*'
        Get-FakeWriteCount $ctx | Should -Be 0
    }

    It 'Gezgin düzeni uygulamazsa hata; ilke yine de kaldırılır' {
        $ctx = New-ShellCtx
        $ctx.Desktop.OnRefresh = $null
        $a = Act @{ Type = 'TaskbarPins'; Pins = @(@{ AppId = 'Microsoft.Windows.Explorer' }) }
        { $a.Apply($ctx) } | Should -Throw '*did not apply*'
        $ctx.Registry.ValueExists($script:Policy, 'StartLayoutFile') | Should -BeFalse
        $ctx.Desktop.WaitCount | Should -BeGreaterThan 0
    }
}

Describe 'SolidImageAction' {
    It 'şema: Path ya da Directory, boyut ve renk' {
        Errs @{ Type = 'SolidImage'; Path = 'C:\x\a.png'; Color = '000000'; Width = 10; Height = 10 } | Should -BeNullOrEmpty
        Errs @{ Type = 'SolidImage'; Directory = 'C:\x'; Filter = @('*.png'); Color = '000000' } | Should -BeNullOrEmpty
        (Errs @{ Type = 'SolidImage'; Color = '000000' }) -join ' ' | Should -Match 'exactly one'
        (Errs @{ Type = 'SolidImage'; Path = 'C:\x\a.gif'; Color = '000000'; Width = 1; Height = 1 }) -join ' ' | Should -Match 'extension must be'
        (Errs @{ Type = 'SolidImage'; Path = 'C:\x\a.png'; Color = 'siyah'; Width = 1; Height = 1 }) -join ' ' | Should -Match 'RRGGBB'
        (Errs @{ Type = 'SolidImage'; Path = 'C:\x\a.png'; Color = '000000' }) -join ' ' | Should -Match 'Width: required with Path'
        (Errs @{ Type = 'SolidImage'; Directory = 'C:\x'; Filter = @('*.png'); Color = '000000'; Width = 5 }) -join ' ' | Should -Match 'only allowed with Path'
    }

    It 'Path: dosya yoksa verilen boyutta oluşturulur; geri alma siler' {
        $ctx = New-Ctx
        $a = Act @{ Type = 'SolidImage'; Path = 'C:\ProgramData\FAI_WinOP\Black.png'; Color = '000000'; Width = 1920; Height = 1080 }
        $snap = RoundTrip ($a.Snapshot($ctx))
        $a.Apply($ctx)
        $ctx.Images.GetSize('C:\ProgramData\FAI_WinOP\Black.png') | Should -Be @(1920, 1080)
        $a.Test($ctx) | Should -BeTrue
        $a.Revert($ctx, $snap)
        $ctx.Files.FileExists('C:\ProgramData\FAI_WinOP\Black.png') | Should -BeFalse
    }

    It 'Directory: var olan görüntüler boyutu korunarak boyanır, görüntü olmayan atlanır; geri alma birebir' {
        $ctx = New-ShellCtx
        $before = @($ctx.Files.Dump()) -join "`n"
        $dir = Expand-FaiPath '%ProgramData%\Microsoft\User Account Pictures'
        $a = Act @{ Type = 'SolidImage'; Directory = '%ProgramData%\Microsoft\User Account Pictures'; Filter = @('*.png', '*.bmp', '*.txt'); Color = '000000' }
        @($a.Pending($ctx)).Count | Should -Be 2
        $snap = RoundTrip ($a.Snapshot($ctx))
        $a.Apply($ctx)
        $ctx.Images.IsSolid(($dir.TrimEnd('\') + '\' + 'user.png'), '000000') | Should -BeTrue
        $ctx.Images.GetSize(($dir.TrimEnd('\') + '\' + 'guest.bmp')) | Should -Be @(448, 448)
        $a.Test($ctx) | Should -BeTrue
        $a.Revert($ctx, $snap)
        (@($ctx.Files.Dump()) -join "`n") | Should -Be $before
    }
}

Describe 'AppSettingAction' {
    It 'şema: paket ailesi, tür ve değer' {
        Errs @{ Type = 'AppSetting'; Package = $script:Notepad; Name = 'GhostFile'; Kind = 'Bool'; Value = $false } | Should -BeNullOrEmpty
        Errs @{ Type = 'AppSetting'; Package = $script:Notepad; Name = 'OpenFile'; Kind = 'Int32'; Value = 1 } | Should -BeNullOrEmpty
        (Errs @{ Type = 'AppSetting'; Package = 'Notepad'; Name = 'X'; Kind = 'Bool'; Value = $true }) -join ' ' | Should -Match 'Package'
        (Errs @{ Type = 'AppSetting'; Package = $script:Notepad; Name = 'X'; Kind = 'Bool'; Value = 1 }) -join ' ' | Should -Match 'for Bool'
        (Errs @{ Type = 'AppSetting'; Package = $script:Notepad; Name = 'X'; Kind = 'String'; Value = 'a' }) -join ' ' | Should -Match 'Kind'
    }

    It 'yazar: tür + yük + 8 bayt zaman damgası; karşılaştırma damgaya bakmaz; geri alma eski veriyi yazar' {
        $ctx = New-ShellCtx
        $old = $ctx.AppSettings.GetValue($script:Notepad, 'GhostFile')
        $a = Act @{ Type = 'AppSetting'; Package = $script:Notepad; Name = 'GhostFile'; Kind = 'Bool'; Value = $false }
        $a.Test($ctx) | Should -BeFalse
        $snap = RoundTrip ($a.Snapshot($ctx))
        $a.Apply($ctx)
        $v = $ctx.AppSettings.GetValue($script:Notepad, 'GhostFile')
        $v['Type'] | Should -Be 100000011
        $v['Data'].Length | Should -Be 9
        $v['Data'][0] | Should -Be 0
        $a.Test($ctx) | Should -BeTrue
        $a.Revert($ctx, $snap)
        [Convert]::ToBase64String($ctx.AppSettings.GetValue($script:Notepad, 'GhostFile')['Data']) | Should -Be ([Convert]::ToBase64String($old['Data']))
    }

    It 'önceden olmayan değer geri almada silinir; Int32 küçük uçlu' {
        $ctx = New-ShellCtx
        $a = Act @{ Type = 'AppSetting'; Package = $script:Notepad; Name = 'RewriteEnabled'; Kind = 'Int32'; Value = 258 }
        $snap = RoundTrip ($a.Snapshot($ctx))
        $a.Apply($ctx)
        @($ctx.AppSettings.GetValue($script:Notepad, 'RewriteEnabled')['Data'][0..3]) | Should -Be @(2, 1, 0, 0)
        $a.Revert($ctx, $snap)
        $ctx.AppSettings.GetValue($script:Notepad, 'RewriteEnabled') | Should -BeNullOrEmpty
    }

    It 'ayar dosyası yoksa yapılacak iş yok (Test $true), günlüğe yazılır' {
        $ctx = New-Ctx
        (Act @{ Type = 'AppSetting'; Package = $script:Notepad; Name = 'GhostFile'; Kind = 'Bool'; Value = $false }).Test($ctx) | Should -BeTrue
        (@($ctx.Logger.Entries | ForEach-Object { $_.Message }) -join ' ') | Should -Match 'settings file not found'
    }
}

Describe 'FileAction: Base64 içerik' {
    It 'ikili içerik yazılır, Test baytları karşılaştırır, geri alma eski dosyayı yazar' {
        $ctx = New-Ctx
        $ctx.Files.Seed('C:\x\start2.bin', [byte[]]@(9, 9))
        $a = Act @{ Type = 'File'; Path = 'C:\x\start2.bin'; Base64 = [Convert]::ToBase64String([byte[]]@(0, 1, 2, 255)) }
        $a.Test($ctx) | Should -BeFalse
        $snap = RoundTrip ($a.Snapshot($ctx))
        $a.Apply($ctx)
        $ctx.Files.ReadBytes('C:\x\start2.bin') | Should -Be @(0, 1, 2, 255)
        $a.Test($ctx) | Should -BeTrue
        $a.Describe() | Should -Match '4 bytes, binary'
        $a.Revert($ctx, $snap)
        $ctx.Files.ReadBytes('C:\x\start2.bin') | Should -Be @(9, 9)
    }

    It 'şema: Base64 ile Content / Encoding birlikte verilmez, geçersiz base64 hata' {
        (Errs @{ Type = 'File'; Path = 'C:\a'; Base64 = 'AA=='; Content = 'x' }) -join ' ' | Should -Match 'Content: not allowed with Base64'
        (Errs @{ Type = 'File'; Path = 'C:\a'; Base64 = 'AA=='; Encoding = 'ASCII' }) -join ' ' | Should -Match 'Encoding'
        (Errs @{ Type = 'File'; Path = 'C:\a'; Base64 = '!!' }) -join ' ' | Should -Match 'valid base64'
    }
}

Describe 'Motor: kabuk yenilemesi (Refresh)' {
    BeforeAll {
        function New-RefreshTweak([string] $Id, [string[]] $Refresh, [string] $Name) {
            return [Tweak]::FromHashtable(@{
                    Id = $Id; Title = $Id; Description = 'test'; Category = 'ui'; Risk = 'Safe'; Refresh = $Refresh
                    Actions = @(@{ Type = 'Registry'; Path = 'HKCU:\Software\FAI_Test'; Name = $Name; Value = 1; Kind = 'DWord' })
                }, 'test')
        }
        $script:RCat = @{
            'ui.a' = (New-RefreshTweak 'ui.a' @('Shell', 'Desktop') 'A')
            'ui.b' = (New-RefreshTweak 'ui.b' @('Shell') 'B')
            'ui.c' = (New-RefreshTweak 'ui.c' @() 'C')
        }
        $script:RProfile = New-Profile @{ name = 't'; tweaks = @('ui.a', 'ui.b', 'ui.c') }
    }

    It 'şema: bilinmeyen yenileme türü hata' {
        (@(Get-FaiTweakError @{ Id = 'ui.x'; Title = 'x'; Description = 'x'; Category = 'ui'; Risk = 'Safe'; Refresh = @('Gezgin'); Actions = @(@{ Type = 'Registry'; Path = 'HKCU:\X'; Name = 'A'; Value = 1; Kind = 'DWord' }) }) -join ' ') | Should -Match 'Refresh'
    }

    It 'uygulamada her tür bir kez, sabit sırayla ve çalıştırmanın sonunda' {
        $ctx = New-Ctx
        $r = Invoke-FaiEngine -Profile $script:RProfile -Context $ctx -Catalog $script:RCat
        $r.HasFailures() | Should -BeFalse
        @($ctx.Desktop.Refreshed) | Should -Be @('Desktop', 'Shell')
    }

    It 'dry-run ve ZATEN UYGUN çalıştırma yenilemez' {
        $ctx = New-Ctx -DryRun
        [void](Invoke-FaiEngine -Profile $script:RProfile -Context $ctx -Catalog $script:RCat)
        @($ctx.Desktop.Refreshed).Count | Should -Be 0
        $ctx2 = New-Ctx
        [void](Invoke-FaiEngine -Profile $script:RProfile -Context $ctx2 -Catalog $script:RCat)
        $ctx2.Desktop.Refreshed.Clear()
        [void](Invoke-FaiEngine -Profile $script:RProfile -Context $ctx2 -Catalog $script:RCat)
        @($ctx2.Desktop.Refreshed).Count | Should -Be 0
    }

    It 'geri alma oturumdaki yenilemeleri yapar' {
        $ctx = New-Ctx
        [void](Invoke-FaiEngine -Profile $script:RProfile -Context $ctx -Catalog $script:RCat)
        $ctx.Desktop.Refreshed.Clear()
        $u = Invoke-FaiEngine -Undo -Context $ctx -Catalog $script:RCat
        $u.HasFailures() | Should -BeFalse
        @($ctx.Desktop.Refreshed) | Should -Be @('Desktop', 'Shell')
    }

    It 'yenileme hatası raporda görünür, tweak''ler uygulanmış kalır' {
        $ctx = New-Ctx
        $ctx.Desktop.OnRefresh = { param($k) if ($k -eq 'Shell') { throw 'explorer yok' } }
        $r = Invoke-FaiEngine -Profile $script:RProfile -Context $ctx -Catalog $script:RCat
        $r.Find('refresh.shell').Status | Should -Be 'Failed'
        $r.Find('ui.a').Status | Should -Be 'Applied'
    }
}

Describe 'Profil düzeni (layout)' {
    It 'şema: bilinmeyen alan, yanlış tür, geçersiz sabitleme ve base64 yakalanır' {
        $bad = @{
            name = 'p'; tweaks = @()
            layout = @{ taskbar = @{ alignment = 'right'; autoHide = 'evet'; pins = @(@{ exe = 'a' }) }; desktop = @{ iconLayouts = '!!' }; extra = @{} }
        }
        $e = @(Get-FaiProfileError -Data $bad) -join "`n"
        $e | Should -Match 'layout\.extra: unknown'
        $bad.layout.Remove('extra')
        $e = @(Get-FaiProfileError -Data $bad) -join "`n"
        $e | Should -Match 'layout\.taskbar\.alignment'
        $e | Should -Match 'layout\.taskbar\.autoHide'
        $e | Should -Match 'layout\.taskbar\.pins\[0\]'
        $e | Should -Match 'layout\.desktop\.iconLayouts'
        @(Get-FaiProfileError -Data @{ name = 'p'; tweaks = @(); layout = @{ taskbar = @{ pins = @(@{ aumid = 'Store' }) } } }) -join ' ' | Should -Match 'Aumid'
    }

    It 'düzen tweak''e çevrilir: sabitleme en sonda, Başlat ve Gezgin yenilenir' {
        $t = ConvertTo-FaiLayoutTweak -Layout @{
            taskbar = @{ alignment = 'left'; autoHide = $true; pins = @(@{ appId = 'Microsoft.Windows.Explorer' }) }
            desktopIcons = @{ thisPC = $true; network = $false }
            desktop = @{ flags = 1075839524; iconLayouts = 'AAEC' }
            start = @{ start2 = 'AAEC' }
        }
        $t.Id | Should -Be 'layout.profile'
        @($t.Refresh) | Should -Be @('StartMenu', 'Shell')
        $t.Actions[-1].Type | Should -Be 'TaskbarPins'
        @($t.Actions | ForEach-Object { $_.Type }) | Should -Contain 'RegistryByte'
        @($t.Actions | ForEach-Object { $_.Type }) | Should -Contain 'File'
        ($t.Actions | Where-Object { $_.Definition['Name'] -eq 'TaskbarAl' }).Definition['Value'] | Should -Be 0
        ($t.Actions | Where-Object { $_.Definition['Name'] -eq '{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}' }).Definition['Value'] | Should -Be 1
    }

    It 'Export: Gezgin appId, Başlat menüsünde kısayolu olan uygulama link, Store aumid; diğeri uyarı' {
        $ctx = New-ShellCtx
        $r = Export-FaiLayout -Context $ctx
        $pins = @($r.Layout['taskbar']['pins'])
        $pins.Count | Should -Be 2
        $pins[0]['appId'] | Should -Be 'Microsoft.Windows.Explorer'
        $pins[1]['aumid'] | Should -Be 'Microsoft.WindowsStore_8wekyb3d8bbwe!App'
        ($r.Warnings -join ' ') | Should -Match 'Microsoft Edge\.lnk'
        $r.Layout['taskbar']['autoHide'] | Should -BeFalse
        $r.Layout['desktopIcons']['recycleBin'] | Should -BeTrue
        $r.Layout['desktopIcons']['thisPC'] | Should -BeFalse
        Get-FakeWriteCount $ctx | Should -Be 0
    }

    It 'Export → dosyaya yaz → profil olarak geri oku: düzen aynı ve geçerli' {
        $ctx = New-ShellCtx
        $ctx.Registry.Seed('HKCU:\Software\Microsoft\Windows\Shell\Bags\1\Desktop', 'IconLayouts', [byte[]]@(1, 2, 3), 'Binary')
        $ctx.Files.Seed((Expand-FaiPath '%LOCALAPPDATA%\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin'), [byte[]]@(7, 7, 7))
        $path = Join-Path $TestDrive 'disa.json'
        $layout = Invoke-FaiExportLayout -ProfilePath $path -Context $ctx 6>$null
        $p = Import-FaiProfileFile -Path $path
        $p.Name | Should -Be 'disa'
        ($p.Layout | ConvertTo-Json -Depth 10 -Compress) | Should -Be (ConvertFrom-JsonText -Json ($layout | ConvertTo-Json -Depth 10) | ConvertTo-Json -Depth 10 -Compress)
        $p.Layout['desktop']['iconLayouts'] | Should -Be 'AQID'
        $p.Layout['start']['start2'] | Should -Be 'BwcH'
    }

    It 'var olan profile yazınca diğer alanlar korunur' {
        $path = Join-Path $TestDrive 'var.json'
        [System.IO.File]::WriteAllText($path, '{ "name": "var", "description": "d", "tweaks": [ "ui.taskbar" ] }')
        Save-FaiProfileLayout -Path $path -Layout @{ desktopIcons = @{ thisPC = $true } }
        $p = Import-FaiProfileFile -Path $path
        $p.Description | Should -Be 'd'
        $p.Tweaks[0]['Id'] | Should -Be 'ui.taskbar'
        $p.Layout['desktopIcons']['thisPC'] | Should -BeTrue
    }

    It 'kabul: -ExportLayout → -Undo → profil uygula düzeni birebir geri getirir; -Undo yine başa döner' {
        $ctx = New-ShellCtx
        $ctx.Registry.Seed('HKCU:\Software\Microsoft\Windows\Shell\Bags\1\Desktop', 'IconLayouts', [byte[]]@(1, 2, 3, 4), 'Binary')
        $ctx.Files.Seed((Expand-FaiPath '%LOCALAPPDATA%\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin'), [byte[]]@(5, 5))
        $start = Get-LayoutState $ctx

        # 1) kullanıcının düzeni: fedai görev çubuğu + masaüstü simgeleri, sonra simgeler elle sağ alta (IconLayouts)
        # görsel düzenin tek kaynağı layout (hiza, otomatik gizle, masaüstü simgeleri, FFlags); ui.taskbar yalnız düğmeler + sabitlemeler
        $fedaiLayout = @{
            taskbar      = @{ alignment = 'center'; autoHide = $true }
            desktopIcons = @{ thisPC = $true; recycleBin = $true }
            desktop      = @{ flags = 1075839524 }
        }
        $r1 = Invoke-FaiEngine -Profile (New-Profile @{ name = 'fedai'; tweaks = @('ui.taskbar'); layout = $fedaiLayout }) -Context $ctx -Catalog $script:Catalog
        $r1.HasFailures() | Should -BeFalse -Because ($r1.Render())
        $ctx.Registry.Seed('HKCU:\Software\Microsoft\Windows\Shell\Bags\1\Desktop', 'IconLayouts', [byte[]]@(9, 8, 7, 6), 'Binary')
        $ctx.Files.Seed((Expand-FaiPath '%LOCALAPPDATA%\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin'), [byte[]]@(6, 6, 6))
        Pins $ctx | Should -Be 'File Explorer.lnk,Google Chrome.lnk'

        # 2) -ExportLayout
        $path = Join-Path $TestDrive 'fedai-layout.json'
        $exported = Invoke-FaiExportLayout -ProfilePath $path -Context $ctx 6>$null
        $wantJson = $exported | ConvertTo-Json -Depth 10 -Compress
        @($exported['taskbar']['pins'])[1]['link'] | Should -Be '%ProgramData%\Microsoft\Windows\Start Menu\Programs\Google Chrome.lnk'
        # NewStartPanel hariç: Export beş simgenin hepsini açıkça yazar (değeri olmayan = Windows varsayılanı, aynı görünüm).
        $layoutParts = @('Taskband', 'StuckRects3', 'Bags\1\Desktop', 'TaskbarAl', 'User Pinned', 'start2.bin')
        $sel = { param($s) (@($s -split "`n" | Where-Object { $l = $_; @($layoutParts | Where-Object { $l -like ('*' + $_.ToLowerInvariant() + '*') }).Count -gt 0 }) -join "`n") }
        $target = & $sel (Get-LayoutState $ctx)

        # 3) -Undo: tweak'ler geri alınır (elle yapılan IconLayouts / start2 değişikliği oturumda yok, kalır)
        $u = Invoke-FaiEngine -Undo -Context $ctx -Catalog $script:Catalog
        $u.HasFailures() | Should -BeFalse -Because ($u.Render())
        Pins $ctx | Should -Be 'File Explorer.lnk,Microsoft Edge.lnk,Microsoft.WindowsStore_8wekyb3d8bbwe!App'
        $ctx.Files.Seed((Expand-FaiPath '%LOCALAPPDATA%\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin'), [byte[]]@(5, 5))
        $ctx.Registry.Seed('HKCU:\Software\Microsoft\Windows\Shell\Bags\1\Desktop', 'IconLayouts', [byte[]]@(1, 2, 3, 4), 'Binary')
        Get-LayoutState $ctx | Should -Be $start

        # 4) profil (yalnız layout) uygula → düzen birebir
        $p = Import-FaiProfileFile -Path $path
        $r2 = Invoke-FaiEngine -Profile $p -Context $ctx -Catalog $script:Catalog
        $r2.HasFailures() | Should -BeFalse -Because ($r2.Render())
        $r2.Find('layout.profile').Status | Should -Be 'Applied'
        (Export-FaiLayout -Context $ctx).Layout | ConvertTo-Json -Depth 10 -Compress | Should -Be $wantJson
        & $sel (Get-LayoutState $ctx) | Should -Be $target
        $icons = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel'
        $ctx.Registry.GetValue($icons, '{20D04FE0-3AEA-1069-A2D8-08002B30309D}') | Should -Be 0
        $ctx.Registry.GetValue($icons, '{645FF040-5081-101B-9F08-00AA002F954E}') | Should -Be 0
        $ctx.Registry.GetValue($icons, '{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}') | Should -Be 1
        @($ctx.Desktop.Refreshed | Select-Object -Last 2) | Should -Be @('StartMenu', 'Shell')

        # ikinci kez: ZATEN UYGUN
        (Invoke-FaiEngine -Profile $p -Context $ctx -Catalog $script:Catalog).Find('layout.profile').Status | Should -Be 'UpToDate'

        # 5) -Undo → başlangıç
        $u2 = Invoke-FaiEngine -Undo -Context $ctx -Catalog $script:Catalog
        $u2.HasFailures() | Should -BeFalse -Because ($u2.Render())
        Get-LayoutState $ctx | Should -Be $start
    }

    It 'dry-run: layout.profile planlanır, hiçbir şey yazılmaz' {
        $ctx = New-ShellCtx -DryRun
        $p = New-Profile @{ name = 'd'; tweaks = @(); layout = @{ taskbar = @{ autoHide = $true; pins = @(@{ appId = 'Microsoft.Windows.Explorer' }) } } }
        $r = Invoke-FaiEngine -Profile $p -Context $ctx -Catalog $script:Catalog
        $r.Find('layout.profile').Status | Should -Be 'Planned'
        Get-FakeWriteCount $ctx | Should -Be 0
    }
}

Describe 'Faz 6 tweak''leri' {
    It 'katalogda ve fedai hedef masaüstünü kapsıyor' {
        foreach ($id in @('ui.theme-black', 'ui.taskbar', 'ui.lockscreen-black', 'ui.account-pictures-black', 'ui.widgets-off', 'ui.copilot-off', 'ui.notepad-settings')) {
            $script:Catalog.ContainsKey($id) | Should -BeTrue -Because $id
        }
        # tek kaynak: hiza / otomatik gizle / masaüstü simgeleri tweak'te değil, layout'ta
        $script:Catalog.ContainsKey('ui.desktop-icons') | Should -BeFalse
        @($script:Catalog['ui.taskbar'].Params.Keys) | Should -Not -Contain 'autoHide'
        @($script:Catalog['ui.taskbar'].Actions | Where-Object { $_.Type -eq 'RegistryByte' }).Count | Should -Be 0
        @($script:Catalog['ui.taskbar'].Actions | Where-Object { $_.Type -eq 'Registry' -and $_.Definition['Name'] -in @('TaskbarAl', 'ShowCopilotButton') }).Count | Should -Be 0
        $tb = $script:Catalog['ui.taskbar']
        ($tb.Actions | Where-Object { $_.Type -eq 'TaskbarPins' }).Definition['Pins'].Count | Should -Be 2
        $tb.Actions[-1].Type | Should -Be 'TaskbarPins'
        @($script:Catalog['ui.theme-black'].Refresh) | Should -Contain 'Desktop'
    }

    It 'ui.notepad-settings parametreleri: varsayılan önceki oturum kapalı' {
        $ctx = New-ShellCtx
        $r = Invoke-FaiEngine -Profile (New-Profile @{ name = 'n'; tweaks = @('ui.notepad-settings') }) -Context $ctx -Catalog $script:Catalog
        $r.HasFailures() | Should -BeFalse -Because ($r.Render())
        $ctx.AppSettings.GetValue($script:Notepad, 'GhostFile')['Data'][0] | Should -Be 0
        $ctx.AppSettings.GetValue($script:Notepad, 'OpenFile')['Data'][0] | Should -Be 1
    }
}
