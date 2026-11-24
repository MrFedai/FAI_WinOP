# Native eylemler (src/Native/*.cs; sağlayıcı derler).
#
# VolumeAction: varsayılan ses çıkışının seviyesi ve/veya sessizi. Yalnız $Ctx.Audio üzerinden.
#   @{ Type='Volume'; Level=15 }            # 0-100
#   @{ Type='Volume'; Level='{{level}}'; Mute=$false }
# Çıkış aygıtı yoksa eylem atlanır (servis gibi).
#
# TimerResolutionAction: zamanlayıcı çözünürlüğü servisi. Yalnız $Ctx.TimerResolution üzerinden.
#   @{ Type='TimerResolution'; Resolution=5000 }       # 100 ns birimi: 5000 = 0,5 ms
#   @{ Type='TimerResolution'; Ensure='Absent' }       # servisi kaldır
# Not: Windows 11'de istek yalnız çağıran süreci etkiler; sistem geneli için ayrıca
# HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel\GlobalTimerResolutionRequests=1 gerekir (Faz 7 tweak'i).

class VolumeAction : ActionBase {
    VolumeAction([hashtable] $Definition) : base($Definition) { }

    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        foreach ($m in (Get-FaiUnknownKeyError $Def @('Type', 'Level', 'Mute'))) { $e.Add($m) }
        if (-not $Def.Contains('Level') -and -not $Def.Contains('Mute')) { $e.Add('Level / Mute: en az biri gerekir') }
        if ($Def.Contains('Level') -and -not (Test-FaiHasPlaceholder $Def['Level'])) {
            $v = $Def['Level']
            if (-not (Test-FaiIsInteger $v) -or $v -lt 0 -or $v -gt 100) { $e.Add('Level: 0 ile 100 arası tamsayı olmalı') }
        }
        if ($Def.Contains('Mute') -and -not (Test-FaiHasPlaceholder $Def['Mute']) -and $Def['Mute'] -isnot [bool]) { $e.Add('Mute: $true ya da $false olmalı') }
        return $e.ToArray()
    }

    [bool] Test([ExecutionContext] $Ctx) {
        if (-not $Ctx.Audio.HasDevice()) { return $true }
        if ($this.Definition.ContainsKey('Level') -and $Ctx.Audio.GetVolume() -ne [int]$this.Definition['Level']) { return $false }
        if ($this.Definition.ContainsKey('Mute') -and $Ctx.Audio.GetMute() -ne [bool]$this.Definition['Mute']) { return $false }
        return $true
    }

    [hashtable] Snapshot([ExecutionContext] $Ctx) {
        if (-not $Ctx.Audio.HasDevice()) { return @{ Device = $false } }
        return @{ Device = $true; Level = $Ctx.Audio.GetVolume(); Mute = $Ctx.Audio.GetMute() }
    }

    [void] Apply([ExecutionContext] $Ctx) {
        if (-not $Ctx.Audio.HasDevice()) {
            $Ctx.Logger.Warn('Ses çıkış aygıtı yok, atlandı')
            return
        }
        if ($this.Definition.ContainsKey('Level') -and $Ctx.Audio.GetVolume() -ne [int]$this.Definition['Level']) { $Ctx.Audio.SetVolume([int]$this.Definition['Level']) }
        if ($this.Definition.ContainsKey('Mute') -and $Ctx.Audio.GetMute() -ne [bool]$this.Definition['Mute']) { $Ctx.Audio.SetMute([bool]$this.Definition['Mute']) }
    }

    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        if (-not $Snapshot['Device'] -or -not $Ctx.Audio.HasDevice()) { return }
        if ($this.Definition.ContainsKey('Level') -and $Ctx.Audio.GetVolume() -ne [int]$Snapshot['Level']) { $Ctx.Audio.SetVolume([int]$Snapshot['Level']) }
        if ($this.Definition.ContainsKey('Mute') -and $Ctx.Audio.GetMute() -ne [bool]$Snapshot['Mute']) { $Ctx.Audio.SetMute([bool]$Snapshot['Mute']) }
    }

    [string] Describe() {
        $parts = New-Object 'System.Collections.Generic.List[string]'
        if ($this.Definition.ContainsKey('Level')) { $parts.Add('seviye = %' + $this.Definition['Level']) }
        if ($this.Definition.ContainsKey('Mute')) {
            if ([bool]$this.Definition['Mute']) { $parts.Add('sessiz') } else { $parts.Add('sesli') }
        }
        return ('Ses: varsayılan çıkış → {0}' -f ($parts -join ', '))
    }

    [string] Preview([ExecutionContext] $Ctx) {
        if (-not $Ctx.Audio.HasDevice()) { return ('{0} [çıkış aygıtı yok, atlanır]' -f $this.Describe()) }
        return ('{0} [şu an: %{1}, sessiz = {2}]' -f $this.Describe(), $Ctx.Audio.GetVolume(), $Ctx.Audio.GetMute())
    }
}

