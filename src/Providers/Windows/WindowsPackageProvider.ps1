# Gerçek paket sağlayıcısı: winget.exe (kaynak winget ya da msstore). Çıktı yerelleştirilmiş olabilir: yalnız çıkış
# kodlarına bakılır. Sessiz kurulum, sözleşmeler kabul, etkileşim kapalı.

# Dış süreç yardımcısı: zaman aşımı + aşımda süreç ağacı sonlandırma (taskkill /T /F). Çıktı (stdout + stderr) isteğe
# bağlı yakalanır; iki akış da eşzamansız okunur (tampon dolup kilitlenme olmasın).
class ExternalProcessResult {
    [int] $ExitCode = 0
    [string] $Output = ''
}

class ExternalProcess {
    # Zaman aşımı süreleri (sn).
    static [int] $WingetListTimeoutSeconds = 120         # 2 dk
    static [int] $WingetChangeTimeoutSeconds = 1800      # 30 dk (install / uninstall)
    static [int] $EdgeSetupTimeoutSeconds = 600          # 10 dk
    static [int] $UninstallerTimeoutSeconds = 900        # 15 dk

    # Argüman dizisi -> tek komut satırı dizesi (boşluk / tırnak içerenler çift tırnaklanır).
    static [string] BuildArguments([string[]] $Arguments) {
        $parts = New-Object 'System.Collections.Generic.List[string]'
        foreach ($a in @($Arguments)) {
            if ($null -eq $a -or $a.Length -eq 0) { $parts.Add('""') }
            elseif ($a -match '[\s"]') { $parts.Add('"' + ($a -replace '"', '\"') + '"') }
            else { $parts.Add($a) }
        }
        return ($parts -join ' ')
    }

    # Zaman aşımı iletisi: "<ne> <n> dk içinde bitmedi, süreç ağacı sonlandırıldı".
    static [string] TimeoutMessage([string] $What, [int] $Seconds) {
        $min = ([double]$Seconds / 60.0).ToString('0.##', [System.Globalization.CultureInfo]::InvariantCulture)
        return ('{0} did not finish within {1} min, process tree terminated' -f $What, $min)
    }

    static [ExternalProcessResult] Run([string] $FilePath, [string] $ArgumentLine, [int] $TimeoutSeconds, [string] $What, [bool] $Capture) {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $FilePath
        $psi.Arguments = $ArgumentLine
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        if ($Capture) {
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
            $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
        }
        $p = [System.Diagnostics.Process]::Start($psi)
        try {
            $outTask = $null
            $errTask = $null
            if ($Capture) {
                $outTask = $p.StandardOutput.ReadToEndAsync()
                $errTask = $p.StandardError.ReadToEndAsync()
            }
            if (-not $p.WaitForExit($TimeoutSeconds * 1000)) {
                [ExternalProcess]::KillTree($p)
                throw ([ExternalProcess]::TimeoutMessage($What, $TimeoutSeconds))
            }
            $p.WaitForExit()
            $r = New-Object ExternalProcessResult
            $r.ExitCode = $p.ExitCode
            if ($Capture) {
                $r.Output = ((@($outTask.Result, $errTask.Result) | Where-Object { $_ }) -join "`n")
            }
            return $r
        }
        finally { $p.Dispose() }
    }

    static [void] KillTree([System.Diagnostics.Process] $P) {
        try {
            $tkPsi = New-Object System.Diagnostics.ProcessStartInfo
            $tkPsi.FileName = (Join-Path $env:SystemRoot 'System32\taskkill.exe')
            $tkPsi.Arguments = ('/PID {0} /T /F' -f $P.Id)
            $tkPsi.UseShellExecute = $false
            $tkPsi.CreateNoWindow = $true
            $tp = [System.Diagnostics.Process]::Start($tkPsi)
            [void]$tp.WaitForExit(30000)
            $tp.Dispose()
        }
        catch { Write-Verbose ('taskkill could not start: ' + $_.Exception.Message) }
        try { if (-not $P.HasExited) { $P.Kill() } } catch { Write-Verbose ('process could not be terminated: ' + $_.Exception.Message) }
        try { [void]$P.WaitForExit(10000) } catch { Write-Verbose ('could not wait for process: ' + $_.Exception.Message) }
    }
}

class WindowsPackageProvider : IPackageProvider {
    # winget çıkış kodları (APPINSTALLER_CLI_ERROR_*)
    static [int] $NoPackageFound = -1978335212          # 0x8A150014
    static [int] $UpdateNotApplicable = -1978335189     # 0x8A15002B (zaten kurulu / güncel)
    static [int] $RebootRequired = 3010                 # ERROR_SUCCESS_REBOOT_REQUIRED (MSI / kaldırıcı: başarılı, yeniden başlatma gerekli)
    # Kaldırma sonrası paketin listeden düşmesi için en çok bekleme.
    static [int] $UninstallWaitSeconds = 120

    hidden [string] $WingetPath = ''
    [string] $LastOutput = ''

    WindowsPackageProvider() { }

