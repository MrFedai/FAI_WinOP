# Windows Update eylemleri (setup.updates-staged, -UpdatesOn / -UpdatesOff). Yalnız $Ctx.Updates ve $Ctx.Registry.
#
#   @{ Type='WindowsUpdate' }                 # bekleyen bütün güncellemeleri kur
#   @{ Type='UpdatePause'; Days=365 }         # Ayarlar > Windows Update'i N gün duraklat
#   @{ Type='UpdatePause'; Ensure='Absent' }  # duraklatmayı kaldır
#
# WindowsUpdate: kurulum yeniden başlatma isterse (ya da önceden bekliyorsa) hata fırlatır; aynı tweak'teki sonraki
# eylemler (duraklatma) bu çalıştırmada uygulanmaz. $Ctx.ResumeCommand doluysa (CLI, Faz 8) HKLM RunOnce'a yazılır:
# yeniden başlatınca araç kaldığı yerden sürer. Kurulan güncellemeler geri alınmaz.
# UpdatePause: 6 değer (Get-FaiUpdatePauseName) RegistryAction ile yazılır / silinir; geri alma birebir (oluşturulan
# anahtar zinciri dahil). Zaman [FaiClock]'tan.

class WindowsUpdateAction : ActionBase {
    WindowsUpdateAction([hashtable] $Definition) : base($Definition) { }

    static [string] RunOnceKey() { return 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' }

    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        foreach ($m in (Get-FaiUnknownKeyError $Def @('Type'))) { $e.Add($m) }
        return $e.ToArray()
    }

    [bool] Test([ExecutionContext] $Ctx) {
        if ($Ctx.Updates.IsRebootPending()) { return $false }
        return (@($Ctx.Updates.GetPending()).Count -eq 0)
    }

    [hashtable] Snapshot([ExecutionContext] $Ctx) {
        return @{ Pending = [string[]]@($Ctx.Updates.GetPending()) }
    }

    [void] Apply([ExecutionContext] $Ctx) {
        $r = $Ctx.Updates.InstallPending()
        $Ctx.Logger.Info(('Windows Update: {0} kuruldu, {1} başarısız' -f [int]$r['Installed'], [int]$r['Failed']))
        if ([bool]$r['RebootRequired'] -or $Ctx.Updates.IsRebootPending()) {
            $tail = 'yeniden başlatıp profili tekrar çalıştırın (kalan güncellemeler ve duraklatma o zaman).'
            if ($Ctx.ResumeCommand) {
                $Ctx.Registry.SetValue([WindowsUpdateAction]::RunOnceKey(), 'FAI_WinOP', $Ctx.ResumeCommand, 'String')
                $tail = 'yeniden başlatın: oturum açınca araç kaldığı yerden sürer (RunOnce).'
            }
            throw ('Güncellemeler kuruldu ({0}), yeniden başlatma gerekiyor; {1}' -f [int]$r['Installed'], $tail)
        }
        if ([int]$r['Failed'] -gt 0) { throw ('{0} güncelleme kurulamadı; profili yeniden çalıştırın' -f [int]$r['Failed']) }
    }

    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        $Ctx.Logger.Warn('Kurulan Windows güncellemeleri geri alınmaz (Ayarlar > Windows Update > Güncelleştirme geçmişi).')
    }

    [string] Describe() { return 'Windows Update: bekleyen bütün güncellemeler kurulur' }

    [string] Preview([ExecutionContext] $Ctx) {
        $pending = @($Ctx.Updates.GetPending())
        $show = @($pending | Select-Object -First 3)
        $text = '{0} [şu an: {1} bekleyen' -f $this.Describe(), $pending.Count
        if ($show.Count -gt 0) { $text += ': ' + ($show -join '; ') }
        if ($pending.Count -gt $show.Count) { $text += '; …' }
        if ($Ctx.Updates.IsRebootPending()) { $text += '; yeniden başlatma bekliyor' }
        return ($text + ']')
    }
}

