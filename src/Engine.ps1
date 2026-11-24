# Motor. Akış (docs/ROADMAP.md 2.1): profil → tweak'leri çöz → koşul → risk politikası / onay → snapshot → uygula → rapor.
#
#   -DryRun  hiçbir sağlayıcı yazma modunda çağrılmaz, BackupStore oturumu açılmaz, soru sorulmaz; rapor "ÖNİZLEME" olur.
#   -Undo    geri alınmamış son oturumun (ya da verilen oturumun) kayıtlarını TERS sırada Revert eder.
# Profilin 'apps' listesi tweak'lerden SONRA, uygulama kataloğundan (apps/catalog.json) üretilen 'app.<id>' tweak'leri
# olarak aynı yoldan işlenir. Eylem Apply sırasında snapshot'ına günlük ekleyebilir (App): oturum Apply'dan sonra
# yeniden kaydedilir.
# Tek tweak'in hatası diğerlerini durdurmaz; hata raporda 'Failed' olur. Yarım kalan tweak'in snapshot'ları oturumda
# durur, -Undo onları da geri alır.

class Engine {
    [ExecutionContext] $Ctx
    # Id → Tweak
    [hashtable] $Catalog
    # Uygulama kimliği → katalog kaydı (Import-FaiAppCatalog); profilde apps yoksa boş kalabilir.
    [hashtable] $AppCatalog = @{}
    [BackupSession] $Session

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

        foreach ($entry in $FaiProfile.Tweaks) {
            $id = [string]$entry['Id']
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
        $this.Ctx.Logger.Info($report.Summary())
        return $report
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
            if (-not $tweak.Actions[$i].Test($cx)) { $pending.Add($i) }
        }
        if ($pending.Count -eq 0) {
            [void]$Report.Add($Id, $tweak.Title, 'UpToDate', '', [string[]]@())
            return
        }

        # 4) risk politikası / onay
        $decision = [RiskPolicy]::Decide($cx, $tweak.Risk, $tweak.Title, $tweak.Confirm, $FaiProfile.IsAutoConfirmed($Id))
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
            $this.Session.AddEntry($Id, $i, $action.Definition, $snapshot)
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
                    $action.Revert($cx, [hashtable]$e['Snapshot'])
                    [void]$report.Add($id, $title, 'Reverted', '', [string[]]@('önceki duruma döndürüldü: ' + $action.Describe()))
                }
            }
            catch {
                [void]$report.Add($id, $title, 'Failed', $_.Exception.Message, [string[]]@())
                $cx.Logger.Error("${id}: geri alınamadı: $($_.Exception.Message)")
            }
        }

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
        [hashtable] $AppCatalog = @{}
    )

    $engine = [Engine]::new($Context, $Catalog)
    $engine.AppCatalog = $AppCatalog
    if ($Undo.IsPresent) { return $engine.Undo($Session) }
    if ($null -eq $FaiProfile) { throw 'Profil verilmedi.' }
    return $engine.Run($FaiProfile)
}
