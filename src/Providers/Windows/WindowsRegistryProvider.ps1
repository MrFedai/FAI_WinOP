# Gerçek kayıt defteri (Microsoft.Win32, 64 bit görünüm: 32 bit PowerShell'den de WOW64 yönlendirmesi olmaz).
# Yol: 'HKLM:\SOFTWARE\...' (HKLM, HKCU, HKCR, HKU, HKCC). Değerler ortam değişkeni AÇILMADAN okunur (ExpandString korunur).

class WindowsRegistryProvider : IRegistryProvider {
    WindowsRegistryProvider() { }

    static [hashtable] SplitPath([string] $Path) {
        $m = [regex]::Match($Path, '^(HKLM|HKCU|HKCR|HKU|HKCC):\\(.+)$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if (-not $m.Success) { throw "Geçersiz kayıt defteri yolu: $Path" }
        $hives = @{ HKLM = 'LocalMachine'; HKCU = 'CurrentUser'; HKCR = 'ClassesRoot'; HKU = 'Users'; HKCC = 'CurrentConfig' }
        return @{
            Hive   = [Microsoft.Win32.RegistryHive]$hives[$m.Groups[1].Value.ToUpperInvariant()]
            SubKey = $m.Groups[2].Value.TrimEnd('\')
        }
    }

    # Mode: Read (yoksa $null) | Write (var olanı yazılabilir aç; yoksa $null) | Create (yoksa oluştur).
    hidden [Microsoft.Win32.RegistryKey] OpenKey([string] $Path, [string] $Mode) {
        $parts = [WindowsRegistryProvider]::SplitPath($Path)
        $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($parts['Hive'], [Microsoft.Win32.RegistryView]::Registry64)
        try {
            if ($Mode -eq 'Create') { return $base.CreateSubKey($parts['SubKey']) }
            return $base.OpenSubKey($parts['SubKey'], ($Mode -eq 'Write'))
        }
        finally { $base.Dispose() }
    }

    [bool] KeyExists([string] $Path) {
        $k = $this.OpenKey($Path, 'Read')
        if ($null -eq $k) { return $false }
        $k.Dispose()
        return $true
    }

    [bool] ValueExists([string] $Path, [string] $Name) {
        $k = $this.OpenKey($Path, 'Read')
        if ($null -eq $k) { return $false }
        try { return (@($k.GetValueNames()) -contains $Name) }
        finally { $k.Dispose() }
    }

    [object] GetValue([string] $Path, [string] $Name) {
        $k = $this.OpenKey($Path, 'Read')
        if ($null -eq $k) { return $null }
        try {
            if (@($k.GetValueNames()) -notcontains $Name) { return $null }
            return $k.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        }
        finally { $k.Dispose() }
    }

    [string] GetValueKind([string] $Path, [string] $Name) {
        $k = $this.OpenKey($Path, 'Read')
        if ($null -eq $k) { return '' }
        try {
            if (@($k.GetValueNames()) -notcontains $Name) { return '' }
            return $k.GetValueKind($Name).ToString()
        }
        finally { $k.Dispose() }
    }

    [void] SetValue([string] $Path, [string] $Name, [object] $Value, [string] $Kind) {
        $k = $this.OpenKey($Path, 'Create')
        try {
            $coerced = ConvertTo-FaiRegistryValue -Value $Value -Kind $Kind
            $k.SetValue($Name, $coerced, [Microsoft.Win32.RegistryValueKind]$Kind)
        }
        finally { $k.Dispose() }
    }

    [void] DeleteEmptyKey([string] $Path) {
        $parts = [WindowsRegistryProvider]::SplitPath($Path)
        $sub = $parts['SubKey']
        $i = $sub.LastIndexOf('\')
        if ($i -lt 0) { return }
        $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($parts['Hive'], [Microsoft.Win32.RegistryView]::Registry64)
        try {
            $k = $base.OpenSubKey($sub, $false)
            if ($null -eq $k) { return }
            $empty = $false
            try { $empty = ($k.ValueCount -eq 0 -and $k.SubKeyCount -eq 0) }
            finally { $k.Dispose() }
            if (-not $empty) { return }
            $parent = $base.OpenSubKey($sub.Substring(0, $i), $true)
            if ($null -eq $parent) { return }
            try { $parent.DeleteSubKey($sub.Substring($i + 1), $false) }
            finally { $parent.Dispose() }
        }
        finally { $base.Dispose() }
    }

    [void] DeleteValue([string] $Path, [string] $Name) {
        $k = $this.OpenKey($Path, 'Write')
        if ($null -eq $k) { return }
        try { $k.DeleteValue($Name, $false) }
        finally { $k.Dispose() }
    }
}