    # PATH'te yoksa (yönetici / SYSTEM oturumu) App Installer klasörü denenir.
    hidden [string] Resolve() {
        if ($this.WingetPath) { return $this.WingetPath }
        $cmd = Get-Command -Name 'winget.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd) { $this.WingetPath = $cmd.Source; return $this.WingetPath }
        $pattern = Join-Path $env:ProgramFiles 'WindowsApps\Microsoft.DesktopAppInstaller_*_8wekyb3d8bbwe\winget.exe'
        $found = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
        if ($found) { $this.WingetPath = $found.FullName; return $this.WingetPath }
        throw 'winget not found (App Installer is not installed)'
    }

    hidden [int] Invoke([string[]] $Arguments, [int] $TimeoutSeconds) {
        $path = $this.Resolve()
        $this.LastOutput = ''
        $what = 'winget ' + [string]$Arguments[0]
        $r = [ExternalProcess]::Run($path, [ExternalProcess]::BuildArguments($Arguments), $TimeoutSeconds, $what, $true)
        $this.LastOutput = $r.Output
        return $r.ExitCode
    }

    hidden [string] Tail() {
        $lines = @($this.LastOutput -split "`r?`n|`r" | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch '^[\s\-\\|/█▒]+$' })
        return (($lines | Select-Object -Last 4) -join ' | ')
    }

    [bool] IsInstalled([string] $PackageId, [string] $Source) {
        $code = $this.Invoke([string[]]@('list', '--id', $PackageId, '--exact', '--source', $Source,
                '--accept-source-agreements', '--disable-interactivity'), [ExternalProcess]::WingetListTimeoutSeconds)
        if ($code -eq 0) { return $true }
        if ($code -eq [WindowsPackageProvider]::NoPackageFound) { return $false }
        throw ('winget list failed ({0}): {1}' -f $code, $this.Tail())
    }

    [void] Install([string] $PackageId, [string] $Source) {
        $code = $this.Invoke([string[]]@('install', '--id', $PackageId, '--exact', '--source', $Source, '--silent',
                '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity'), [ExternalProcess]::WingetChangeTimeoutSeconds)
        if ($code -eq 0 -or $code -eq [WindowsPackageProvider]::UpdateNotApplicable) { return }
        throw ('winget install {0} failed ({1}): {2}' -f $PackageId, $code, $this.Tail())
    }

    [void] Uninstall([string] $PackageId, [string] $Source) {
        $code = $this.Invoke([string[]]@('uninstall', '--id', $PackageId, '--exact', '--source', $Source, '--silent',
                '--accept-source-agreements', '--disable-interactivity'), [ExternalProcess]::WingetChangeTimeoutSeconds)
        if ($code -ne 0 -and $code -ne [WindowsPackageProvider]::NoPackageFound) {
            throw ('winget uninstall {0} failed ({1}): {2}' -f $PackageId, $code, $this.Tail())
        }
        $this.WaitUntilGone($PackageId, $Source, $this.Tail())
    }

    [void] RunUninstaller([string] $PackageId, [string] $Source, [string] $FilePath, [string] $Arguments) {
        if (-not [System.IO.File]::Exists($FilePath)) { throw ('{0}: uninstaller not found: {1}' -f $PackageId, $FilePath) }
        $r = [ExternalProcess]::Run($FilePath, $Arguments, [ExternalProcess]::UninstallerTimeoutSeconds, ('{0}: uninstaller {1}' -f $PackageId, $FilePath), $false)
        if (-not [WindowsPackageProvider]::IsUninstallerSuccess($r.ExitCode)) { throw ('{0}: uninstaller {1} exit code {2}' -f $PackageId, $FilePath, $r.ExitCode) }
        $this.WaitUntilGone($PackageId, $Source, ('{0} {1}' -f $FilePath, $Arguments))
    }

    # Kaldırıcı çıkış kodu: 0 ya da 3010 (yeniden başlatma gerekli) başarı.
    static [bool] IsUninstallerSuccess([int] $Code) {
        return ($Code -eq 0 -or $Code -eq [WindowsPackageProvider]::RebootRequired)
    }

    # Bazı kaldırıcılar (NSIS) kendini geçici klasöre kopyalayıp hemen çıkar; kaldırma sürer. Paket listeden düşene kadar
    # beklenir; düşmezse sessizce geçilmez. Kaldırıcı etkileşimli açıldıysa (winget sessiz komut bulamadı) da burada yakalanır.
    hidden [void] WaitUntilGone([string] $PackageId, [string] $Source, [string] $Detail) {
        $deadline = [DateTime]::UtcNow.AddSeconds([WindowsPackageProvider]::UninstallWaitSeconds)
        while ($this.IsInstalled($PackageId, $Source)) {
            if ([DateTime]::UtcNow -gt $deadline) {
                throw ('{0}: uninstaller did not finish within {1} s, package is still installed (it may have opened interactively: see quietUninstall in the catalog); {2}' -f $PackageId, [WindowsPackageProvider]::UninstallWaitSeconds, $Detail)
            }
            Start-Sleep -Seconds 3
        }
    }
}
