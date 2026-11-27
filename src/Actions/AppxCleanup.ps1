# AppxCleanupAction (bloat.persistence): kara listedeki paketlerin provisioned kopyalarını kaldırır (yeni kullanıcılara
# kurulmasınlar) ve açılışta Windows yapısı değiştiyse temizliği yineleyen bir zamanlanmış görev kurar (büyük güncelleme
# kaldırılan uygulamaları geri getirir). Yalnız $Ctx.Appx, $Ctx.Files ve $Ctx.Tasks üzerinden.
#
#   @{ Type='AppxCleanup'; Names=@('Microsoft.BingNews', ...)
#      TaskPath='\FAI_WinOP\BloatCleanup'; ScriptPath='%ProgramData%\FAI_WinOP\BloatCleanup.ps1' }
# Names: birebir paket adları (joker yok). $Ctx.ProtectedAppx'e uyan ad hiçbir adımda kullanılmaz (betiğe de girmez).
# Betik metni Get-FaiBloatCleanupScript (src/Core/Bloat.ps1) üretir; görev SYSTEM hesabıyla açılışta çalışır.
# Geri alma: görev silinir (önceden varsa eski komutuyla yeniden kaydedilir), betik önceki hâline döner. Provisioned
# kaldırmanın geri dönüşü yoktur (Store'dan yeniden kurulur); uyarı olarak günlüğe yazılır.

class AppxCleanupAction : ActionBase {
    AppxCleanupAction([hashtable] $Definition) : base($Definition) { }