class UpdatePauseAction : ActionBase {
    UpdatePauseAction([hashtable] $Definition) : base($Definition) { }

    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        foreach ($m in (Get-FaiUnknownKeyError $Def @('Type', 'Days', 'Ensure'))) { $e.Add($m) }
        $ensure = 'Present'
        if ($Def.Contains('Ensure')) {
            if ($Def['Ensure'] -isnot [string] -or @('Present', 'Absent') -cnotcontains $Def['Ensure']) { $e.Add('Ensure: Present ya da Absent olmalı') }
            else { $ensure = $Def['Ensure'] }
        }
        if ($ensure -eq 'Absent') {
            if ($Def.Contains('Days')) { $e.Add('Days: Ensure=Absent iken verilmez') }
            return $e.ToArray()
        }
        if (-not $Def.Contains('Days')) { $e.Add('Days: zorunlu alan eksik') }
        elseif (-not (Test-FaiHasPlaceholder $Def['Days'])) {
            $v = $Def['Days']
            if (-not (Test-FaiIsInteger $v) -or $v -lt 1 -or $v -gt 3650) { $e.Add('Days: 1 ile 3650 arası tamsayı olmalı') }
        }
        return $e.ToArray()
    }

    [bool] IsAbsent() { return ([string]$this.Definition['Ensure'] -eq 'Absent') }

    # Ad → RegistryAction (Present'te değerler şimdiki zamandan; Snapshot / Revert yalnız yol + ad kullanır).
    [hashtable] RegistryActions() {
        $now = [FaiClock]::UtcNow()
        $start = [FaiClock]::Format($now)
        $end = $start
        if (-not $this.IsAbsent()) { $end = [FaiClock]::Format($now.AddDays([int]$this.Definition['Days'])) }
        $map = Get-FaiUpdatePauseName
        $out = [ordered]@{}
        foreach ($name in @($map.Keys)) {
            $def = @{ Type = 'Registry'; Path = (Get-FaiUpdatePauseKey); Name = $name }
            if ($this.IsAbsent()) { $def['Ensure'] = 'Absent' }
            else {
                $def['Kind'] = 'String'
                if ($map[$name] -eq 'Start') { $def['Value'] = $start } else { $def['Value'] = $end }
            }
            $out[$name] = [RegistryAction]::new($def)
        }
        return $out
    }

    [bool] Test([ExecutionContext] $Ctx) {
        $key = Get-FaiUpdatePauseKey
        $names = @((Get-FaiUpdatePauseName).Keys)
        if ($this.IsAbsent()) {
            foreach ($n in $names) { if ($Ctx.Registry.ValueExists($key, $n)) { return $false } }
            return $true
        }
        foreach ($n in $names) { if (-not $Ctx.Registry.ValueExists($key, $n)) { return $false } }
        $expiry = [FaiClock]::Parse([string]$Ctx.Registry.GetValue($key, 'PauseUpdatesExpiryTime'))
        if ($null -eq $expiry) { return $false }
        $threshold = [FaiClock]::UtcNow().Date.AddDays([int]$this.Definition['Days'] - 1)
        return ([datetime]$expiry -ge $threshold)
    }

    # Zaman metinleri snapshot'ta base64 tutulur: pwsh 7'nin ConvertFrom-Json'u ISO tarih metnini DateTime'a çevirir
    # (5.1 çevirmez); geri alma metni birebir yazmalı.
    [hashtable] Snapshot([ExecutionContext] $Ctx) {
        $snap = @{}
        $acts = $this.RegistryActions()
        foreach ($n in @($acts.Keys)) {
            $s = $acts[$n].Snapshot($Ctx)
            if ($s['Value'] -is [string]) { $s['Value'] = 'b64:' + [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes([string]$s['Value'])) }
            $snap[$n] = $s
        }
        return $snap
    }

    [void] Apply([ExecutionContext] $Ctx) {
        $acts = $this.RegistryActions()
        foreach ($n in @($acts.Keys)) { if (-not $acts[$n].Test($Ctx) -or -not $this.IsAbsent()) { $acts[$n].Apply($Ctx) } }
    }

    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        $acts = $this.RegistryActions()
        $names = @($acts.Keys)
        # Ters sırada: oluşturulan anahtar zinciri en son değerle birlikte silinir.
        for ($i = $names.Count - 1; $i -ge 0; $i--) {
            $n = $names[$i]
            if (-not $Snapshot.ContainsKey($n)) { continue }
            $s = @{}
            foreach ($k in @(([hashtable]$Snapshot[$n]).Keys)) { $s[$k] = $Snapshot[$n][$k] }
            if ($s['Value'] -is [string] -and ([string]$s['Value']).StartsWith('b64:')) {
                $s['Value'] = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(([string]$s['Value']).Substring(4)))
            }
            $acts[$n].Revert($Ctx, $s)
        }
    }

    [string] Describe() {
        if ($this.IsAbsent()) { return 'Windows Update: duraklatma kaldırılır' }
        return ('Windows Update: {0} gün duraklatılır' -f $this.Definition['Days'])
    }

    [string] Preview([ExecutionContext] $Ctx) {
        $key = Get-FaiUpdatePauseKey
        $now = 'duraklatılmamış'
        if ($Ctx.Registry.ValueExists($key, 'PauseUpdatesExpiryTime')) { $now = 'duraklatılmış, bitiş ' + [string]$Ctx.Registry.GetValue($key, 'PauseUpdatesExpiryTime') }
        return ('{0} [şu an: {1}]' -f $this.Describe(), $now)
    }
}
