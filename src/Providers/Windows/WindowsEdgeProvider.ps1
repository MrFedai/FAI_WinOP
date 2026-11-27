# Gerçek Edge / WebView2 sağlayıcısı (yönetici gerekir). WebView2 Runtime'a ve EdgeUpdate'e (WebView2 güncellemesi onunla
# gelir) hiçbir yöntem dokunmaz; yalnız msedge süreçleri durdurulur, msedgewebview2 çalışmaya devam eder.
#
# Kaldırma: Edge'in kendi kurucusu (Application\<sürüm>\Installer\setup.exe) --uninstall --system-level --force-uninstall
# ile çalışır. Kurucu AB dışı bölgede kaldırmayı reddeder; eski (UWP) Edge'in SystemApps klasöründe MicrosoftEdge.exe
# varsa izin verir. Bu dosya yoksa geçici olarak boş oluşturulur ve kaldırmadan sonra silinir (FR33THY/Ultimate'te
# incelenen yöntem; kod ondan alınmadı). Kurucu çıkış kodu güvenilmez: msedge.exe gidene kadar beklenir.

class WindowsEdgeProvider : IEdgeProvider {
    static [string] $EdgeAppId = '{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}'
    static [string] $WebView2AppId = '{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'

    WindowsEdgeProvider() { }

    static [string[]] ApplicationDirs() {
        $dirs = New-Object 'System.Collections.Generic.List[string]'
        foreach ($root in @(${env:ProgramFiles(x86)}, $env:ProgramFiles)) {
            if ($root) { $dirs.Add((Join-Path $root 'Microsoft\Edge\Application')) }
        }
        return $dirs.ToArray()
    }

    hidden [string] EdgeExe() {
        foreach ($d in [WindowsEdgeProvider]::ApplicationDirs()) {
            $exe = Join-Path $d 'msedge.exe'
            if (Test-Path -LiteralPath $exe -PathType Leaf) { return $exe }
        }
        return ''
    }

    # EdgeUpdate'in Clients kaydındaki sürüm (pv); '0.0.0.0' kurulu değil demektir.
    static [string] ClientVersion([string] $AppId) {
        foreach ($key in @("HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\$AppId", "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\$AppId",
                "HKCU:\Software\Microsoft\EdgeUpdate\Clients\$AppId")) {
            $pv = [string](Get-ItemProperty -LiteralPath $key -Name 'pv' -ErrorAction SilentlyContinue).pv
            if ($pv -and $pv -ne '0.0.0.0') { return $pv }
        }
        return ''
    }

    [string] GetEdgeVersion() {
        $exe = $this.EdgeExe()
        if (-not $exe) { return '' }
        $v = [WindowsEdgeProvider]::ClientVersion([WindowsEdgeProvider]::EdgeAppId)
        if (-not $v) { $v = [string](Get-Item -LiteralPath $exe).VersionInfo.ProductVersion }
        if (-not $v) { $v = 'bilinmeyen sürüm' }
        return $v
    }

    [string] GetWebView2Version() { return [WindowsEdgeProvider]::ClientVersion([WindowsEdgeProvider]::WebView2AppId) }

    hidden [string] FindSetup() {
        foreach ($d in [WindowsEdgeProvider]::ApplicationDirs()) {
            if (-not (Test-Path -LiteralPath $d)) { continue }
            $found = @(Get-ChildItem -LiteralPath $d -Directory -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -match '^\d+(\.\d+){3}$' } |
                    Sort-Object { [version]$_.Name } -Descending |
                    ForEach-Object { Join-Path $_.FullName 'Installer\setup.exe' } |
                    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
            if ($found.Count -gt 0) { return $found[0] }
        }
        return ''
    }

    [void] UninstallEdge() {
        $setup = $this.FindSetup()
        if (-not $setup) { throw 'Edge kurucusu (Installer\setup.exe) bulunamadı.' }

        Get-Process -Name 'msedge' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

        $legacyDir = Join-Path $env:SystemRoot 'SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe'
        $legacyExe = Join-Path $legacyDir 'MicrosoftEdge.exe'
        $createdDir = -not (Test-Path -LiteralPath $legacyDir)
        $createdExe = -not (Test-Path -LiteralPath $legacyExe)
        try {
            if ($createdDir) { [void](New-Item -ItemType Directory -Path $legacyDir -Force) }
            if ($createdExe) { [void](New-Item -ItemType File -Path $legacyExe -Force) }
            $argList = '--uninstall --msedge --channel=stable --system-level --force-uninstall --verbose-logging'
            [void][ExternalProcess]::Run($setup, $argList, [ExternalProcess]::EdgeSetupTimeoutSeconds, 'Edge kurucusu (setup.exe)', $false)
            $deadline = (Get-Date).AddSeconds(90)
            while ($this.EdgeExe() -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 2 }
        }
        finally {
            if ($createdExe) { Remove-Item -LiteralPath $legacyExe -Force -ErrorAction SilentlyContinue }
            if ($createdDir) { Remove-Item -LiteralPath $legacyDir -Recurse -Force -ErrorAction SilentlyContinue }
        }

        # Kurucunun bazen bıraktığı kısayollar (geri almada Edge kurulumu yeniden oluşturur).
        foreach ($lnk in @(
                (Join-Path $env:PUBLIC 'Desktop\Microsoft Edge.lnk'),
                (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk'),
                (Join-Path $env:APPDATA 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk'))) {
            if (Test-Path -LiteralPath $lnk -PathType Leaf) { Remove-Item -LiteralPath $lnk -Force -ErrorAction SilentlyContinue }
        }
        if ($this.EdgeExe()) { throw "Edge kurucusu kaldırmayı tamamlamadı: $setup" }
    }

    # winget ile sistem düzeyinde kurulum. EdgeUpdate'in Install{Edge} ilkesi 0 ise kurulum engellenebilir; tweak'te
    # ilke geri almada önce kalktığı için sıra doğru (bkz. EdgeRemoveAction).
    [void] InstallEdge() { ([WindowsPackageProvider]::new()).Install('Microsoft.Edge', 'winget') }
}
