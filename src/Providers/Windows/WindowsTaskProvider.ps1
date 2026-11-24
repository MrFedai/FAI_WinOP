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
}
