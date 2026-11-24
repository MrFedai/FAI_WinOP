# EdgeRemoveAction (bloat.edge-remove): Microsoft Edge'i (Chromium) kaldırır; WebView2 Runtime ve EdgeUpdate'e dokunmaz
# (WebView2 güncellemeleri EdgeUpdate ile gelir; WhatsApp ve birçok uygulama WebView2'ye bağlı). Yalnız $Ctx.Edge üzerinden.
#
#   @{ Type='EdgeRemove' }
# Edge'in yeniden kurulmasını engelleyen EdgeUpdate ilkesi ve microsoft-edge: yönlendirmesi tweak'te ayrı Registry /
# File eylemleridir. Tweak'te bu eylem ilkeden ÖNCE gelmeli: geri alma ters sırada çalışır, ilke kalkınca Edge kurulur.
# Uygulama sonrası Edge hâlâ kuruluysa hata; WebView2 kaybolduysa yüksek sesli uyarı (Edge kaldırıcısı onu silmemeli).

class EdgeRemoveAction : ActionBase {
    EdgeRemoveAction([hashtable] $Definition) : base($Definition) { }

    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        foreach ($m in (Get-FaiUnknownKeyError $Def @('Type'))) { $e.Add($m) }
        return $e.ToArray()
    }

    [bool] Test([ExecutionContext] $Ctx) { return (-not $Ctx.Edge.GetEdgeVersion()) }

    [hashtable] Snapshot([ExecutionContext] $Ctx) {
        return @{ EdgeVersion = $Ctx.Edge.GetEdgeVersion(); WebView2Version = $Ctx.Edge.GetWebView2Version() }
    }

    [void] Apply([ExecutionContext] $Ctx) {
        $webView = $Ctx.Edge.GetWebView2Version()
        if (-not $webView) { $Ctx.Logger.Warn('WebView2 Runtime kurulu değil; WhatsApp gibi uygulamalar için gerekir (Edge kaldırma bunu değiştirmez).') }
        $Ctx.Edge.UninstallEdge()
        $left = $Ctx.Edge.GetEdgeVersion()
        if ($left) { throw "Edge kaldırılamadı (hâlâ kurulu: $left)" }
        if ($webView -and -not $Ctx.Edge.GetWebView2Version()) {
            $Ctx.Logger.Error('UYARI: Edge kaldırıldıktan sonra WebView2 Runtime bulunamıyor; WhatsApp çalışmayabilir. WebView2 yeniden kurulmalı.')
        }
    }

    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        if (-not $Snapshot['EdgeVersion']) { return }
        if ($Ctx.Edge.GetEdgeVersion()) { return }
        $Ctx.Edge.InstallEdge()
    }

    [string] Describe() { return 'Microsoft Edge kaldırılır (WebView2 Runtime ve güncellemesi kalır)' }

    [string] Preview([ExecutionContext] $Ctx) {
        $edge = $Ctx.Edge.GetEdgeVersion()
        if (-not $edge) { $edge = 'yok' }
        $wv = $Ctx.Edge.GetWebView2Version()
        if (-not $wv) { $wv = 'yok' }
        return ('{0} [şu an Edge: {1}; WebView2: {2}]' -f $this.Describe(), $edge, $wv)
    }
}
