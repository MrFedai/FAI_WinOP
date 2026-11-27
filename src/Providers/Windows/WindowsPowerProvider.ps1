# Gerçek güç sağlayıcısı: powercfg.exe. Çıktı yerelleştirilmiştir: yalnız GUID'ler ve satır sonundaki onaltılık
# değerler okunur. /qh gizli ayarları da gösterir; ayar sorgusunun son iki onaltılık değeri AC ve DC indeksidir.

class WindowsPowerProvider : IPowerProvider {
    WindowsPowerProvider() { }

    static [string] GuidPattern() { return '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' }

    # powercfg'nin plan takma adları (GUID'leri sabit).
    static [hashtable] SchemeAliases() {
        return @{
            SCHEME_BALANCED = '381b4222-f694-41f0-9685-ff5bb260df2e'
            SCHEME_MIN      = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
            SCHEME_MAX      = 'a1841308-3541-4fab-bc81-f71556f20b4a'
        }
    }

    hidden [string] Invoke([string[]] $Arguments) {
        $out = & powercfg.exe @Arguments 2>&1
        $text = (@($out) | ForEach-Object { [string]$_ }) -join "`n"
        if ($global:LASTEXITCODE -ne 0) { throw ('powercfg {0} failed ({1}): {2}' -f ($Arguments -join ' '), $global:LASTEXITCODE, $text.Trim()) }
        return $text
    }

    [string] GetActiveScheme() {
        $m = [regex]::Match($this.Invoke([string[]]@('/getactivescheme')), [WindowsPowerProvider]::GuidPattern())
        if (-not $m.Success) { throw 'Could not read the active power plan' }
        return $m.Value.ToLowerInvariant()
    }

    [string] ResolveScheme([string] $Scheme) {
        $s = $Scheme.ToUpperInvariant()
        if ($s -eq 'SCHEME_CURRENT') { return $this.GetActiveScheme() }
        $guid = $Scheme.ToLowerInvariant()
        $aliases = [WindowsPowerProvider]::SchemeAliases()
        if ($aliases.ContainsKey($s)) { $guid = $aliases[$s] }
        elseif ($Scheme -notmatch ('^' + [WindowsPowerProvider]::GuidPattern() + '$')) { return '' }
        $known = @([regex]::Matches($this.Invoke([string[]]@('/list')), [WindowsPowerProvider]::GuidPattern()) | ForEach-Object { $_.Value.ToLowerInvariant() })
        if ($known -contains $guid) { return $guid }
        return ''
    }

    [void] SetActiveScheme([string] $Scheme) { [void]$this.Invoke([string[]]@('/setactive', $Scheme)) }

    [long] GetValue([string] $Scheme, [string] $Subgroup, [string] $Setting, [bool] $OnAC) {
        $text = $this.Invoke([string[]]@('/qh', $Scheme, $Subgroup, $Setting))
        $values = @([regex]::Matches($text, ':\s*0x([0-9a-fA-F]+)\s*(\r?\n|$)') | ForEach-Object { [Convert]::ToInt64($_.Groups[1].Value, 16) })
        if ($values.Count -lt 2) { throw ('Could not read power setting: {0} {1} {2}' -f $Scheme, $Subgroup, $Setting) }
        if ($OnAC) { return [long]$values[$values.Count - 2] }
        return [long]$values[$values.Count - 1]
    }

    [void] SetValue([string] $Scheme, [string] $Subgroup, [string] $Setting, [bool] $OnAC, [long] $Value) {
        $verb = '/setdcvalueindex'
        if ($OnAC) { $verb = '/setacvalueindex' }
        [void]$this.Invoke([string[]]@($verb, $Scheme, $Subgroup, $Setting, [string]$Value))
        # Etkin planın değişikliği ancak yeniden etkinleştirince uygulanır.
        $target = $this.ResolveScheme($Scheme)
        if ($target -and $target -eq $this.GetActiveScheme()) { [void]$this.Invoke([string[]]@('/setactive', $target)) }
    }

    # Takma ad → GUID (SCHEME_CURRENT etkin plan); GUID olduğu gibi (listede olmasa da: silinmiş varsayılan plan
    # powercfg'nin varsayılan deposundan yine kopyalanabilir).
    hidden [string] SourceGuid([string] $Scheme) {
        $s = $Scheme.ToUpperInvariant()
        if ($s -eq 'SCHEME_CURRENT') { return $this.GetActiveScheme() }
        $aliases = [WindowsPowerProvider]::SchemeAliases()
        if ($aliases.ContainsKey($s)) { return [string]$aliases[$s] }
        return $Scheme.ToLowerInvariant()
    }

    [void] CreateScheme([string] $Source, [string] $Guid, [string] $Name) {
        [void]$this.Invoke([string[]]@('/duplicatescheme', $this.SourceGuid($Source), $Guid.ToLowerInvariant()))
        if (-not $this.ResolveScheme($Guid)) {
            throw (('Power plan could not be copied: {0} → {1}. The default plans may have been deleted (on Modern Standby machines ' +
                'a deleted plan cannot be copied): as administrator run "powercfg -restoredefaultschemes" (deletes custom plans), ' +
                'then try again') -f $Source, $Guid)
        }
        [void]$this.Invoke([string[]]@('/changename', $Guid.ToLowerInvariant(), $Name))
    }

    [void] DeleteScheme([string] $Guid) { [void]$this.Invoke([string[]]@('/delete', $Guid.ToLowerInvariant())) }

    # HibernateEnabled (yoksa HibernateEnabledDefault) = 1.
    [bool] GetHibernate() {
        $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)
        try {
            $k = $base.OpenSubKey('SYSTEM\CurrentControlSet\Control\Power')
            if ($null -eq $k) { return $false }
            try {
                $v = $k.GetValue('HibernateEnabled')
                if ($null -eq $v) { $v = $k.GetValue('HibernateEnabledDefault') }
                return ($null -ne $v -and [int]$v -eq 1)
            }
            finally { $k.Dispose() }
        }
        finally { $base.Dispose() }
    }

    [void] SetHibernate([bool] $Enabled) {
        $state = 'off'
        if ($Enabled) { $state = 'on' }
        [void]$this.Invoke([string[]]@('/hibernate', $state))
    }
}
