# Bellek içi sahte servis yöneticisi. Yazma çağrılarını sayar ve kaydeder.
class FakeServiceManager : IServiceManager {
    # küçük harf ad → @{ Name; StartType; Status }
    [hashtable] $Services = @{}
    [int] $WriteCount = 0
    [System.Collections.ArrayList] $WriteLog = (New-Object System.Collections.ArrayList)

    FakeServiceManager() { }

    [void] Seed([string] $Name, [string] $StartType, [string] $Status) {
        $this.Services[$Name.ToLowerInvariant()] = @{ Name = $Name; StartType = $StartType; Status = $Status }
    }

    [bool] ServiceExists([string] $Name) { return $this.Services.ContainsKey($Name.ToLowerInvariant()) }

    [string] GetStartType([string] $Name) { return [string]$this.Services[$Name.ToLowerInvariant()]['StartType'] }

    [string] GetStatus([string] $Name) { return [string]$this.Services[$Name.ToLowerInvariant()]['Status'] }

    [void] SetStartType([string] $Name, [string] $StartType) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("SetStartType $Name $StartType")
        $this.Services[$Name.ToLowerInvariant()]['StartType'] = $StartType
    }

    [void] StartService([string] $Name) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("StartService $Name")
        $this.Services[$Name.ToLowerInvariant()]['Status'] = 'Running'
    }

    [void] StopService([string] $Name) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("StopService $Name")
        $this.Services[$Name.ToLowerInvariant()]['Status'] = 'Stopped'
    }

    # Sıralı, karşılaştırılabilir döküm: 'ad|başlangıç|durum'.
    [string[]] Dump() {
        $lines = New-Object 'System.Collections.Generic.List[string]'
        foreach ($s in $this.Services.Values) { $lines.Add(('{0}|{1}|{2}' -f $s['Name'], $s['StartType'], $s['Status'])) }
        $arr = $lines.ToArray()
        [System.Array]::Sort($arr, [System.StringComparer]::Ordinal)
        return $arr
    }
}
