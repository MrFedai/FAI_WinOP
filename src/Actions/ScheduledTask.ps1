# ScheduledTaskAction: zamanlanmış görevi etkinleştirir / devre dışı bırakır. Yalnız $Ctx.Tasks üzerinden.
#
#   @{ Type='ScheduledTask'; Path='\Microsoft\Windows\Customer Experience Improvement Program\Consolidator'; State='Disabled' }
# Path: klasör + görev adı, '\' ile başlar. State: Enabled | Disabled. Görev yoksa eylem atlanır (servis gibi).

class ScheduledTaskAction : ActionBase {
    ScheduledTaskAction([hashtable] $Definition) : base($Definition) { }

    static [string[]] States() { return [string[]]@('Enabled', 'Disabled') }

    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        foreach ($m in (Get-FaiUnknownKeyError $Def @('Type', 'Path', 'State'))) { $e.Add($m) }
        if (-not $Def.Contains('Path')) { $e.Add('Path: zorunlu alan eksik') }
        elseif ($Def['Path'] -isnot [string] -or $Def['Path'] -notmatch '^\\(.+\\)?[^\\]+$') {
            $e.Add('Path: ''\Klasör\Görev'' biçiminde olmalı (\ ile başlar, \ ile bitmez)')
        }
        if (-not $Def.Contains('State')) { $e.Add('State: zorunlu alan eksik') }
        elseif ($Def['State'] -isnot [string] -or [ScheduledTaskAction]::States() -cnotcontains $Def['State']) {
            $e.Add('State: ' + ([ScheduledTaskAction]::States() -join ', ') + ' değerlerinden biri olmalı')
        }
        return $e.ToArray()
    }

    [string] TaskPath() { return [string]$this.Definition['Path'] }

    [bool] Test([ExecutionContext] $Ctx) {
        $now = $Ctx.Tasks.GetTaskState($this.TaskPath())
        if (-not $now) { return $true }
        return ($now -eq [string]$this.Definition['State'])
    }

    [hashtable] Snapshot([ExecutionContext] $Ctx) {
        $now = $Ctx.Tasks.GetTaskState($this.TaskPath())
        if (-not $now) { return @{ Exists = $false } }
        return @{ Exists = $true; State = $now }
    }

    [void] Apply([ExecutionContext] $Ctx) {
        $now = $Ctx.Tasks.GetTaskState($this.TaskPath())
        if (-not $now) {
            $Ctx.Logger.Warn('Zamanlanmış görev yok, atlandı: ' + $this.TaskPath())
            return
        }
        $want = [string]$this.Definition['State']
        if ($now -ne $want) { $Ctx.Tasks.SetTaskEnabled($this.TaskPath(), ($want -eq 'Enabled')) }
    }

    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        if (-not $Snapshot['Exists']) { return }
        $now = $Ctx.Tasks.GetTaskState($this.TaskPath())
        if (-not $now) { return }
        $want = [string]$Snapshot['State']
        if ($now -ne $want) { $Ctx.Tasks.SetTaskEnabled($this.TaskPath(), ($want -eq 'Enabled')) }
    }

    [string] Describe() {
        $word = 'devre dışı'
        if ([string]$this.Definition['State'] -eq 'Enabled') { $word = 'etkin' }
        return ('Zamanlanmış görev: {0} → {1}' -f $this.TaskPath(), $word)
    }

    [string] Preview([ExecutionContext] $Ctx) {
        $now = $Ctx.Tasks.GetTaskState($this.TaskPath())
        if (-not $now) { return ('{0} [görev yok, atlanır]' -f $this.Describe()) }
        return ('{0} [şu an: {1}]' -f $this.Describe(), $now)
    }

    [string] PreviewRevert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        if (-not $Snapshot['Exists']) { return ('Zamanlanmış görev {0}: kayıtta yoktu, geri alınca dokunulmaz' -f $this.TaskPath()) }
        $now = $Ctx.Tasks.GetTaskState($this.TaskPath())
        if (-not $now) { return ('Zamanlanmış görev {0}: şu an yok, geri alma atlanır' -f $this.TaskPath()) }
        return ('Zamanlanmış görev {0}: şu an {1} → geri alınca {2}' -f $this.TaskPath(), $now, $Snapshot['State'])
    }
}
