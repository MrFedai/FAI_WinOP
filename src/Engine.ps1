# Motor. Akış (docs/ROADMAP.md 2.1): profil → tweak'leri çöz → koşul → risk politikası / onay → snapshot → uygula → rapor.
#
#   -DryRun  hiçbir sağlayıcı yazma modunda çağrılmaz, BackupStore oturumu açılmaz, soru sorulmaz; rapor "ÖNİZLEME" olur.
#   -Undo    geri alınmamış son oturumun (ya da verilen oturumun) kayıtlarını TERS sırada Revert eder.
# Profilin 'apps' listesi tweak'lerden ÖNCE (bildirim istisnaları, görev çubuğu sabitlemesi kurulu uygulama ister),
# uygulama kataloğundan (apps/catalog.json) üretilen 'app.<id>' tweak'leri
# olarak aynı yoldan işlenir. Eylem Apply sırasında snapshot'ına günlük ekleyebilir (App): oturum Apply'dan sonra
# yeniden kaydedilir.
# Görünüm tweak'leri (Refresh: Shell, Desktop, Settings, StartMenu) uygulanınca / geri alınınca kabuk yenilemesi
# çalıştırmanın SONUNDA, türü başına bir kez yapılır (Gezgin bir kez yeniden başlar). Profilin 'layout' bölümü
# tweak'lerden SONRA 'layout.profile' tweak'i olarak işlenir (ConvertTo-FaiLayoutTweak).
# 'First' işaretli profil tweak'leri (system.restore-point) uygulamalardan da ÖNCE işlenir. 'Tool' tweak'leri
# (refresh.reboot-to-bios) profille otomatik çalışmaz: AllowTools (menü / -Only, Faz 8) yoksa atlanır. 'AlwaysConfirm'
# tweak'lerinde profil autoConfirm'i işlemez, -Unattended'da atlanır. Eylemin 'When' koşulu sağlanmıyorsa o eylem bu
# makinede yok sayılır (hepsi yok sayılırsa tweak ZATEN UYGUN).
# Tek tweak'in hatası diğerlerini durdurmaz; hata raporda 'Failed' olur. Yarım kalan tweak'in snapshot'ları oturumda
# durur, -Undo onları da geri alır.

class Engine {
    [ExecutionContext] $Ctx
    # Id → Tweak
    [hashtable] $Catalog
    # Uygulama kimliği → katalog kaydı (Import-FaiAppCatalog); profilde apps yoksa boş kalabilir.
    [hashtable] $AppCatalog = @{}
    [BackupSession] $Session
    # Bu çalıştırmada istenen kabuk yenilemeleri (Get-FaiRefreshKind adları).
    [System.Collections.Generic.List[string]] $PendingRefresh = (New-Object 'System.Collections.Generic.List[string]')
    # Araç tweak'lerine (Tool) izin: menü / -Only (Faz 8). Profil çalıştırmasında $false.
    [bool] $AllowTools = $false

    Engine([ExecutionContext] $Ctx, [hashtable] $Catalog) {
        $this.Ctx = $Ctx
        $this.Catalog = $Catalog
    }

