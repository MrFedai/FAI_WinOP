# ServiceAction: servisin başlangıç türünü ve/veya çalışma durumunu ayarlar. Yalnız $Ctx.Services üzerinden.
#
#   @{ Type='Service'; Name='DiagTrack'; StartType='Disabled'; State='Stopped' }
# StartType: Automatic | Manual | Disabled · State: Running | Stopped (en az biri gerekir). Servis yoksa eylem atlanır.

class ServiceAction : ActionBase {
    ServiceAction([hashtable] $Definition) : base($Definition) { }

    static [string[]] StartTypes() { return [string[]]@('Automatic', 'Manual', 'Disabled') }
    static [string[]] States() { return [string[]]@('Running', 'Stopped') }

    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        $allowed = @('Type', 'Name', 'StartType', 'State')
        foreach ($k in @($Def.Keys)) {
            if ($allowed -cnotcontains [string]$k) { $e.Add("${k}: bilinmeyen alan (izin verilenler: " + ($allowed -join ', ') + ')') }
        }
        if (-not $Def.Contains('Name')) { $e.Add('Name: zorunlu alan eksik') }
        elseif ($Def['Name'] -isnot [string] -or [string]::IsNullOrWhiteSpace($Def['Name'])) { $e.Add('Name: boş olmayan metin olmalı') }
        if (-not $Def.Contains('StartType') -and -not $Def.Contains('State')) { $e.Add('StartType / State: en az biri gerekir') }
        if ($Def.Contains('StartType') -and ($Def['StartType'] -isnot [string] -or [ServiceAction]::StartTypes() -cnotcontains $Def['StartType'])) {
            $e.Add('StartType: ' + ([ServiceAction]::StartTypes() -join ', ') + ' değerlerinden biri olmalı')
        }
        if ($Def.Contains('State') -and ($Def['State'] -isnot [string] -or [ServiceAction]::States() -cnotcontains $Def['State'])) {
            $e.Add('State: ' + ([ServiceAction]::States() -join ', ') + ' değerlerinden biri olmalı')
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
            $Ctx.Logger.Warn("Servis yok, atlandı: $name")
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
        if ($this.Definition.ContainsKey('StartType')) { $parts.Add('başlangıç = ' + $this.Definition['StartType']) }
        if ($this.Definition.ContainsKey('State')) { $parts.Add('durum = ' + $this.Definition['State']) }
        return ('Servis: {0} → {1}' -f $this.ServiceName(), ($parts -join ', '))
    }

    [string] Preview([ExecutionContext] $Ctx) {
        $name = $this.ServiceName()
        if (-not $Ctx.Services.ServiceExists($name)) { return ('{0} [servis yok, atlanır]' -f $this.Describe()) }
        return ('{0} [şu an: başlangıç = {1}, durum = {2}]' -f $this.Describe(), $Ctx.Services.GetStartType($name), $Ctx.Services.GetStatus($name))
    }
}
