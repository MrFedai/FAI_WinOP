# MMAgentAction: bellek yöneticisi özelliği aç / kapat (MMAgent modülü). Yalnız $Ctx.MemoryAgent üzerinden.
#
#   @{ Type='MMAgent'; Feature='MemoryCompression'; Enabled=$false }
# Feature: MemoryCompression | PageCombining | ApplicationLaunchPrefetching | ApplicationPreLaunch | OperationAPI.
# Bellek sıkıştırma ve sayfa birleştirme yeniden başlatınca etkinleşir. Undo: önceki durum.
# Windows bazen ayarı kaydedip canlı değişikliği reddeder ("The request is not supported"; Hyper-V açık makinede
# MemoryCompression): komut hata verse de durum istenen değerdeyse başarı sayılır, uyarı günlüğe yazılır.

class MMAgentAction : ActionBase {
    MMAgentAction([hashtable] $Definition) : base($Definition) { }

    static [string[]] Features() { return [string[]]@('MemoryCompression', 'PageCombining', 'ApplicationLaunchPrefetching', 'ApplicationPreLaunch', 'OperationAPI') }

    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        foreach ($m in (Get-FaiUnknownKeyError $Def @('Type', 'Feature', 'Enabled'))) { $e.Add($m) }
        if (-not $Def.Contains('Feature')) { $e.Add('Feature: required field missing') }
        elseif ($Def['Feature'] -isnot [string] -or [MMAgentAction]::Features() -cnotcontains $Def['Feature']) { $e.Add('Feature: must be one of ' + ([MMAgentAction]::Features() -join ', ')) }
        if (-not $Def.Contains('Enabled')) { $e.Add('Enabled: required field missing') }
        elseif ($Def['Enabled'] -isnot [bool] -and -not (Test-FaiHasPlaceholder $Def['Enabled'])) { $e.Add('Enabled: must be $true / $false') }
        return $e.ToArray()
    }

    [string] Feature() { return [string]$this.Definition['Feature'] }

    # Özelliğin şu anki durumu; okunamazsa hata.
    [bool] Current([ExecutionContext] $Ctx) {
        $state = $Ctx.MemoryAgent.GetState()
        if (-not $state.ContainsKey($this.Feature())) { throw ('Could not read MMAgent feature: ' + $this.Feature()) }
        return [bool]$state[$this.Feature()]
    }

    [bool] Test([ExecutionContext] $Ctx) { return ($this.Current($Ctx) -eq [bool]$this.Definition['Enabled']) }

    [hashtable] Snapshot([ExecutionContext] $Ctx) { return @{ Enabled = $this.Current($Ctx) } }

    [void] Apply([ExecutionContext] $Ctx) {
        $want = [bool]$this.Definition['Enabled']
        if ($this.Current($Ctx) -ne $want) { $this.SetTo($Ctx, $want) }
    }

    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        $was = [bool]$Snapshot['Enabled']
        if ($this.Current($Ctx) -ne $was) { $this.SetTo($Ctx, $was) }
    }

    hidden [void] SetTo([ExecutionContext] $Ctx, [bool] $Value) {
        try { $Ctx.MemoryAgent.SetFeature($this.Feature(), $Value) }
        catch {
            $err = $_.Exception
            if ($this.Current($Ctx) -ne $Value) { throw $err }
            $Ctx.Logger.Warn(('MMAgent {0}: command reported an error but the setting was saved; it takes effect after a restart ({1})' -f $this.Feature(), $err.Message.Trim()))
        }
    }

    [string] Describe() {
        $state = 'off'
        if ([bool]$this.Definition['Enabled']) { $state = 'on' }
        return ('Memory manager: {0} → {1}' -f $this.Feature(), $state)
    }

    [string] Preview([ExecutionContext] $Ctx) {
        $now = 'off'
        if ($this.Current($Ctx)) { $now = 'on' }
        return ('{0} [current: {1}]' -f $this.Describe(), $now)
    }
}
