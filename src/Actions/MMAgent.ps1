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
        if (-not $Def.Contains('Feature')) { $e.Add('Feature: zorunlu alan eksik') }
        elseif ($Def['Feature'] -isnot [string] -or [MMAgentAction]::Features() -cnotcontains $Def['Feature']) { $e.Add('Feature: ' + ([MMAgentAction]::Features() -join ', ') + ' değerlerinden biri olmalı') }
        if (-not $Def.Contains('Enabled')) { $e.Add('Enabled: zorunlu alan eksik') }
        elseif ($Def['Enabled'] -isnot [bool] -and -not (Test-FaiHasPlaceholder $Def['Enabled'])) { $e.Add('Enabled: $true / $false olmalı') }
        return $e.ToArray()
    }

    [string] Feature() { return [string]$this.Definition['Feature'] }

    # Özelliğin şu anki durumu; okunamazsa hata.
    [bool] Current([ExecutionContext] $Ctx) {
        $state = $Ctx.MemoryAgent.GetState()
        if (-not $state.ContainsKey($this.Feature())) { throw ('MMAgent özelliği okunamadı: ' + $this.Feature()) }
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
            $Ctx.Logger.Warn(('MMAgent {0}: komut hata verdi ama ayar kaydedildi, yeniden başlatınca etkinleşir ({1})' -f $this.Feature(), $err.Message.Trim()))
        }
    }

    [string] Describe() {
        $state = 'kapalı'
        if ([bool]$this.Definition['Enabled']) { $state = 'açık' }
        return ('Bellek yöneticisi: {0} → {1}' -f $this.Feature(), $state)
    }

    [string] Preview([ExecutionContext] $Ctx) {
        $now = 'kapalı'
        if ($this.Current($Ctx)) { $now = 'açık' }
        return ('{0} [şu an: {1}]' -f $this.Describe(), $now)
    }
}