    [Reporter] Run([Profile] $FaiProfile) {
        $report = [Reporter]::new()
        if ($this.Ctx.DryRun) { $report.Heading = "Profil '$($FaiProfile.Name)' — ÖNİZLEME (dry-run, hiçbir şey değişmedi)" }
        else { $report.Heading = "Profil '$($FaiProfile.Name)' — uygulama" }
        $this.Ctx.Logger.Info($report.Heading)
        $this.Session = $null
        $this.PendingRefresh.Clear()
        $this.Ctx.ProtectedAppx = $this.ProtectedAppxFor($FaiProfile)

        $firstIds = New-Object 'System.Collections.Generic.List[string]'
        foreach ($entry in $FaiProfile.Tweaks) {
            $id = [string]$entry['Id']
            if (-not $this.Catalog.ContainsKey($id) -or -not $this.Catalog[$id].First) { continue }
            $firstIds.Add($id)
            try { $this.ProcessTweak($FaiProfile, $id, $entry['Params'], $report) }
            catch {
                [void]$report.Add($id, $id, 'Failed', $_.Exception.Message, [string[]]@())
                $this.Ctx.Logger.Error("${id}: $($_.Exception.Message)")
            }
        }
        foreach ($app in $FaiProfile.Apps) {
            $id = 'app.' + [string]$app['Id']
            try {
                if (-not $this.AppCatalog.ContainsKey([string]$app['Id'])) {
                    [void]$report.Add($id, $id, 'Failed', 'Uygulama kataloğunda yok', [string[]]@())
                    continue
                }
                $appTweak = ConvertTo-FaiAppTweak -App $this.AppCatalog[[string]$app['Id']] -KeepAutostart ([bool]$app['KeepAutostart'])
                $this.ProcessResolved($FaiProfile, $appTweak, $report)
            }
            catch {
                [void]$report.Add($id, $id, 'Failed', $_.Exception.Message, [string[]]@())
                $this.Ctx.Logger.Error("${id}: $($_.Exception.Message)")
            }
        }
        foreach ($entry in $FaiProfile.Tweaks) {
            $id = [string]$entry['Id']
            if ($firstIds.Contains($id)) { continue }
            try { $this.ProcessTweak($FaiProfile, $id, $entry['Params'], $report) }
            catch {
                [void]$report.Add($id, $id, 'Failed', $_.Exception.Message, [string[]]@())
                $this.Ctx.Logger.Error("${id}: $($_.Exception.Message)")
            }
        }
        if ($null -ne $FaiProfile.Layout -and $FaiProfile.Layout.Count -gt 0) {
            $id = 'layout.profile'
            try { $this.ProcessResolved($FaiProfile, (ConvertTo-FaiLayoutTweak -Layout $FaiProfile.Layout), $report) }
            catch {
                [void]$report.Add($id, $id, 'Failed', $_.Exception.Message, [string[]]@())
                $this.Ctx.Logger.Error("${id}: $($_.Exception.Message)")
            }
        }
        $this.RunRefresh($report)
        $this.Ctx.Logger.Info($report.Summary())
        return $report
    }

    hidden [void] AddRefresh([string[]] $Kinds) {
        foreach ($k in @($Kinds)) { if ($k -and -not $this.PendingRefresh.Contains([string]$k)) { $this.PendingRefresh.Add([string]$k) } }
    }

    # İstenen yenilemeler sabit sırayla (Desktop, Settings, StartMenu, Shell); hata rapora 'refresh.<tür>' olarak girer.
    hidden [void] RunRefresh([Reporter] $Report) {
        if ($this.Ctx.DryRun -or $this.PendingRefresh.Count -eq 0) { return }
        foreach ($kind in (Get-FaiRefreshKind)) {
            if (-not $this.PendingRefresh.Contains($kind)) { continue }
            try {
                $this.Ctx.Desktop.Refresh($kind)
                $this.Ctx.Logger.Info("kabuk yenilendi: $kind")
            }
            catch {
                [void]$Report.Add('refresh.' + $kind.ToLowerInvariant(), "Kabuk yenileme: $kind", 'Failed', $_.Exception.Message, [string[]]@())
                $this.Ctx.Logger.Error("kabuk yenilenemedi (${kind}): $($_.Exception.Message)")
            }
        }
        $this.PendingRefresh.Clear()
    }

    # Sabit korunan liste + profildeki uygulamaların katalogdaki Appx adları (bloat.remove onlara dokunmaz).
    [string[]] ProtectedAppxFor([Profile] $FaiProfile) {
        $list = New-Object 'System.Collections.Generic.List[string]'
        foreach ($k in @((Get-FaiBloatProtected).Keys)) { $list.Add([string]$k) }
        foreach ($app in $FaiProfile.Apps) {
            $entry = $this.AppCatalog[[string]$app['Id']]
            if ($null -eq $entry -or -not $entry.Contains('appxNames')) { continue }
            foreach ($n in @($entry['appxNames'])) { if ($list -notcontains [string]$n) { $list.Add([string]$n) } }
        }
        return $list.ToArray()
    }

    hidden [void] ProcessTweak([Profile] $FaiProfile, [string] $Id, [hashtable] $Overrides, [Reporter] $Report) {
        if (-not $this.Catalog.ContainsKey($Id)) {
            [void]$Report.Add($Id, $Id, 'Failed', 'Katalogda böyle bir tweak yok', [string[]]@())
            return
        }
        # 1) çöz: parametre geçersiz kılmaları uygulanır, eylemler yeniden doğrulanır
        $this.ProcessResolved($FaiProfile, $this.Catalog[$Id].WithParams($Overrides), $Report)
    }

