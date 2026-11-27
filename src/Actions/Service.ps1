# ServiceAction: servisin başlangıç türünü ve/veya çalışma durumunu ayarlar. Yalnız $Ctx.Services üzerinden.
#
#   @{ Type='Service'; Name='DiagTrack'; StartType='Disabled'; State='Stopped' }
# StartType: Automatic | AutomaticDelayedStart | Manual | Disabled · State: Running | Stopped (en az biri gerekir). Servis yoksa eylem atlanır.

class ServiceAction : ActionBase {
    ServiceAction([hashtable] $Definition) : base($Definition) { }

    static [string[]] StartTypes() { return [string[]]@('Automatic', 'AutomaticDelayedStart', 'Manual', 'Disabled') }
    static [string[]] States() { return [string[]]@('Running', 'Stopped') }

    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        $allowed = @('Type', 'Name', 'StartType', 'State')
        foreach ($k in @($Def.Keys)) {
            if ($allowed -cnotcontains [string]$k) { $e.Add("${k}: unknown field (allowed: " + ($allowed -join ', ') + ')') }
        }
        if (-not $Def.Contains('Name')) { $e.Add('Name: required field missing') }
        elseif ($Def['Name'] -isnot [string] -or [string]::IsNullOrWhiteSpace($Def['Name'])) { $e.Add('Name: must be non-empty text') }
        if (-not $Def.Contains('StartType') -and -not $Def.Contains('State')) { $e.Add('StartType / State: at least one is required') }
        if ($Def.Contains('StartType') -and ($Def['StartType'] -isnot [string] -or [ServiceAction]::StartTypes() -cnotcontains $Def['StartType'])) {
            $e.Add('StartType: must be one of ' + ([ServiceAction]::StartTypes() -join ', '))
        }
        if ($Def.Contains('State') -and ($Def['State'] -isnot [string] -or [ServiceAction]::States() -cnotcontains $Def['State'])) {
            $e.Add('State: must be one of ' + ([ServiceAction]::States() -join ', '))
        }
        return $e.ToArray()
    }

    [string] ServiceName() { return [string]$this.Definition['Name'] }

    [bool] Test([ExecutionContext] $Ctx) {
        $name = $this.ServiceName()
        if (-not $Ctx.Services.ServiceExists($name)) { return $true }
        if ($this.Definition.ContainsKey('StartType') -and $Ctx.Services.GetStartType($name) -ne [string]$this.Definition['StartType']) { return $false }
        if ($this.Definition.ContainsKey('State') -and $Ctx.Services.GetStatus($name) -ne [string]$this.Definition['State']) { return $false }
        return $true
    }

    [hashtable] Snapshot([ExecutionContext] $Ctx) {
        $name = $this.ServiceName()
        if (-not $Ctx.Services.ServiceExists($name)) { return @{ Exists = $false } }
        return @{
            Exists    = $true
            StartType = $Ctx.Services.GetStartType($name)
            Status    = $Ctx.Services.GetStatus($name)
        }
    }

    [void] Apply([ExecutionContext] $Ctx) {
        $name = $this.ServiceName()
        if (-not $Ctx.Services.ServiceExists($name)) {
            $Ctx.Logger.Warn("Service not found, skipped: $name")
            return
        }
        if ($this.Definition.ContainsKey('StartType') -and $Ctx.Services.GetStartType($name) -ne [string]$this.Definition['StartType']) {
            $Ctx.Services.SetStartType($name, [string]$this.Definition['StartType'])
        }
        if ($this.Definition.ContainsKey('State')) {
            $want = [string]$this.Definition['State']
            $now = $Ctx.Services.GetStatus($name)
            if ($want -eq 'Stopped' -and $now -ne 'Stopped') { $Ctx.Services.StopService($name) }
            if ($want -eq 'Running' -and $now -ne 'Running') { $Ctx.Services.StartService($name) }
        }
    }

    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        $name = $this.ServiceName()
        if (-not $Snapshot['Exists']) { return }
        if (-not $Ctx.Services.ServiceExists($name)) { return }
        if ($Ctx.Services.GetStartType($name) -ne [string]$Snapshot['StartType']) {
            $Ctx.Services.SetStartType($name, [string]$Snapshot['StartType'])
        }
        $now = $Ctx.Services.GetStatus($name)
        if ([string]$Snapshot['Status'] -eq 'Running' -and $now -ne 'Running') { $Ctx.Services.StartService($name) }
        if ([string]$Snapshot['Status'] -eq 'Stopped' -and $now -ne 'Stopped') { $Ctx.Services.StopService($name) }
    }

    [string] Describe() {
        $parts = New-Object 'System.Collections.Generic.List[string]'
        if ($this.Definition.ContainsKey('StartType')) { $parts.Add('start = ' + $this.Definition['StartType']) }
        if ($this.Definition.ContainsKey('State')) { $parts.Add('status = ' + $this.Definition['State']) }
        return ('Service: {0} → {1}' -f $this.ServiceName(), ($parts -join ', '))
    }

    [string] Preview([ExecutionContext] $Ctx) {
        $name = $this.ServiceName()
        if (-not $Ctx.Services.ServiceExists($name)) { return ('{0} [service not found, will be skipped]' -f $this.Describe()) }
        return ('{0} [current: start = {1}, status = {2}]' -f $this.Describe(), $Ctx.Services.GetStartType($name), $Ctx.Services.GetStatus($name))
    }

    [string] PreviewRevert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        $name = $this.ServiceName()
        if (-not $Snapshot['Exists']) { return ('Service {0}: was not in the backup, left untouched on revert' -f $name) }
        if (-not $Ctx.Services.ServiceExists($name)) { return ('Service {0}: current: none, revert will be skipped' -f $name) }
        return ('Service {0}: currently start = {1} → will revert to {2}, status {3}' -f $name, $Ctx.Services.GetStartType($name), $Snapshot['StartType'], $Snapshot['Status'])
    }
}
