# WingetAction: paket kurar ya da kaldırır (winget / msstore). Yalnız $Ctx.Packages üzerinden.
#
#   @{ Type='Winget'; Id='Google.Chrome' }                                  # winget, kurulu olsun
#   @{ Type='Winget'; Id='9NKSQGP7F2NH'; Source='msstore' }                 # Store uygulaması
#   @{ Type='Winget'; Id='Microsoft.Edge'; Ensure='Absent' }                # kaldır
# Source: winget | msstore (varsayılan winget). Ensure: Present | Absent (varsayılan Present).
# Geri alma: önceki duruma göre kaldırır ya da yeniden kurar (sürüm değil, varlık geri gelir).

class WingetAction : ActionBase {
    WingetAction([hashtable] $Definition) : base($Definition) { }

    static [string[]] Sources() { return [string[]]@('winget', 'msstore') }

    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        foreach ($m in (Get-FaiUnknownKeyError $Def @('Type', 'Id', 'Source', 'Ensure'))) { $e.Add($m) }
        if (-not $Def.Contains('Id')) { $e.Add('Id: required field missing') }
        elseif ($Def['Id'] -isnot [string] -or $Def['Id'] -notmatch '^[A-Za-z0-9][A-Za-z0-9.\-_+]*$') {
            $e.Add('Id: must be a package id (letters, digits, . - _ +; no spaces)')
        }
        if ($Def.Contains('Source') -and ($Def['Source'] -isnot [string] -or [WingetAction]::Sources() -cnotcontains $Def['Source'])) {
            $e.Add('Source: must be one of ' + ([WingetAction]::Sources() -join ', '))
        }
        if ($Def.Contains('Ensure') -and ($Def['Ensure'] -isnot [string] -or @('Present', 'Absent') -cnotcontains $Def['Ensure'])) {
            $e.Add('Ensure: must be Present or Absent')
        }
        return $e.ToArray()
    }

    [string] PackageId() { return [string]$this.Definition['Id'] }

    [string] SourceName() {
        if ($this.Definition.ContainsKey('Source')) { return [string]$this.Definition['Source'] }
        return 'winget'
    }

    [bool] WantInstalled() { return ([string]$this.Definition['Ensure'] -ne 'Absent') }

    [bool] Test([ExecutionContext] $Ctx) {
        return ($Ctx.Packages.IsInstalled($this.PackageId(), $this.SourceName()) -eq $this.WantInstalled())
    }

    [hashtable] Snapshot([ExecutionContext] $Ctx) {
        return @{ Installed = $Ctx.Packages.IsInstalled($this.PackageId(), $this.SourceName()) }
    }

    [void] Apply([ExecutionContext] $Ctx) {
        $now = $Ctx.Packages.IsInstalled($this.PackageId(), $this.SourceName())
        if ($this.WantInstalled() -and -not $now) { $Ctx.Packages.Install($this.PackageId(), $this.SourceName()) }
        if (-not $this.WantInstalled() -and $now) { $Ctx.Packages.Uninstall($this.PackageId(), $this.SourceName()) }
    }

    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        $was = [bool]$Snapshot['Installed']
        $now = $Ctx.Packages.IsInstalled($this.PackageId(), $this.SourceName())
        if ($was -and -not $now) { $Ctx.Packages.Install($this.PackageId(), $this.SourceName()) }
        if (-not $was -and $now) { $Ctx.Packages.Uninstall($this.PackageId(), $this.SourceName()) }
    }

    [string] Describe() {
        $verb = 'is installed'
        if (-not $this.WantInstalled()) { $verb = 'is removed' }
        return ('Package ({0}): {1} {2}' -f $this.SourceName(), $this.PackageId(), $verb)
    }

    [string] Preview([ExecutionContext] $Ctx) {
        $now = 'not installed'
        if ($Ctx.Packages.IsInstalled($this.PackageId(), $this.SourceName())) { $now = 'installed' }
        return ('{0} [current: {1}]' -f $this.Describe(), $now)
    }
}
