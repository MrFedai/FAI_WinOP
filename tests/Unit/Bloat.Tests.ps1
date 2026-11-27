#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }
# Faz 5: bloat.remove kara listesi, korunan liste, bloat.persistence (AppxCleanup), bloat.edge-remove (EdgeRemove +
# microsoft-edge: yönlendirmesi). Hepsi Fake sağlayıcılara karşı.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Load-Fakes.ps1')
    $script:Seq = 0
    $script:Catalog = Import-FaiTweakCatalog -Path (Join-Path $script:FaiRepoRoot 'tweaks')
    $script:AppCatalog = Import-FaiAppCatalog -Path (Join-Path $script:FaiRepoRoot 'apps/catalog.json')
    $script:Protected = [string[]]@((Get-FaiBloatProtected).Keys)
    $script:BlackList = [string[]]@($script:Catalog['bloat.remove'].Actions | ForEach-Object { $_.PackageName() })
    $script:CleanupDef = $script:Catalog['bloat.persistence'].ActionDefs | Where-Object { $_['Type'] -eq 'AppxCleanup' }

    function New-BloatContext([switch] $DryRun, [string[]] $Answers = @()) {
        $script:Seq++
        return (New-FakeContext -BackupRoot (Join-Path $TestDrive ('b{0}' -f $script:Seq)) -DryRun:$DryRun -Answers $Answers)
    }

    function New-BloatProfile([object[]] $Tweaks, [object[]] $Apps = @()) {
        return [Profile]::FromHashtable(@{ name = 'bloat'; tweaks = @($Tweaks); apps = @($Apps) }, 'test')
    }

    # Kara listedeki her paket + bütün korunan adlar kurulu ve provisioned (en kötü durum).
    function Initialize-FakePackage([ExecutionContext] $Ctx) {
        $protectedNames = [string[]]@('Microsoft.WindowsStore', 'Microsoft.DesktopAppInstaller', 'Microsoft.ScreenSketch',
            '5319275A.WhatsAppDesktop', 'Claude', 'SpotifyAB.SpotifyMusic', 'MicrosoftWindows.Client.CBS', 'Microsoft.MicrosoftEdge.Stable')
        $all = [string[]]@($script:BlackList + $protectedNames)
        $Ctx.Appx.Seed($all, $all)
    }
}

Describe 'Kara liste ve korunan liste' {
    It 'bloat.remove yalnız Appx eylemi, Scope=User, her ad bir kez ve jokersiz' {
        foreach ($d in $script:Catalog['bloat.remove'].ActionDefs) {
            $d['Type'] | Should -Be 'Appx'
            $d['Scope'] | Should -Be 'User'
            $d['Name'] | Should -Not -Match '[*?\[\]]'
        }
        @($script:BlackList | Sort-Object -Unique).Count | Should -Be $script:BlackList.Count
        $script:BlackList.Count | Should -BeGreaterThan 20
    }

    It 'kara liste korunan kalıplarla kesişmez' {
        foreach ($n in $script:BlackList) {
            Test-FaiAppxProtected -Name $n -Patterns $script:Protected | Should -BeFalse -Because "$n korunan bir kalıba uyuyor"
        }
    }

    It 'kara liste katalogdaki hiçbir uygulamanın Appx adını içermez' {
        $appx = @(foreach ($a in $script:AppCatalog.Values) { if ($a.Contains('appxNames')) { @($a['appxNames']) } })
        $appx | Should -Contain '5319275A.WhatsAppDesktop'
        foreach ($n in $script:BlackList) { $appx | Should -Not -Contain $n }
    }

    It 'kullanıcının açık istekleri korunuyor: Store, Ekran Alıntısı, WhatsApp, Claude, winget' {
        foreach ($n in @('Microsoft.WindowsStore', 'Microsoft.ScreenSketch', '5319275A.WhatsAppDesktop', 'Claude_pzs8sxrjxfjjc', 'Microsoft.DesktopAppInstaller')) {
            Test-FaiAppxProtected -Name $n -Patterns $script:Protected | Should -BeTrue -Because $n
        }
        Test-FaiAppxProtected -Name 'Microsoft.BingNews' -Patterns $script:Protected | Should -BeFalse
    }

    It 'bloat.persistence ad listesi bloat.remove ile birebir aynı' {
        [string[]]@($script:CleanupDef['Names']) | Should -Be $script:BlackList
    }
}