    hidden [void] ProcessResolved([Profile] $FaiProfile, [Tweak] $tweak, [Reporter] $Report) {
        # Yerel değişken adları sınıf özelliklerinden (Ctx, Session) farklı olmalı: aynı adı atamak ayrıştırma hatası.
        $cx = $this.Ctx
        $Id = $tweak.Id

        if ($tweak.Tool -and -not $this.AllowTools) {
            [void]$Report.Add($Id, $tweak.Title, 'Skipped', 'Araç: profille otomatik çalışmaz (menüden / -Only ile)', [string[]]@())
            $cx.Logger.Info("${Id}: atlandı (araç)")
            return
        }

        # 2) koşullar
        $failedCondition = $tweak.FirstFailedCondition($cx.SystemInfo)
        if ($failedCondition) {
            [void]$Report.Add($Id, $tweak.Title, 'Skipped', "Koşul sağlanmadı: $failedCondition", [string[]]@())
            $cx.Logger.Info("${Id}: atlandı, koşul sağlanmadı ($failedCondition)")
            return
        }

        # 3) hedef durum zaten sağlanıyorsa soru sormadan geç
        $pending = New-Object 'System.Collections.Generic.List[int]'
        for ($i = 0; $i -lt $tweak.Actions.Count; $i++) {
            # Eylem düzeyi koşul (When) sağlanmıyorsa eylem bu makinede yok sayılır.
            if (-not $tweak.Actions[$i].Applies($cx.SystemInfo)) { continue }
            if (-not $tweak.Actions[$i].Test($cx)) { $pending.Add($i) }
        }
        if ($pending.Count -eq 0) {
            [void]$Report.Add($Id, $tweak.Title, 'UpToDate', '', [string[]]@())
            return
        }

        # 4) risk politikası / onay (soruda bekleyen eylemlerin tablosu gösterilir)
        $details = New-Object 'System.Collections.Generic.List[string]'
        if ($tweak.Risk -ne 'Safe' -and -not $cx.DryRun -and -not $cx.Unattended) {
            foreach ($i in $pending) { $details.Add($tweak.Actions[$i].Preview($cx)) }
        }
        # AlwaysConfirm: autoConfirm işlemez; etkileşimsiz kipte soru sorulamayacağı için atlanır.
        if ($tweak.AlwaysConfirm -and $tweak.Risk -ne 'Safe' -and $cx.Unattended) {
            [void]$Report.Add($Id, $tweak.Title, 'Skipped', 'Her çalıştırmada onay ister: -Unattended kipte uygulanmaz (autoConfirm işlemez)', [string[]]@())
            $cx.Logger.Info("${Id}: atlandı (her çalıştırmada onay, Unattended)")
            return
        }
        $autoConfirm = $FaiProfile.IsAutoConfirmed($Id) -and -not $tweak.AlwaysConfirm
        $decision = [RiskPolicy]::Decide($cx, $tweak.Risk, $tweak.Title, $tweak.Confirm, $autoConfirm, $details.ToArray())
        if (-not $decision.Apply) {
            [void]$Report.Add($Id, $tweak.Title, 'Skipped', $decision.Reason, [string[]]@())
            $cx.Logger.Info("${Id}: atlandı ($($decision.Reason))")
            return
        }

        # 5a) dry-run: yalnız okuyarak değişiklik listesi
        if ($cx.DryRun) {
            $preview = New-Object 'System.Collections.Generic.List[string]'
            foreach ($i in $pending) { $preview.Add($tweak.Actions[$i].Preview($cx)) }
            $reason = ''
            if ($decision.Prompted) { $reason = $decision.Reason }
            [void]$Report.Add($Id, $tweak.Title, 'Planned', $reason, $preview.ToArray())
            return
        }

        # 5b) gerçek uygulama: her eylem için snapshot → (diske yaz) → uygula
        if ($null -eq $this.Session) { $this.Session = $cx.Backup.BeginSession($FaiProfile.Name) }
        $lines = New-Object 'System.Collections.Generic.List[string]'
        foreach ($i in $pending) {
            $action = $tweak.Actions[$i]
            $snapshot = $action.Snapshot($cx)
            $this.Session.AddEntry($Id, $i, $action.Definition, $snapshot, $tweak.Refresh)
            # Yarıda kalsa da (hata) değişen görünüm yenilensin.
            $this.AddRefresh($tweak.Refresh)
            $action.Apply($cx)
            $this.Session.Save()
            $lines.Add($action.Describe())
        }
        [void]$Report.Add($Id, $tweak.Title, 'Applied', '', $lines.ToArray())
        $cx.Logger.Info("${Id}: uygulandı ($($lines.Count) eylem)")
    }

