# Tek seferlik sistem eylemleri: her çalıştırmada yeniden yapılırlar (Test her zaman $false) ve geri alınmazlar.
#
#   @{ Type='RestorePoint'; Description='FAI_WinOP' }                     # Sistem Geri Yükleme noktası ($Ctx.SystemControl)
#   @{ Type='Reboot'; Firmware=$true; Delay=10 }                          # UEFI ayarlarına yeniden başlat (araç tweak'i)
#   @{ Type='OpenSettings'; Uri='ms-settings:activation'; Message='...' } # yalnız kullanıcının yapabildiği adım ($Ctx.Shell)

class RestorePointAction : ActionBase {
    RestorePointAction([hashtable] $Definition) : base($Definition) { }

    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        foreach ($m in (Get-FaiUnknownKeyError $Def @('Type', 'Description'))) { $e.Add($m) }
        if (-not $Def.Contains('Description')) { $e.Add('Description: required field missing') }
        elseif (Test-FaiHasPlaceholder $Def['Description']) { }
        elseif ($Def['Description'] -isnot [string] -or [string]::IsNullOrWhiteSpace($Def['Description']) -or $Def['Description'].Length -gt 64) {
            $e.Add('Description: must be non-empty text of at most 64 characters')
        }
        return $e.ToArray()
    }

    # Her çalıştırmada yeni nokta: hedef durum diye bir şey yok.
    [bool] Test([ExecutionContext] $Ctx) { return $false }

    [hashtable] Snapshot([ExecutionContext] $Ctx) { return @{} }

    [void] Apply([ExecutionContext] $Ctx) {
        if (-not $Ctx.SystemControl.IsRestoreEnabled()) {
            $Ctx.Logger.Info('System Protection was off: turning it on for the system drive')
            $Ctx.SystemControl.EnableRestore()
        }
        $Ctx.SystemControl.CreateRestorePoint([string]$this.Definition['Description'])
    }

    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        $Ctx.Logger.Info(("Restore point ('{0}') is not deleted; use 'rstrui' to return to it if needed." -f $this.Definition['Description']))
    }

    [string] Describe() { return ("System Restore point: '{0}'" -f $this.Definition['Description']) }

    [string] Preview([ExecutionContext] $Ctx) {
        $state = 'off, will be turned on'
        if ($Ctx.SystemControl.IsRestoreEnabled()) { $state = 'on' }
        return ('{0} [System Protection: {1}]' -f $this.Describe(), $state)
    }
}

class RebootAction : ActionBase {
    RebootAction([hashtable] $Definition) : base($Definition) { }

    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        foreach ($m in (Get-FaiUnknownKeyError $Def @('Type', 'Firmware', 'Delay'))) { $e.Add($m) }
        # Şimdilik yalnız ürün yazılımına (BIOS / UEFI) yeniden başlatma.
        if (-not $Def.Contains('Firmware')) { $e.Add('Firmware: required field missing') }
        elseif ($Def['Firmware'] -isnot [bool] -or -not $Def['Firmware']) { $e.Add('Firmware: must be $true (only rebooting to UEFI settings is supported)') }
        if ($Def.Contains('Delay') -and -not (Test-FaiHasPlaceholder $Def['Delay'])) {
            $v = $Def['Delay']
            if (-not (Test-FaiIsInteger $v) -or $v -lt 0 -or $v -gt 600) { $e.Add('Delay: must be an integer (seconds) from 0 to 600') }
        }
        return $e.ToArray()
    }

    [int] Delay() {
        if ($this.Definition.ContainsKey('Delay')) { return [int]$this.Definition['Delay'] }
        return 10
    }

    [bool] Test([ExecutionContext] $Ctx) { return $false }

    [hashtable] Snapshot([ExecutionContext] $Ctx) { return @{} }

    [void] Apply([ExecutionContext] $Ctx) {
        $Ctx.Logger.Warn(('Rebooting to UEFI (BIOS) settings in {0} s; to cancel: shutdown /a' -f $this.Delay()))
        $Ctx.SystemControl.RestartToFirmware($this.Delay())
    }

    # Yeniden başlatma geri alınamaz.
    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) { }

    [string] Describe() { return ('Reboot to UEFI (BIOS) settings after {0} s' -f $this.Delay()) }
}

class OpenSettingsAction : ActionBase {
    OpenSettingsAction([hashtable] $Definition) : base($Definition) { }

    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        foreach ($m in (Get-FaiUnknownKeyError $Def @('Type', 'Uri', 'Message'))) { $e.Add($m) }
        if (-not $Def.Contains('Uri')) { $e.Add('Uri: required field missing') }
        elseif ($Def['Uri'] -isnot [string] -or $Def['Uri'] -notmatch '^ms-settings:[A-Za-z0-9\-_?=&%.]*$') { $e.Add('Uri: must be an ms-settings: page') }
        if (-not $Def.Contains('Message')) { $e.Add('Message: required field missing') }
        elseif ($Def['Message'] -isnot [string] -or [string]::IsNullOrWhiteSpace($Def['Message'])) { $e.Add('Message: must be non-empty text') }
        return $e.ToArray()
    }

    # Sonucu programla denetlenemeyen kullanıcı adımı: tweak koşulu (ör. Edition=Core) sağlandıkça her çalıştırmada açılır.
    [bool] Test([ExecutionContext] $Ctx) { return $false }

    [hashtable] Snapshot([ExecutionContext] $Ctx) { return @{} }

    [void] Apply([ExecutionContext] $Ctx) {
        $msg = [string]$this.Definition['Message']
        if ($Ctx.Unattended) { throw "Needs interaction; cannot run in unattended mode. $msg" }
        $Ctx.Shell.OpenUri([string]$this.Definition['Uri'])
        $Ctx.Logger.Info($msg)
    }

    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) { }

    [string] Describe() { return ("Settings opens ({0}): {1}" -f $this.Definition['Uri'], $this.Definition['Message']) }
}