Describe 'AppxAction korumasi' {
    It 'korunan paket: Test $true, Apply yazmaz ve uyarır, önizlemede korunuyor' {
        $ctx = New-BloatContext
        $ctx.ProtectedAppx = [string[]]@('*WhatsApp*')
        $ctx.Appx.Seed([string[]]@('5319275A.WhatsAppDesktop'), [string[]]@('5319275A.WhatsAppDesktop'))
        $a = New-FaiAction @{ Type = 'Appx'; Name = '5319275A.WhatsAppDesktop'; Scope = 'All' }
        $a.Test($ctx) | Should -BeTrue
        $a.Preview($ctx) | Should -Match 'korunuyor'
        $a.Apply($ctx)
        $ctx.Appx.WriteCount | Should -Be 0
        @($ctx.Logger.Entries | Where-Object { $_.Message -match 'Protected package' }).Count | Should -Be 1
    }
}

Describe 'Motor: bloat.remove' {
    It 'dry-run listesinde korunan hiçbir paket yok (kara listeye korunan ad eklense bile)' {
        $ctx = New-BloatContext -DryRun
        Initialize-FakePackage $ctx
        # Kasıtlı hatalı kara liste: korunan paketler araya sokulmuş.
        $bad = @{
            Id = 'bloat.bad'; Title = 'hatalı liste'; Description = 'test'; Category = 'bloat'; Risk = 'Safe'
            Actions = @(
                @{ Type = 'Appx'; Name = 'Microsoft.BingNews'; Scope = 'User' }
                @{ Type = 'Appx'; Name = 'Microsoft.WindowsStore'; Scope = 'User' }
                @{ Type = 'Appx'; Name = '5319275A.WhatsAppDesktop'; Scope = 'User' }
                @{ Type = 'Appx'; Name = 'SpotifyAB.SpotifyMusic'; Scope = 'User' }
            )
        }
        $catalog = @{}
        foreach ($k in $script:Catalog.Keys) { $catalog[$k] = $script:Catalog[$k] }
        $catalog['bloat.bad'] = [Tweak]::FromHashtable($bad, 'test')
        $faiProfile = New-BloatProfile -Tweaks @('bloat.remove', 'bloat.bad') -Apps @('spotify')
        $report = Invoke-FaiEngine $faiProfile -Context $ctx -Catalog $catalog -AppCatalog $script:AppCatalog

        $lines = @($report.Items | Where-Object { $_.TweakId -like 'bloat.*' } | ForEach-Object { $_.Lines })
        $lines.Count | Should -Be ($script:BlackList.Count + 1)
        foreach ($l in $lines) {
            foreach ($n in @('WindowsStore', 'WhatsApp', 'Spotify', 'ScreenSketch', 'DesktopAppInstaller', 'Claude', 'CBS', 'MicrosoftEdge')) {
                $l | Should -Not -Match $n
            }
        }
        Get-FakeWriteCount $ctx | Should -Be 0
    }

    It 'onay sorusunda kaldırılacaklar numaralı tablo olarak gösterilir; ret hiçbir şey silmez' {
        $ctx = New-BloatContext -Answers @('H')
        $ctx.Appx.Seed([string[]]@('Microsoft.BingNews', 'Microsoft.Todos', 'Microsoft.WindowsStore'), [string[]]@())
        $report = Invoke-FaiEngine (New-BloatProfile -Tweaks @('bloat.remove')) -Context $ctx -Catalog $script:Catalog
        $msg = [string]$ctx.Prompt.Asked[0]['Message']
        $msg | Should -Match 'To do \(2\)'
        $msg | Should -Match '1\. Appx: Microsoft.BingNews'
        $msg | Should -Match '2\. Appx: Microsoft.Todos'
        $msg | Should -Not -Match 'WindowsStore'
        $report.Items[0].Status | Should -Be 'Skipped'
        $ctx.Appx.WriteCount | Should -Be 0
    }

    It 'onaylanınca yalnız listedekiler kalkar; geri alma provisioned kopyadan kaydeder' {
        $ctx = New-BloatContext -Answers @('Y')
        $ctx.Appx.Seed([string[]]@('Microsoft.BingNews', 'Microsoft.WindowsStore'), [string[]]@('Microsoft.BingNews', 'Microsoft.WindowsStore'))
        $report = Invoke-FaiEngine (New-BloatProfile -Tweaks @('bloat.remove')) -Context $ctx -Catalog $script:Catalog
        $report.HasFailures() | Should -BeFalse
        $ctx.Appx.GetInstalled() | Should -Be @('Microsoft.WindowsStore')
        $undo = Invoke-FaiEngine -Undo -Context $ctx -Catalog $script:Catalog
        $undo.HasFailures() | Should -BeFalse
        @($ctx.Appx.GetInstalled()) | Should -Contain 'Microsoft.BingNews'
    }
}

