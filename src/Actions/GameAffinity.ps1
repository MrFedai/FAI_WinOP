# GameAffinityAction (gaming.per-game): oyun başına işlemci benzeşimi (affinity). IFEO'da benzeşim ayarı yok: maskeler
# üretilen betiğe gömülür, açılışta SYSTEM olarak başlayan süresiz bir görev betiği çalıştırır; betik oyun süreci
# başlayınca (Win32_ProcessStartTrace) benzeşimi ayarlar. Yalnız $Ctx.Files ve $Ctx.Tasks üzerinden.
#
#   @{ Type='GameAffinity'; Games=@(@{ Exe='cs2.exe'; Mask=21845 })
#      TaskPath='\FAI_WinOP\GameAffinity'; ScriptPath='%ProgramData%\FAI_WinOP\GameAffinity.ps1' }
# Betik metni Get-FaiGameAffinityScript (src/Core/Games.ps1) üretir. Geri alma: görev silinir (önceden varsa eski
# komutuyla yeniden kaydedilir), betik önceki hâline döner. Çalışan oyunun benzeşimi oyun kapanınca kendiliğinden düzelir.

class GameAffinityAction : ActionBase {
    GameAffinityAction([hashtable] $Definition) : base($Definition) { }

    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        foreach ($m in (Get-FaiUnknownKeyError $Def @('Type', 'Games', 'TaskPath', 'ScriptPath'))) { $e.Add($m) }
        if (-not $Def.Contains('Games')) { $e.Add('Games: zorunlu alan eksik') }
        elseif (-not (Test-FaiIsList $Def['Games']) -or @($Def['Games']).Count -eq 0) { $e.Add('Games: boş olmayan @{ Exe; Mask } listesi olmalı') }
        else {
            $i = 0
            foreach ($g in @($Def['Games'])) {
                if ($g -isnot [System.Collections.IDictionary]) { $e.Add("Games[$i]: @{ Exe; Mask } olmalı") }
                else {
                    if ($g['Exe'] -isnot [string] -or $g['Exe'] -notmatch (Get-FaiGameExePattern)) { $e.Add("Games[$i].Exe: yalnız dosya adı (ör. cs2.exe)") }
                    if (-not (Test-FaiIsInteger $g['Mask']) -or [long]$g['Mask'] -eq 0) { $e.Add("Games[$i].Mask: sıfırdan farklı tamsayı olmalı") }
                }
                $i++
            }
        }
        if (-not $Def.Contains('TaskPath')) { $e.Add('TaskPath: zorunlu alan eksik') }
        elseif ($Def['TaskPath'] -isnot [string] -or $Def['TaskPath'] -notmatch '^\\(.+\\)?[^\\]+$') { $e.Add('TaskPath: ''\Klasör\Görev'' biçiminde olmalı') }
        if (-not $Def.Contains('ScriptPath')) { $e.Add('ScriptPath: zorunlu alan eksik') }
        elseif (-not (Test-FaiWindowsPath $Def['ScriptPath']) -or [string]$Def['ScriptPath'] -notmatch '\.ps1$') { $e.Add('ScriptPath: mutlak .ps1 yolu olmalı (C:\..., %DEĞİŞKEN%\...)') }
        return $e.ToArray()
    }

    [string] TaskPath() { return [string]$this.Definition['TaskPath'] }
    [string] ScriptFullPath() { return (Expand-FaiPath ([string]$this.Definition['ScriptPath'])) }

    [byte[]] WantScript() {
        $dir = [string]$this.Definition['ScriptPath']
        $dir = $dir.Substring(0, $dir.LastIndexOf('\'))
        return [FileAction]::Encode((Get-FaiGameAffinityScript -Games @($this.Definition['Games']) -StateDirectory $dir), 'UTF8BOM')
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
        return [FileAction]::BytesEqual($Ctx.Files.ReadBytes($p), $this.WantScript())
    }

    [bool] Test([ExecutionContext] $Ctx) { return ($this.ScriptMatches($Ctx) -and $this.TaskMatches($Ctx)) }

    [hashtable] Snapshot([ExecutionContext] $Ctx) {
        $task = $Ctx.Tasks.GetTaskAction($this.TaskPath())
        $snap = @{ Script = [FileAction]::BackupFile($Ctx, $this.ScriptFullPath()); TaskExisted = ($null -ne $task) }
        if ($null -ne $task) {
            $snap['TaskExecute'] = [string]$task['Execute']
            $snap['TaskArguments'] = [string]$task['Arguments']
        }
        return $snap
    }

    [void] Apply([ExecutionContext] $Ctx) {
        if (-not $this.ScriptMatches($Ctx)) { $Ctx.Files.WriteBytes($this.ScriptFullPath(), $this.WantScript()) }
        if (-not $this.TaskMatches($Ctx)) {
            $Ctx.Tasks.RegisterWatcherTask($this.TaskPath(), (Expand-FaiPath ([AppxCleanupAction]::PowerShellPath())), $this.WantArguments(),
                'FAI_WinOP: oyun başlayınca işlemci benzeşimini ayarlar (gaming.per-game).')
        }
    }

    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        if ($Snapshot['TaskExisted']) {
            $Ctx.Tasks.RegisterWatcherTask($this.TaskPath(), [string]$Snapshot['TaskExecute'], [string]$Snapshot['TaskArguments'], 'FAI_WinOP (geri alındı)')
        }
        else { $Ctx.Tasks.UnregisterTask($this.TaskPath()) }
        [FileAction]::RestoreFile($Ctx, $this.ScriptFullPath(), [hashtable]$Snapshot['Script'])
    }

    [string] Describe() {
        $parts = @(@($this.Definition['Games']) | ForEach-Object { '{0} = 0x{1:X}' -f $_['Exe'], [long]$_['Mask'] })
        return ('Oyun benzeşimi: {0} (açılış görevi {1})' -f ($parts -join ', '), $this.TaskPath())
    }

    [string] Preview([ExecutionContext] $Ctx) {
        $task = 'yok'
        if ($this.TaskMatches($Ctx)) { $task = 'güncel' }
        elseif ($null -ne $Ctx.Tasks.GetTaskAction($this.TaskPath())) { $task = 'farklı komutla var' }
        $script = 'yok'
        if ($this.ScriptMatches($Ctx)) { $script = 'güncel' }
        elseif ($Ctx.Files.FileExists($this.ScriptFullPath())) { $script = 'farklı' }
        return ('{0} [şu an görev: {1}; betik: {2}]' -f $this.Describe(), $task, $script)
    }
}
