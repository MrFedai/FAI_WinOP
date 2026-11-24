# Gerçek zamanlanmış görevler (ScheduledTasks modülü). Yol: '\Klasör\Alt\GörevAdı'.

class WindowsTaskProvider : ITaskProvider {
    WindowsTaskProvider() { }

    # '\A\B\Ad' → @('\A\B\', 'Ad')
    static [string[]] SplitPath([string] $TaskPath) {
        $i = $TaskPath.LastIndexOf('\')
        if ($i -lt 0) { return [string[]]@('\', $TaskPath) }
        return [string[]]@($TaskPath.Substring(0, $i + 1), $TaskPath.Substring($i + 1))
    }

    hidden [object] Find([string] $TaskPath) {
        $p = [WindowsTaskProvider]::SplitPath($TaskPath)
        # -TaskPath / -TaskName joker kabul eder; sonuç birebir adla süzülür.
        $found = @(Get-ScheduledTask -TaskPath $p[0] -TaskName $p[1] -ErrorAction SilentlyContinue |
                Where-Object { $_.TaskPath -eq $p[0] -and $_.TaskName -eq $p[1] })
        if ($found.Count -eq 0) { return $null }
        return $found[0]
    }

    [string] GetTaskState([string] $TaskPath) {
        $t = $this.Find($TaskPath)
        if ($null -eq $t) { return '' }
        if ($t.State.ToString() -eq 'Disabled') { return 'Disabled' }
        return 'Enabled'
    }

    [void] SetTaskEnabled([string] $TaskPath, [bool] $Enabled) {
        $p = [WindowsTaskProvider]::SplitPath($TaskPath)
        if ($Enabled) { Enable-ScheduledTask -TaskPath $p[0] -TaskName $p[1] -ErrorAction Stop | Out-Null }
        else { Disable-ScheduledTask -TaskPath $p[0] -TaskName $p[1] -ErrorAction Stop | Out-Null }
    }

    [hashtable] GetTaskAction([string] $TaskPath) {
        $t = $this.Find($TaskPath)
        if ($null -eq $t) { return $null }
        $exec = @($t.Actions | Where-Object { $_.Execute })
        if ($exec.Count -eq 0) { return @{ Execute = ''; Arguments = '' } }
        return @{ Execute = [string]$exec[0].Execute; Arguments = [string]$exec[0].Arguments }
    }

    # Açılışta, SYSTEM hesabıyla, en yüksek yetkiyle; pil ile de çalışır; 1 saatte bitmezse durdurulur.
    [void] RegisterStartupTask([string] $TaskPath, [string] $Execute, [string] $Arguments, [string] $Description) {
        $p = [WindowsTaskProvider]::SplitPath($TaskPath)
        $action = New-ScheduledTaskAction -Execute $Execute -Argument $Arguments
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1)
        Register-ScheduledTask -TaskPath $p[0] -TaskName $p[1] -Action $action -Trigger $trigger -Principal $principal -Settings $settings `
            -Description $Description -Force -ErrorAction Stop | Out-Null
    }

    [void] UnregisterTask([string] $TaskPath) {
        $t = $this.Find($TaskPath)
        if ($null -eq $t) { return }
        Unregister-ScheduledTask -TaskPath $t.TaskPath -TaskName $t.TaskName -Confirm:$false -ErrorAction Stop
    }
}
