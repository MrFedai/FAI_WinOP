# Betik çalıştırıcı ve native sağlayıcılar (ses: AudioEndpoint.cs bellekte; zamanlayıcı: TimerResolution.cs → servis .exe).
# Native tipler bundle ayrıştırılırken yoktur: sınıf gövdesinde [FaiWinOP.Native.X] yazılamaz, ('...' -as [type]) kullanılır.

# 5.1 tuzağı: sınıf yönteminde 'return (& $betik)' betik çıktı vermezse 'Index was out of range' fırlatır;
# çıktı önce @() ile toplanır.
class WindowsScriptHost : IScriptHost {
    WindowsScriptHost() { }

    static [object] Invoke([string] $Code, [object] $Argument) {
        $out = @(& ([scriptblock]::Create($Code)) $Argument)
        if ($out.Count -eq 0) { return $null }
        if ($out.Count -eq 1) { return $out[0] }
        return $out
    }

    [object] Query([string] $Code, [object] $Argument) { return [WindowsScriptHost]::Invoke($Code, $Argument) }

    [object] Run([string] $Code, [object] $Argument) { return [WindowsScriptHost]::Invoke($Code, $Argument) }
}

class WindowsAudioProvider : IAudioProvider {
    WindowsAudioProvider() { }

    static [type] Native() {
        $t = 'FaiWinOP.Native.AudioEndpoint' -as [type]
        if ($null -eq $t) {
            Add-Type -TypeDefinition (Get-FaiNativeSource -Name 'AudioEndpoint') -Language CSharp -ErrorAction Stop
            $t = 'FaiWinOP.Native.AudioEndpoint' -as [type]
        }
        return $t
    }

    [bool] HasDevice() {
        $t = [WindowsAudioProvider]::Native()
        return [bool]$t::HasDevice()
    }

    [int] GetVolume() {
        $t = [WindowsAudioProvider]::Native()
        return [int]$t::GetVolume()
    }

    [void] SetVolume([int] $Level) {
        $t = [WindowsAudioProvider]::Native()
        $t::SetVolume($Level)
    }

    [bool] GetMute() {
        $t = [WindowsAudioProvider]::Native()
        return [bool]$t::GetMute()
    }

    [void] SetMute([bool] $Mute) {
        $t = [WindowsAudioProvider]::Native()
        $t::SetMute($Mute)
    }
}

# Servis: FAI_TimerResolution · ikili: %ProgramFiles%\FAI_WinOP\FAI_TimerResolution.exe · ImagePath: "<exe>" <çözünürlük>.
# Derleme ayrı bir powershell.exe (5.1) sürecinde: aynı oturumda aynı tipi ikinci kez derlemek çakışır.
class WindowsTimerResolutionProvider : ITimerResolutionProvider {
    [string] $ServiceName = 'FAI_TimerResolution'
    [string] $InstallDir

    WindowsTimerResolutionProvider() { $this.InstallDir = Join-Path $env:ProgramFiles 'FAI_WinOP' }

    [string] ExePath() { return (Join-Path $this.InstallDir 'FAI_TimerResolution.exe') }

    [bool] IsInstalled() { return ($null -ne (Get-Service -Name $this.ServiceName -ErrorAction SilentlyContinue)) }

    [int] GetResolution() {
        if (-not $this.IsInstalled()) { return 0 }
        $image = ''
        $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)
        try {
            $k = $base.OpenSubKey('SYSTEM\CurrentControlSet\Services\' + $this.ServiceName)
            if ($null -eq $k) { return 0 }
            try { $image = [string]$k.GetValue('ImagePath', '') }
            finally { $k.Dispose() }
        }
        finally { $base.Dispose() }
        $m = [regex]::Match($image, '\s(\d+)\s*$')
        if ($m.Success) { return [int]$m.Groups[1].Value }
        return 5000
    }

    [void] Install([int] $Resolution) {
        if ($this.IsInstalled()) { $this.Uninstall() }
        if (-not (Test-Path -LiteralPath $this.InstallDir)) { New-Item -ItemType Directory -Path $this.InstallDir -Force | Out-Null }
        $exe = $this.ExePath()
        $cs = Join-Path $this.InstallDir 'TimerResolution.cs'
        [System.IO.File]::WriteAllText($cs, (Get-FaiNativeSource -Name 'TimerResolution'), (New-Object System.Text.UTF8Encoding($true)))
        try {
            $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
            $cmd = "Add-Type -Path '{0}' -OutputAssembly '{1}' -OutputType ConsoleApplication -ReferencedAssemblies System.ServiceProcess -ErrorAction Stop" -f $cs.Replace("'", "''"), $exe.Replace("'", "''")
            $out = & $ps -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command $cmd 2>&1
            if ($global:LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exe)) {
                throw ('TimerResolution could not be compiled: {0}' -f ((@($out) | ForEach-Object { [string]$_ }) -join ' ').Trim())
            }
        }
        finally { Remove-Item -LiteralPath $cs -Force -ErrorAction SilentlyContinue }
        New-Service -Name $this.ServiceName -BinaryPathName ('"{0}" {1}' -f $exe, $Resolution) -DisplayName 'FAI_WinOP Timer Resolution' `
            -Description 'FAI_WinOP: timer resolution request (src/Native/TimerResolution.cs).' -StartupType Automatic -ErrorAction Stop | Out-Null
        Start-Service -Name $this.ServiceName -ErrorAction Stop
    }

    [void] Uninstall() {
        if ($this.IsInstalled()) {
            Stop-Service -Name $this.ServiceName -ErrorAction SilentlyContinue
            $out = & sc.exe delete $this.ServiceName 2>&1
            if ($global:LASTEXITCODE -ne 0) { throw ('Could not delete service: {0}' -f ((@($out) | ForEach-Object { [string]$_ }) -join ' ').Trim()) }
            for ($i = 0; $i -lt 20 -and $this.IsInstalled(); $i++) { Start-Sleep -Milliseconds 250 }
        }
        $exe = $this.ExePath()
        for ($i = 0; $i -lt 20 -and (Test-Path -LiteralPath $exe); $i++) {
            try { Remove-Item -LiteralPath $exe -Force -ErrorAction Stop }
            catch { Start-Sleep -Milliseconds 250 }
        }
        if ((Test-Path -LiteralPath $this.InstallDir) -and @(Get-ChildItem -LiteralPath $this.InstallDir -Force).Count -eq 0) {
            Remove-Item -LiteralPath $this.InstallDir -Force -ErrorAction SilentlyContinue
        }
    }
}