Describe 'ui.widgets-off: WebExperience istisnası' {
    It 'yalnız WebExperience istisna; öteki MicrosoftWindows.Client.* paketleri korunur' {
        Test-FaiAppxProtected -Name 'MicrosoftWindows.Client.WebExperience' -Patterns $script:Protected | Should -BeFalse
        foreach ($n in @('MicrosoftWindows.Client.CBS', 'MicrosoftWindows.Client.Core', 'MicrosoftWindows.Client.FileExp', 'MicrosoftWindows.Client.WebExperienceX')) {
            Test-FaiAppxProtected -Name $n -Patterns $script:Protected | Should -BeTrue -Because $n
        }
    }

    It 'motorla uygula: pano paketi kullanıcıdan kalkar, provisioned kalır; geri alma yeniden kaydeder' {
        $ctx = New-BloatContext
        $names = [string[]]@('MicrosoftWindows.Client.WebExperience', 'MicrosoftWindows.Client.CBS')
        $ctx.Appx.Seed($names, $names)
        $report = Invoke-FaiEngine (New-BloatProfile -Tweaks @('ui.widgets-off')) -Context $ctx -Catalog $script:Catalog
        $report.HasFailures() | Should -BeFalse
        $ctx.Appx.GetInstalled() | Should -Be @('MicrosoftWindows.Client.CBS')
        @($ctx.Appx.GetProvisioned()) | Should -Contain 'MicrosoftWindows.Client.WebExperience'
        $undo = Invoke-FaiEngine -Undo -Context $ctx -Catalog $script:Catalog
        $undo.HasFailures() | Should -BeFalse
        @($ctx.Appx.GetInstalled()) | Should -Contain 'MicrosoftWindows.Client.WebExperience'
    }
}