class TimerResolutionAction : ActionBase {
    TimerResolutionAction([hashtable] $Definition) : base($Definition) { }

    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        foreach ($m in (Get-FaiUnknownKeyError $Def @('Type', 'Resolution', 'Ensure'))) { $e.Add($m) }
        $ensure = 'Present'
        if ($Def.Contains('Ensure')) {
            if ($Def['Ensure'] -isnot [string] -or @('Present', 'Absent') -cnotcontains $Def['Ensure']) { $e.Add('Ensure: Present ya da Absent olmalı') }
            else { $ensure = $Def['Ensure'] }
        }
        if ($ensure -eq 'Absent') {
            if ($Def.Contains('Resolution')) { $e.Add('Resolution: Ensure=Absent iken verilmez') }
            return $e.ToArray()
        }
        if (-not $Def.Contains('Resolution')) { $e.Add('Resolution: zorunlu alan eksik') }
        elseif (-not (Test-FaiHasPlaceholder $Def['Resolution'])) {
            $v = $Def['Resolution']
            if (-not (Test-FaiIsInteger $v) -or $v -lt 5000 -or $v -gt 156250) { $e.Add('Resolution: 5000 (0,5 ms) ile 156250 (15,6 ms) arası tamsayı olmalı (100 ns)') }
        }
        return $e.ToArray()
    }

    [bool] IsAbsent() { return ([string]$this.Definition['Ensure'] -eq 'Absent') }

    [bool] Test([ExecutionContext] $Ctx) {
        $installed = $Ctx.TimerResolution.IsInstalled()
        if ($this.IsAbsent()) { return (-not $installed) }
        return ($installed -and $Ctx.TimerResolution.GetResolution() -eq [int]$this.Definition['Resolution'])
    }

    [hashtable] Snapshot([ExecutionContext] $Ctx) {
        return @{ Installed = $Ctx.TimerResolution.IsInstalled(); Resolution = $Ctx.TimerResolution.GetResolution() }
    }

    [void] Apply([ExecutionContext] $Ctx) {
        if ($this.IsAbsent()) {
            if ($Ctx.TimerResolution.IsInstalled()) { $Ctx.TimerResolution.Uninstall() }
            return
        }
        $Ctx.TimerResolution.Install([int]$this.Definition['Resolution'])
    }

    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        $installed = $Ctx.TimerResolution.IsInstalled()
        if ($Snapshot['Installed']) {
            if (-not $installed -or $Ctx.TimerResolution.GetResolution() -ne [int]$Snapshot['Resolution']) { $Ctx.TimerResolution.Install([int]$Snapshot['Resolution']) }
        }
        elseif ($installed) {
            $Ctx.TimerResolution.Uninstall()
        }
    }

    [string] Describe() {
        if ($this.IsAbsent()) { return 'Zamanlayıcı çözünürlüğü servisi kaldırılır' }
        return ('Zamanlayıcı çözünürlüğü servisi: {0} ms' -f ([double]$this.Definition['Resolution'] / 10000).ToString([System.Globalization.CultureInfo]::InvariantCulture))
    }

    [string] Preview([ExecutionContext] $Ctx) {
        if (-not $Ctx.TimerResolution.IsInstalled()) { return ('{0} [şu an: kurulu değil]' -f $this.Describe()) }
        return ('{0} [şu an: kurulu, {1} × 100 ns]' -f $this.Describe(), $Ctx.TimerResolution.GetResolution())
    }
}
