# Gerçek paket sağlayıcısı: winget.exe (kaynak winget ya da msstore). Çıktı yerelleştirilmiş olabilir: yalnız çıkış
# kodlarına bakılır. Sessiz kurulum, sözleşmeler kabul, etkileşim kapalı.

class WindowsPackageProvider : IPackageProvider {
    # winget çıkış kodları (APPINSTALLER_CLI_ERROR_*)
    static [int] $NoPackageFound = -1978335212          # 0x8A150014
    static [int] $UpdateNotApplicable = -1978335189     # 0x8A15002B (zaten kurulu / güncel)
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
        throw 'winget bulunamadı (App Installer kurulu değil)'
    }

    hidden [int] Invoke([string[]] $Arguments) {
        $path = $this.Resolve()
        $out = & $path @Arguments 2>&1
        $this.LastOutput = (@($out) | ForEach-Object { [string]$_ }) -join "`n"
        return [int]$global:LASTEXITCODE
    }

    hidden [string] Tail() {
        $lines = @($this.LastOutput -split "`r?`n|`r" | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch '^[\s\-\\|/█▒]+$' })
        return (($lines | Select-Object -Last 4) -join ' | ')
    }

    [bool] IsInstalled([string] $PackageId, [string] $Source) {
        $code = $this.Invoke([string[]]@('list', '--id', $PackageId, '--exact', '--source', $Source,
                '--accept-source-agreements', '--disable-interactivity'))
        if ($code -eq 0) { return $true }
        if ($code -eq [WindowsPackageProvider]::NoPackageFound) { return $false }
        throw ('winget list başarısız ({0}): {1}' -f $code, $this.Tail())
    }

    [void] Install([string] $PackageId, [string] $Source) {
        $code = $this.Invoke([string[]]@('install', '--id', $PackageId, '--exact', '--source', $Source, '--silent',
                '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity'))
        if ($code -eq 0 -or $code -eq [WindowsPackageProvider]::UpdateNotApplicable) { return }
        throw ('winget install {0} başarısız ({1}): {2}' -f $PackageId, $code, $this.Tail())
    }

    [void] Uninstall([string] $PackageId, [string] $Source) {
        $code = $this.Invoke([string[]]@('uninstall', '--id', $PackageId, '--exact', '--source', $Source, '--silent',
                '--accept-source-agreements', '--disable-interactivity'))
        if ($code -ne 0 -and $code -ne [WindowsPackageProvider]::NoPackageFound) {
            throw ('winget uninstall {0} başarısız ({1}): {2}' -f $PackageId, $code, $this.Tail())
        }
        $this.WaitUntilGone($PackageId, $Source, $this.Tail())
    }

    [void] RunUninstaller([string] $PackageId, [string] $Source, [string] $FilePath, [string] $Arguments) {
        if (-not [System.IO.File]::Exists($FilePath)) { throw ('{0}: kaldırıcı yok: {1}' -f $PackageId, $FilePath) }
        $p = $null
        if ($Arguments) { $p = Start-Process -FilePath $FilePath -ArgumentList $Arguments -PassThru -Wait }
        else { $p = Start-Process -FilePath $FilePath -PassThru -Wait }
        if ($p.ExitCode -ne 0) { throw ('{0}: kaldırıcı {1} çıkış kodu {2}' -f $PackageId, $FilePath, $p.ExitCode) }
        $this.WaitUntilGone($PackageId, $Source, ('{0} {1}' -f $FilePath, $Arguments))
    }

    # Bazı kaldırıcılar (NSIS) kendini geçici klasöre kopyalayıp hemen çıkar; kaldırma sürer. Paket listeden düşene kadar
    # beklenir; düşmezse sessizce geçilmez. Kaldırıcı etkileşimli açıldıysa (winget sessiz komut bulamadı) da burada yakalanır.
    hidden [void] WaitUntilGone([string] $PackageId, [string] $Source, [string] $Detail) {
        $deadline = [DateTime]::UtcNow.AddSeconds([WindowsPackageProvider]::UninstallWaitSeconds)
        while ($this.IsInstalled($PackageId, $Source)) {
            if ([DateTime]::UtcNow -gt $deadline) {
                throw ('{0}: kaldırıcı {1} sn içinde bitmedi, paket hâlâ kurulu (etkileşimli açılmış olabilir: katalogda quietUninstall); {2}' -f $PackageId, [WindowsPackageProvider]::UninstallWaitSeconds, $Detail)
            }
            Start-Sleep -Seconds 3
        }
    }
}
