# Gerçek servis yöneticisi. Başlangıç türü kayıt defterinden okunur (Start + DelayedAutostart: gecikmeli otomatik ayrımı
# yalnız orada); sc.exe ile yazılır, sc.exe reddederse (korumalı servis) kayıt defterine yazılır (yeniden başlatmada etkin).
# StartType: Automatic | AutomaticDelayedStart | Manual | Disabled | Boot | System. Durdurma bağımlı servisleri ZORLAMAZ.

class WindowsServiceManager : IServiceManager {
    WindowsServiceManager() { }

    static [string] KeyPath([string] $Name) { return ('SYSTEM\CurrentControlSet\Services\{0}' -f $Name) }

    hidden [Microsoft.Win32.RegistryKey] OpenServiceKey([string] $Name, [bool] $Writable) {
        $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)
        try { return $base.OpenSubKey([WindowsServiceManager]::KeyPath($Name), $Writable) }
        finally { $base.Dispose() }
    }

    [bool] ServiceExists([string] $Name) {
        return ($null -ne (Get-Service -Name $Name -ErrorAction SilentlyContinue))
    }

    [string] GetStartType([string] $Name) {
        $k = $this.OpenServiceKey($Name, $false)
        if ($null -eq $k) { throw "Service registration not found: $Name" }
        $start = 3
        $delayed = 0
        try {
            $start = [int]$k.GetValue('Start', 3)
            $delayed = [int]$k.GetValue('DelayedAutostart', 0)
        }
        finally { $k.Dispose() }
        if ($start -eq 0) { return 'Boot' }
        if ($start -eq 1) { return 'System' }
        if ($start -eq 2 -and $delayed -eq 1) { return 'AutomaticDelayedStart' }
        if ($start -eq 2) { return 'Automatic' }
        if ($start -eq 4) { return 'Disabled' }
        return 'Manual'
    }

    [string] GetStatus([string] $Name) {
        $svc = Get-Service -Name $Name -ErrorAction Stop
        return $svc.Status.ToString()
    }

    [void] SetStartType([string] $Name, [string] $StartType) {
        $scArgs = @{ Automatic = 'auto'; AutomaticDelayedStart = 'delayed-auto'; Manual = 'demand'; Disabled = 'disabled'; Boot = 'boot'; System = 'system' }
        if (-not $scArgs.ContainsKey($StartType)) { throw "Unknown start type: $StartType" }
        $out = & sc.exe config $Name start= $scArgs[$StartType] 2>&1
        $code = $global:LASTEXITCODE
        if ($code -eq 0 -and $this.GetStartType($Name) -eq $StartType) { return }

        # sc.exe reddetti (çoğunlukla korumalı servis: erişim engellendi) ya da gecikme bayrağı tutmadı → kayıt defteri.
        $codes = @{ Boot = 0; System = 1; Automatic = 2; AutomaticDelayedStart = 2; Manual = 3; Disabled = 4 }
        $k = $null
        try { $k = $this.OpenServiceKey($Name, $true) }
        catch { throw ("Could not write service start type: {0} (sc.exe {1}: {2}; registry: {3})" -f $Name, $code, (($out | Out-String).Trim()), $_.Exception.Message) }
        if ($null -eq $k) { throw "Service registration not found: $Name" }
        try {
            $k.SetValue('Start', [int]$codes[$StartType], [Microsoft.Win32.RegistryValueKind]::DWord)
            if ($StartType -eq 'AutomaticDelayedStart') { $k.SetValue('DelayedAutostart', 1, [Microsoft.Win32.RegistryValueKind]::DWord) }
            elseif (@($k.GetValueNames()) -contains 'DelayedAutostart') { $k.SetValue('DelayedAutostart', 0, [Microsoft.Win32.RegistryValueKind]::DWord) }
        }
        finally { $k.Dispose() }
    }

    [void] StartService([string] $Name) {
        Start-Service -Name $Name -ErrorAction Stop
    }

    [void] StopService([string] $Name) {
        Stop-Service -Name $Name -ErrorAction Stop
    }
}
