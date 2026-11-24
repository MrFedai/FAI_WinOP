# AppxAction: Store (Appx) paketini kaldırır — kullanıcı paketi ve/veya provisioned (yeni kullanıcılara kurulan) kopya.
# Yalnız $Ctx.Appx üzerinden. Kurulum Appx ile değil Winget eylemiyle (Source='msstore') yapılır.
#
#   @{ Type='Appx'; Name='Microsoft.BingNews'; Scope='All' }
# Name: paket adı birebir (joker yok). Scope: User | Provisioned | All (varsayılan All).
# Geri alma sınırı: kullanıcı paketi, makinede provisioned kopyası durdukça yeniden kaydedilir; provisioned kopya
# kaldırıldıysa geri dönüş yoktur (Store'dan yeniden kurulur). Geri alınamayan adım uyarı olarak günlüğe yazılır.

class AppxAction : ActionBase {
    AppxAction([hashtable] $Definition) : base($Definition) { }

    static [string[]] Scopes() { return [string[]]@('User', 'Provisioned', 'All') }

    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        foreach ($m in (Get-FaiUnknownKeyError $Def @('Type', 'Name', 'Scope'))) { $e.Add($m) }
        if (-not $Def.Contains('Name')) { $e.Add('Name: zorunlu alan eksik') }
        elseif ($Def['Name'] -isnot [string] -or $Def['Name'] -notmatch '^[A-Za-z0-9][A-Za-z0-9.\-]*$') {
            $e.Add('Name: paket adı birebir olmalı (harf, rakam, nokta, tire; joker yok)')
        }
        if ($Def.Contains('Scope') -and ($Def['Scope'] -isnot [string] -or [AppxAction]::Scopes() -cnotcontains $Def['Scope'])) {
            $e.Add('Scope: ' + ([AppxAction]::Scopes() -join ', ') + ' değerlerinden biri olmalı')
        }
        return $e.ToArray()
    }

    [string] PackageName() { return [string]$this.Definition['Name'] }

    [string] ScopeName() {
        if ($this.Definition.ContainsKey('Scope')) { return [string]$this.Definition['Scope'] }
        return 'All'
    }

    [bool] CoversUser() { return ($this.ScopeName() -ne 'Provisioned') }
    [bool] CoversProvisioned() { return ($this.ScopeName() -ne 'User') }

    [bool] IsInstalled([ExecutionContext] $Ctx) { return (@($Ctx.Appx.GetInstalled()) -contains $this.PackageName()) }
    [bool] IsProvisioned([ExecutionContext] $Ctx) { return (@($Ctx.Appx.GetProvisioned()) -contains $this.PackageName()) }

    [bool] Test([ExecutionContext] $Ctx) {
        if ($this.CoversUser() -and $this.IsInstalled($Ctx)) { return $false }
        if ($this.CoversProvisioned() -and $this.IsProvisioned($Ctx)) { return $false }
        return $true
    }

    [hashtable] Snapshot([ExecutionContext] $Ctx) {
        return @{ Installed = $this.IsInstalled($Ctx); Provisioned = $this.IsProvisioned($Ctx) }
    }

    # Önce kullanıcı paketi: provisioned kopya yerinde durduğu sürece kullanıcı paketi geri kaydedilebilir.
    [void] Apply([ExecutionContext] $Ctx) {
        if ($this.CoversUser() -and $this.IsInstalled($Ctx)) { $Ctx.Appx.RemoveInstalled($this.PackageName()) }
        if ($this.CoversProvisioned() -and $this.IsProvisioned($Ctx)) { $Ctx.Appx.RemoveProvisioned($this.PackageName()) }
    }

    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        $name = $this.PackageName()
        if ($Snapshot['Provisioned'] -and -not $this.IsProvisioned($Ctx)) {
            $Ctx.Logger.Warn("Appx provisioned paket geri getirilemez (Store'dan yeniden kurulmalı): $name")
        }
        if ($Snapshot['Installed'] -and -not $this.IsInstalled($Ctx)) {
            try { $Ctx.Appx.RestoreInstalled($name) }
            catch { $Ctx.Logger.Warn("Appx paketi geri kaydedilemedi (Store'dan yeniden kurulmalı): ${name}: $($_.Exception.Message)") }
        }
    }

    [string] Describe() {
        $where = 'kullanıcı + provisioned'
        if ($this.ScopeName() -eq 'User') { $where = 'kullanıcı' }
        if ($this.ScopeName() -eq 'Provisioned') { $where = 'provisioned' }
        return ('Appx: {0} kaldırılır ({1})' -f $this.PackageName(), $where)
    }

    [string] Preview([ExecutionContext] $Ctx) {
        $state = New-Object 'System.Collections.Generic.List[string]'
        if ($this.IsInstalled($Ctx)) { $state.Add('kullanıcıda kurulu') }
        if ($this.IsProvisioned($Ctx)) { $state.Add('provisioned') }
        if ($state.Count -eq 0) { $state.Add('yok') }
        return ('{0} [şu an: {1}]' -f $this.Describe(), ($state -join ', '))
    }
}