    # SessionId boşsa geri alınmamış son oturum.
    [Reporter] Undo([string] $SessionId) {
        $report = [Reporter]::new()
        $cx = $this.Ctx
        $this.PendingRefresh.Clear()
        $sess = $null
        if ($SessionId) { $sess = $cx.Backup.Load($SessionId) }
        else { $sess = $cx.Backup.GetLatest() }

        if ($null -eq $sess) {
            $report.Heading = 'Geri alma'
            [void]$report.Add('(oturum)', 'Geri alınacak oturum yok', 'Skipped', '', [string[]]@())
            return $report
        }
        if ($cx.DryRun) { $report.Heading = "Oturum $($sess.Id) — geri alma ÖNİZLEME (dry-run, hiçbir şey değişmedi)" }
        else { $report.Heading = "Oturum $($sess.Id) — geri alma (ters sırada)" }
        $cx.Logger.Info($report.Heading)

        for ($i = $sess.Entries.Count - 1; $i -ge 0; $i--) {
            $e = $sess.Entries[$i]
            $id = [string]$e['TweakId']
            $title = '{0}. eylem' -f ([int]$e['ActionIndex'] + 1)
            try {
                $action = New-FaiAction -Definition ([hashtable]$e['Action'])
                if ($cx.DryRun) {
                    [void]$report.Add($id, $title, 'Planned', 'geri alınacak', [string[]]@($action.Preview($cx)))
                }
                else {
                    $this.AddRefresh([string[]]@($e['Refresh'] | Where-Object { $_ }))
                    $action.Revert($cx, [hashtable]$e['Snapshot'])
                    [void]$report.Add($id, $title, 'Reverted', '', [string[]]@('önceki duruma döndürüldü: ' + $action.Describe()))
                }
            }
            catch {
                [void]$report.Add($id, $title, 'Failed', $_.Exception.Message, [string[]]@())
                $cx.Logger.Error("${id}: geri alınamadı: $($_.Exception.Message)")
            }
        }

        $this.RunRefresh($report)
        # Başarısız adım varsa oturum geri alınmamış kalır (yeniden denenebilir).
        if (-not $cx.DryRun -and -not $report.HasFailures()) { $sess.MarkUndone() }
        $cx.Logger.Info($report.Summary())
        return $report
    }
}

function Invoke-FaiEngine {
    <#
    .SYNOPSIS
        Profili uygular (ya da -Undo ile son oturumu geri alır) ve Reporter döndürür.
    .PARAMETER FaiProfile
        Uygulanacak profil (Import-FaiProfileFile). -Undo'da gerekmez.
    .PARAMETER Context
        Sağlayıcıları ve DryRun / Unattended kipini taşıyan ExecutionContext.
    .PARAMETER Catalog
        Id → Tweak hashtable (Import-FaiTweakCatalog).
    .PARAMETER AppCatalog
        Uygulama kimliği → katalog kaydı (Import-FaiAppCatalog). Profilde apps varsa gerekir.
    .PARAMETER AllowTools
        Araç tweak'lerini (Tool, ör. refresh.reboot-to-bios) de çalıştırır (menü / -Only; profilde varsayılan atlanır).
    .PARAMETER Session
        -Undo ile birlikte: geri alınacak oturum kimliği (boşsa geri alınmamış son oturum).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)] [Alias('Profile')] [Profile] $FaiProfile,
        [Parameter(Mandatory = $true)] [ExecutionContext] $Context,
        [Parameter(Mandatory = $true)] [hashtable] $Catalog,
        [switch] $Undo,
        [string] $Session = '',
        [hashtable] $AppCatalog = @{},
        [switch] $AllowTools
    )

    $engine = [Engine]::new($Context, $Catalog)
    $engine.AppCatalog = $AppCatalog
    $engine.AllowTools = $AllowTools.IsPresent
    if ($Undo.IsPresent) { return $engine.Undo($Session) }
    if ($null -eq $FaiProfile) { throw 'Profil verilmedi.' }
    return $engine.Run($FaiProfile)
}
