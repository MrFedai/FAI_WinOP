# PowerAction: güç planı ayarı (powercfg). Yalnız $Ctx.Power üzerinden. İki kip:
#
#   @{ Type='Power'; ActiveScheme='SCHEME_MIN' }                                         # etkin planı değiştir
#   @{ Type='Power'; Subgroup='SUB_SLEEP'; Setting='STANDBYIDLE'; AC=0; DC=900 }          # plandaki ayar (AC/DC ayrı)
#   @{ Type='Power'; Scheme='SCHEME_MAX'; Subgroup='...'; Setting='...'; AC=1 }           # belirli plan
# Scheme / ActiveScheme / Subgroup / Setting: GUID ya da powercfg takma adı. Scheme varsayılanı SCHEME_CURRENT.
# AC = prizde, DC = pilde; en az biri. Snapshot planın GUID'ini tutar: etkin plan sonradan değişse de doğru plana döner.

class PowerAction : ActionBase {
    PowerAction([hashtable] $Definition) : base($Definition) { }

    static [string] IdPattern() { return '^[A-Za-z0-9_\-]+$' }

    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        $pattern = [PowerAction]::IdPattern()
        if ($Def.Contains('ActiveScheme')) {
            foreach ($m in (Get-FaiUnknownKeyError $Def @('Type', 'ActiveScheme'))) { $e.Add($m) }
            if ($Def['ActiveScheme'] -isnot [string] -or $Def['ActiveScheme'] -notmatch $pattern) { $e.Add('ActiveScheme: plan GUID''i ya da takma adı olmalı') }
            return $e.ToArray()
        }
        foreach ($m in (Get-FaiUnknownKeyError $Def @('Type', 'Scheme', 'Subgroup', 'Setting', 'AC', 'DC'))) { $e.Add($m) }
        if ($Def.Contains('Scheme') -and ($Def['Scheme'] -isnot [string] -or $Def['Scheme'] -notmatch $pattern)) { $e.Add('Scheme: plan GUID''i ya da takma adı olmalı') }
        foreach ($f in @('Subgroup', 'Setting')) {
            if (-not $Def.Contains($f)) { $e.Add("${f}: zorunlu alan eksik") }
            elseif ($Def[$f] -isnot [string] -or $Def[$f] -notmatch $pattern) { $e.Add("${f}: GUID ya da powercfg takma adı olmalı") }
        }
        if (-not $Def.Contains('AC') -and -not $Def.Contains('DC')) { $e.Add('AC / DC: en az biri gerekir (ya da ActiveScheme)') }
        foreach ($f in @('AC', 'DC')) {
            if (-not $Def.Contains($f) -or (Test-FaiHasPlaceholder $Def[$f])) { continue }
            $v = $Def[$f]
            if (-not (Test-FaiIsInteger $v) -or $v -lt 0 -or $v -gt 4294967295) { $e.Add("${f}: 0 ile 4294967295 arası tamsayı olmalı") }
        }
        return $e.ToArray()
    }

    [bool] IsSchemeSwitch() { return $this.Definition.ContainsKey('ActiveScheme') }

    [string] SchemeName() {
        if ($this.Definition.ContainsKey('Scheme')) { return [string]$this.Definition['Scheme'] }
        return 'SCHEME_CURRENT'
    }

    # Ayar kipinde hedef planın GUID'i; plan yoksa hata.
    [string] TargetScheme([ExecutionContext] $Ctx) {
        $g = $Ctx.Power.ResolveScheme($this.SchemeName())
        if (-not $g) { throw ('Güç planı yok: ' + $this.SchemeName()) }
        return $g
    }

    [string[]] Sides() {
        $s = New-Object 'System.Collections.Generic.List[string]'
        if ($this.Definition.ContainsKey('AC')) { $s.Add('AC') }
        if ($this.Definition.ContainsKey('DC')) { $s.Add('DC') }
        return $s.ToArray()
    }

    [bool] Test([ExecutionContext] $Ctx) {
        if ($this.IsSchemeSwitch()) {
            $g = $Ctx.Power.ResolveScheme([string]$this.Definition['ActiveScheme'])
            return ($g -and $g -eq $Ctx.Power.GetActiveScheme())
        }
        $g = $this.TargetScheme($Ctx)
        foreach ($side in $this.Sides()) {
            $now = $Ctx.Power.GetValue($g, [string]$this.Definition['Subgroup'], [string]$this.Definition['Setting'], ($side -eq 'AC'))
            if ($now -ne [long]$this.Definition[$side]) { return $false }
        }
        return $true
    }

    [hashtable] Snapshot([ExecutionContext] $Ctx) {
        if ($this.IsSchemeSwitch()) { return @{ Active = $Ctx.Power.GetActiveScheme() } }
        $g = $this.TargetScheme($Ctx)
        $snap = @{ Scheme = $g }
        foreach ($side in $this.Sides()) {
            $snap[$side] = $Ctx.Power.GetValue($g, [string]$this.Definition['Subgroup'], [string]$this.Definition['Setting'], ($side -eq 'AC'))
        }
        return $snap
    }

    [void] Apply([ExecutionContext] $Ctx) {
        if ($this.IsSchemeSwitch()) {
            $g = $Ctx.Power.ResolveScheme([string]$this.Definition['ActiveScheme'])
            if (-not $g) { throw ('Güç planı yok: ' + $this.Definition['ActiveScheme']) }
            if ($g -ne $Ctx.Power.GetActiveScheme()) { $Ctx.Power.SetActiveScheme($g) }
            return
        }
        $g = $this.TargetScheme($Ctx)
        $this.SetSides($Ctx, $g, $this.Definition)
    }

    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        if ($this.IsSchemeSwitch()) {
            $was = [string]$Snapshot['Active']
            if ($was -and $was -ne $Ctx.Power.GetActiveScheme() -and $Ctx.Power.ResolveScheme($was)) { $Ctx.Power.SetActiveScheme($was) }
            return
        }
        $g = [string]$Snapshot['Scheme']
        if (-not $Ctx.Power.ResolveScheme($g)) {
            $Ctx.Logger.Warn("Güç planı artık yok, geri alma atlandı: $g")
            return
        }
        $this.SetSides($Ctx, $g, $Snapshot)
    }

    # Values: AC / DC anahtarlı hashtable (tanım ya da snapshot); yalnız farklı olan taraf yazılır.
    hidden [void] SetSides([ExecutionContext] $Ctx, [string] $SchemeGuid, [hashtable] $Values) {
        $sub = [string]$this.Definition['Subgroup']
        $setting = [string]$this.Definition['Setting']
        foreach ($side in $this.Sides()) {
            if (-not $Values.ContainsKey($side)) { continue }
            $onAC = ($side -eq 'AC')
            $want = [long]$Values[$side]
            if ($Ctx.Power.GetValue($SchemeGuid, $sub, $setting, $onAC) -ne $want) { $Ctx.Power.SetValue($SchemeGuid, $sub, $setting, $onAC, $want) }
        }
    }

    [string] Describe() {
        if ($this.IsSchemeSwitch()) { return ('Güç: etkin plan → {0}' -f $this.Definition['ActiveScheme']) }
        $parts = New-Object 'System.Collections.Generic.List[string]'
        if ($this.Definition.ContainsKey('AC')) { $parts.Add('prizde = ' + $this.Definition['AC']) }
        if ($this.Definition.ContainsKey('DC')) { $parts.Add('pilde = ' + $this.Definition['DC']) }
        return ('Güç: {0} / {1} / {2} → {3}' -f $this.SchemeName(), $this.Definition['Subgroup'], $this.Definition['Setting'], ($parts -join ', '))
    }

    [string] Preview([ExecutionContext] $Ctx) {
        if ($this.IsSchemeSwitch()) { return ('{0} [şu an: {1}]' -f $this.Describe(), $Ctx.Power.GetActiveScheme()) }
        $g = $Ctx.Power.ResolveScheme($this.SchemeName())
        if (-not $g) { return ('{0} [plan yok]' -f $this.Describe()) }
        $parts = New-Object 'System.Collections.Generic.List[string]'
        foreach ($side in $this.Sides()) {
            $label = 'pilde'
            if ($side -eq 'AC') { $label = 'prizde' }
            $parts.Add(('{0} = {1}' -f $label, $Ctx.Power.GetValue($g, [string]$this.Definition['Subgroup'], [string]$this.Definition['Setting'], ($side -eq 'AC'))))
        }
        return ('{0} [şu an: {1}]' -f $this.Describe(), ($parts -join ', '))
    }
}
