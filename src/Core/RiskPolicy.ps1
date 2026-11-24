# Risk politikası (docs/ROADMAP.md 2.2):
#   Safe     doğrudan uygulanır
#   Caution  uyarı + E/H sorulur; -Unattended'da profilde autoConfirm yoksa atlanır
#   Risk     kırmızı uyarı + "EVET" yazdırılır; -Unattended'da ASLA uygulanmaz (autoConfirm de işlemez)
# -DryRun'da soru sorulmaz; karar "sorulacak" notuyla önizlenir.

class RiskDecision {
    [bool] $Apply
    [string] $Reason
    # Gerçek çalışmada kullanıcıya sorulacak mı / soruldu mu.
    [bool] $Prompted = $false

    RiskDecision([bool] $Apply, [string] $Reason) {
        $this.Apply = $Apply
        $this.Reason = $Reason
    }
}

class RiskPolicy {
    static [string[]] Levels() { return [string[]]@('Safe', 'Caution', 'Risk') }

    static [RiskDecision] Decide([ExecutionContext] $Ctx, [string] $Risk, [string] $Title, [string] $ConfirmText, [bool] $AutoConfirm) {
        if ($Risk -eq 'Safe') { return [RiskDecision]::new($true, 'Safe') }

        if ($Risk -eq 'Caution') {
            if ($AutoConfirm) { return [RiskDecision]::new($true, 'Caution: profilde autoConfirm') }
            if ($Ctx.Unattended) { return [RiskDecision]::new($false, 'Unattended modda Caution için profilde autoConfirm yok') }
            if ($Ctx.DryRun) {
                $d = [RiskDecision]::new($true, 'Caution: çalışınca onay (E/H) istenecek')
                $d.Prompted = $true
                return $d
            }
            if ($null -eq $Ctx.Prompt) { return [RiskDecision]::new($false, 'Onay sağlayıcısı yok') }
            $text = '⚠ {0}' -f $Title
            if ($ConfirmText) { $text = '{0} — {1}' -f $text, $ConfirmText }
            $yes = $Ctx.Prompt.Confirm($text + ' Uygulansın mı? (E/H)')
            $r = [RiskDecision]::new($yes, 'Caution: kullanıcı onayladı')
            if (-not $yes) { $r.Reason = 'Caution: kullanıcı reddetti' }
            $r.Prompted = $true
            return $r
        }

        if ($Risk -eq 'Risk') {
            if ($Ctx.Unattended) { return [RiskDecision]::new($false, 'Unattended modda Risk asla uygulanmaz') }
            if ($Ctx.DryRun) {
                $d = [RiskDecision]::new($true, 'Risk: çalışınca "EVET" yazılması istenecek')
                $d.Prompted = $true
                return $d
            }
            if ($null -eq $Ctx.Prompt) { return [RiskDecision]::new($false, 'Onay sağlayıcısı yok') }
            $text = '⛔ RİSKLİ: {0}' -f $Title
            if ($ConfirmText) { $text = '{0} — {1}' -f $text, $ConfirmText }
            $yes = $Ctx.Prompt.ConfirmExact($text + ' Devam etmek için EVET yazın.', 'EVET')
            $r = [RiskDecision]::new($yes, 'Risk: "EVET" yazıldı')
            if (-not $yes) { $r.Reason = 'Risk: onay verilmedi' }
            $r.Prompted = $true
            return $r
        }

        return [RiskDecision]::new($false, "Bilinmeyen risk düzeyi: $Risk")
    }
}