    static [string] PowerShellPath() { return '%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe' }

    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        foreach ($m in (Get-FaiUnknownKeyError $Def @('Type', 'Names', 'TaskPath', 'ScriptPath'))) { $e.Add($m) }
        if (-not $Def.Contains('Names')) { $e.Add('Names: required field missing') }
        elseif ($Def['Names'] -is [string] -or $Def['Names'] -isnot [System.Collections.IEnumerable] -or @($Def['Names']).Count -eq 0) {
            $e.Add('Names: must be a non-empty list of package names')
        }
        else {
            foreach ($n in @($Def['Names'])) {
                if ($n -isnot [string] -or $n -notmatch '^[A-Za-z0-9][A-Za-z0-9.\-]*$') {
                    $e.Add("Names: '$n' must be an exact package name (letters, digits, dot, hyphen; no wildcards)")
                }
            }
        }
        if (-not $Def.Contains('TaskPath')) { $e.Add('TaskPath: required field missing') }
        elseif ($Def['TaskPath'] -isnot [string] -or $Def['TaskPath'] -notmatch '^\\(.+\\)?[^\\]+$') {
            $e.Add('TaskPath: must be in the form ''\Folder\Task''')
        }
        if (-not $Def.Contains('ScriptPath')) { $e.Add('ScriptPath: required field missing') }
        elseif (-not (Test-FaiWindowsPath $Def['ScriptPath']) -or [string]$Def['ScriptPath'] -notmatch '\.ps1$') {
            $e.Add('ScriptPath: must be an absolute .ps1 path (C:\..., %VARIABLE%\...)')
        }
        return $e.ToArray()
    }

    [string] TaskPath() { return [string]$this.Definition['TaskPath'] }
    [string] ScriptFullPath() { return (Expand-FaiPath ([string]$this.Definition['ScriptPath'])) }

    # Korunanlar süzülmüş adlar.
    [string[]] EffectiveNames([ExecutionContext] $Ctx) {
        $out = New-Object 'System.Collections.Generic.List[string]'
        foreach ($n in @($this.Definition['Names'])) {
            if (-not (Test-FaiAppxProtected -Name ([string]$n) -Patterns $Ctx.ProtectedAppx)) { $out.Add([string]$n) }
        }
        return $out.ToArray()
    }

    [string[]] PresentProvisioned([ExecutionContext] $Ctx) {
        $prov = @($Ctx.Appx.GetProvisioned())
        return [string[]]@($this.EffectiveNames($Ctx) | Where-Object { $prov -contains $_ })
    }

    [byte[]] WantScript([ExecutionContext] $Ctx) {
        $dir = [string]$this.Definition['ScriptPath']
        $dir = $dir.Substring(0, $dir.LastIndexOf('\'))
        return [FileAction]::Encode((Get-FaiBloatCleanupScript -Names $this.EffectiveNames($Ctx) -StateDirectory $dir), 'UTF8BOM')
    }

    [string] WantArguments() {
        return ('-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}"' -f $this.ScriptFullPath())
    }

    [bool] TaskMatches([ExecutionContext] $Ctx) {
        $now = $Ctx.Tasks.GetTaskAction($this.TaskPath())
        if ($null -eq $now) { return $false }
        return ([string]$now['Execute'] -eq (Expand-FaiPath ([AppxCleanupAction]::PowerShellPath())) -and [string]$now['Arguments'] -eq $this.WantArguments())
    }

    [bool] ScriptMatches([ExecutionContext] $Ctx) {
        $p = $this.ScriptFullPath()
        if (-not $Ctx.Files.FileExists($p)) { return $false }
        return [FileAction]::BytesEqual($Ctx.Files.ReadBytes($p), $this.WantScript($Ctx))
    }

    [bool] Test([ExecutionContext] $Ctx) {
        if (@($this.PresentProvisioned($Ctx)).Count -gt 0) { return $false }
        return ($this.ScriptMatches($Ctx) -and $this.TaskMatches($Ctx))
    }

    [hashtable] Snapshot([ExecutionContext] $Ctx) {
        $task = $Ctx.Tasks.GetTaskAction($this.TaskPath())
        $snap = @{
            Provisioned = [string[]]@($this.PresentProvisioned($Ctx))
            Script      = [FileAction]::BackupFile($Ctx, $this.ScriptFullPath())
            TaskExisted = ($null -ne $task)
        }
        if ($null -ne $task) {
            $snap['TaskExecute'] = [string]$task['Execute']
            $snap['TaskArguments'] = [string]$task['Arguments']
        }
        return $snap
    }

    [void] Apply([ExecutionContext] $Ctx) {
        foreach ($n in $this.PresentProvisioned($Ctx)) { $Ctx.Appx.RemoveProvisioned($n) }
        if (-not $this.ScriptMatches($Ctx)) { $Ctx.Files.WriteBytes($this.ScriptFullPath(), $this.WantScript($Ctx)) }
        if (-not $this.TaskMatches($Ctx)) {
            $Ctx.Tasks.RegisterStartupTask($this.TaskPath(), (Expand-FaiPath ([AppxCleanupAction]::PowerShellPath())), $this.WantArguments(),
                'FAI_WinOP: removes bloatware packages again after a Windows update (bloat.persistence).')
        }
    }

    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        if ($Snapshot['TaskExisted']) {
            $Ctx.Tasks.RegisterStartupTask($this.TaskPath(), [string]$Snapshot['TaskExecute'], [string]$Snapshot['TaskArguments'], 'FAI_WinOP (reverted)')
        }
        else { $Ctx.Tasks.UnregisterTask($this.TaskPath()) }
        [FileAction]::RestoreFile($Ctx, $this.ScriptFullPath(), [hashtable]$Snapshot['Script'])
        $prov = @($Ctx.Appx.GetProvisioned())
        $gone = @(@($Snapshot['Provisioned']) | Where-Object { $_ -and $prov -notcontains $_ })
        if ($gone.Count -gt 0) {
            $Ctx.Logger.Warn("Provisioned packages cannot be restored (reinstall from the Store): " + ($gone -join ', '))
        }
    }

    [string] Describe() {
        return ('Bloatware persistence: the provisioned copy of {0} packages is removed, startup task {1} repeats it after updates' -f @($this.Definition['Names']).Count, $this.TaskPath())
    }

    [string] Preview([ExecutionContext] $Ctx) {
        $prov = @($this.PresentProvisioned($Ctx))
        $task = 'none'
        if ($this.TaskMatches($Ctx)) { $task = 'current' }
        elseif ($null -ne $Ctx.Tasks.GetTaskAction($this.TaskPath())) { $task = 'exists with a different command' }
        $list = 'none'
        if ($prov.Count -gt 0) { $list = $prov -join ', ' }
        return ('{0} [current provisioned: {1}; task: {2}]' -f $this.Describe(), $list, $task)
    }
}