Describe 'AppxCleanupAction (bloat.persistence)' {
    BeforeAll {
        $script:Def = @{ Type = 'AppxCleanup'; Names = @('Microsoft.BingNews', 'Microsoft.Todos', 'Microsoft.WindowsStore')
            TaskPath = '\FAI_WinOP\BloatCleanup'; ScriptPath = 'C:\ProgramData\FAI_WinOP\BloatCleanup.ps1' }
    }

    It 'şema: joker, boş liste, göreli yol reddedilir' {
        @(Get-FaiActionError @{ Type = 'AppxCleanup'; Names = @('Microsoft.Bing*'); TaskPath = '\A\B'; ScriptPath = 'C:\x.ps1' }) | Should -Match 'exact package name'
        @(Get-FaiActionError @{ Type = 'AppxCleanup'; Names = @(); TaskPath = '\A\B'; ScriptPath = 'C:\x.ps1' }) | Should -Match 'non-empty'
        @(Get-FaiActionError @{ Type = 'AppxCleanup'; Names = @('A'); TaskPath = 'A'; ScriptPath = 'x.ps1' }).Count | Should -Be 2
        @(Get-FaiActionError $script:Def).Count | Should -Be 0
    }

    It 'provisioned kopyaları kaldırır (korunan hariç), betiği yazar, görevi kaydeder; sonra Test $true' {
        $ctx = New-BloatContext
        $ctx.ProtectedAppx = [string[]]@('Microsoft.WindowsStore')
        $ctx.Appx.Seed([string[]]@(), [string[]]@('Microsoft.BingNews', 'Microsoft.WindowsStore'))
        $a = New-FaiAction $script:Def
        $a.Test($ctx) | Should -BeFalse
        $a.Preview($ctx) | Should -Match 'provisioned: Microsoft.BingNews; task: none'
        $null = $a.Snapshot($ctx)
        $a.Apply($ctx)
        $ctx.Appx.GetProvisioned() | Should -Be @('Microsoft.WindowsStore')
        $cmd = $ctx.Tasks.GetTaskAction('\FAI_WinOP\BloatCleanup')
        $cmd['Arguments'] | Should -Match '-File "C:\\ProgramData\\FAI_WinOP\\BloatCleanup.ps1"'
        $text = [System.Text.Encoding]::UTF8.GetString($ctx.Files.ReadBytes('C:\ProgramData\FAI_WinOP\BloatCleanup.ps1'))
        $text | Should -Match "'Microsoft.Todos'"
        $text | Should -Not -Match 'WindowsStore'
        (Test-FaiScriptText $text.TrimStart([char]0xFEFF)).Count | Should -Be 0
        $a.Test($ctx) | Should -BeTrue
    }

    It 'üretilen betikte damga yalnız hatasız bitişte yazılır (3.4)' {
        $text = Get-FaiBloatCleanupScript -Names @('Microsoft.Todos')
        $text | Should -Match 'Get-AppxProvisionedPackage -Online -ErrorAction Stop'
        $text | Should -Not -Match 'Get-AppxProvisionedPackage[^\r\n]*SilentlyContinue'
        ([regex]::Matches($text, '\$failed = \$true')).Count | Should -Be 3
        $text | Should -Match 'if \(\$failed\) \{[^\r\n]*stamp not written, will retry at next startup'
        $text | Should -Match '(?s)else \{\s*Set-Content -LiteralPath \$stamp'
        ([regex]::Matches($text, 'Set-Content -LiteralPath \$stamp')).Count | Should -Be 1
        (Test-FaiScriptText $text).Count | Should -Be 0
    }

    It 'geri alma görevi ve betiği siler, provisioned için uyarır' {
        $ctx = New-BloatContext
        $ctx.Appx.Seed([string[]]@(), [string[]]@('Microsoft.BingNews'))
        $a = New-FaiAction $script:Def
        $snap = ConvertFrom-JsonText ($a.Snapshot($ctx) | ConvertTo-Json -Depth 5)
        $a.Apply($ctx)
        $a.Revert($ctx, $snap)
        $ctx.Tasks.GetTaskAction('\FAI_WinOP\BloatCleanup') | Should -BeNullOrEmpty
        $ctx.Files.FileExists('C:\ProgramData\FAI_WinOP\BloatCleanup.ps1') | Should -BeFalse
        @($ctx.Logger.Entries | Where-Object { $_.Message -match 'cannot be restored' }).Count | Should -Be 1
    }

    It 'önceden var olan görev eski komutuyla geri gelir' {
        $ctx = New-BloatContext
        $ctx.Tasks.RegisterStartupTask('\FAI_WinOP\BloatCleanup', 'eski.exe', '-x', 'eski')
        $a = New-FaiAction $script:Def
        $snap = $a.Snapshot($ctx)
        $a.Apply($ctx)
        $a.Revert($ctx, $snap)
        $ctx.Tasks.GetTaskAction('\FAI_WinOP\BloatCleanup')['Execute'] | Should -Be 'eski.exe'
    }

    It 'betik üretici jokerli adı reddeder; boş listeyle de geçerli betik üretir' {
        { Get-FaiBloatCleanupScript -Names @('Microsoft.*') } | Should -Throw '*must be exact*'
        (Test-FaiScriptText (Get-FaiBloatCleanupScript -Names @())).Count | Should -Be 0
    }
}

Describe 'EdgeRemoveAction ve bloat.edge-remove' {
    It 'Edge kaldırılır, WebView2 kalır; geri alma yeniden kurar' {
        $ctx = New-BloatContext
        $ctx.Edge.EdgeVersion = '131.0.2903.70'
        $ctx.Edge.WebView2Version = '131.0.2903.70'
        $a = New-FaiAction @{ Type = 'EdgeRemove' }
        $a.Test($ctx) | Should -BeFalse
        $a.Preview($ctx) | Should -Match 'Edge: 131.0.2903.70; WebView2: 131.0.2903.70'
        $snap = $a.Snapshot($ctx)
        $a.Apply($ctx)
        $ctx.Edge.GetEdgeVersion() | Should -Be ''
        $ctx.Edge.GetWebView2Version() | Should -Be '131.0.2903.70'
        $a.Test($ctx) | Should -BeTrue
        $a.Revert($ctx, $snap)
        $ctx.Edge.WriteLog | Should -Be @('UninstallEdge', 'InstallEdge')
    }

    It 'kaldırıcı başarısızsa hata fırlatır' {
        $ctx = New-BloatContext
        $ctx.Edge.EdgeVersion = '131.0'
        $ctx.Edge.UninstallFails = $true
        { (New-FaiAction @{ Type = 'EdgeRemove' }).Apply($ctx) } | Should -Throw '*Edge could not be removed*'
    }

    It 'tweak: EdgeRemove ilk eylem (geri almada ilke önce kalkar), WebView2 kurulumu ve güncellemesi izinli' {
        $t = $script:Catalog['bloat.edge-remove']
        $t.ActionDefs[0]['Type'] | Should -Be 'EdgeRemove'
        $policy = @($t.ActionDefs | Where-Object { $_['Path'] -eq 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate' })
        ($policy | Where-Object { $_['Name'] -eq 'Install{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}' })['Value'] | Should -Be 0
        ($policy | Where-Object { $_['Name'] -eq 'Install{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}' })['Value'] | Should -Be 1
        ($policy | Where-Object { $_['Name'] -eq 'Update{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}' })['Value'] | Should -Be 1
    }

    It 'motorla uygula + geri al: Edge geri kurulur, ilke ve yönlendirme kalkar' {
        $ctx = New-BloatContext -Answers @('Y')
        $ctx.Edge.EdgeVersion = '131.0'
        $ctx.Edge.WebView2Version = '131.0'
        $report = Invoke-FaiEngine (New-BloatProfile -Tweaks @('bloat.edge-remove')) -Context $ctx -Catalog $script:Catalog
        $report.HasFailures() | Should -BeFalse
        $ctx.Prompt.Asked[0]['Message'] | Should -Match 'To do \(8\)'
        $ctx.Registry.GetValue('HKLM:\SOFTWARE\Classes\microsoft-edge\shell\open\command', '') | Should -Match 'EdgeRedirect.ps1" "%1"$'
        $undo = Invoke-FaiEngine -Undo -Context $ctx -Catalog $script:Catalog
        $undo.HasFailures() | Should -BeFalse
        $ctx.Edge.GetEdgeVersion() | Should -Be '999.0.0.0'
        $ctx.Registry.KeyExists('HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate') | Should -BeFalse
        $ctx.Files.FileExists('C:\ProgramData\FAI_WinOP\EdgeRedirect.ps1') | Should -BeFalse
    }

    It 'yönlendirme betiği yalnız http / https adresini çıkarır' {
        $content = ($script:Catalog['bloat.edge-remove'].ActionDefs | Where-Object { $_['Type'] -eq 'File' })['Content']
        $path = Join-Path $TestDrive 'EdgeRedirect.ps1'
        Set-Content -LiteralPath $path -Value $content -Encoding UTF8
        & $path -Uri 'microsoft-edge:https://example.com/a?b=1' -Print | Should -Be 'https://example.com/a?b=1'
        & $path -Uri 'microsoft-edge:?launchContext1=x&url=https%3A%2F%2Fexample.com%2Fp%3Fq%3D1' -Print | Should -Be 'https://example.com/p?q=1'
        & $path -Uri 'microsoft-edge:///?url=http%3A%2F%2Fexample.org' -Print | Should -Be 'http://example.org'
        foreach ($bad in @('microsoft-edge:file:///C:/Windows/System32/calc.exe', 'microsoft-edge:?url=javascript%3Aalert(1)', 'microsoft-edge:https://a b')) {
            # Çalışan kabuk (5.1'de powershell.exe; pwsh kurulu olmayabilir)
            $out = & (Get-Process -Id $PID).Path -NoProfile -File $path -Uri $bad -Print
            $LASTEXITCODE | Should -Be 1 -Because $bad
            $out | Should -BeNullOrEmpty
        }
    }
}
