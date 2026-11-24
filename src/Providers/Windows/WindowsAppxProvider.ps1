# Gerçek Appx sağlayıcısı (Appx + DISM modülleri; yönetici gerekir). Ad birebir eşleşir (joker yok).

class WindowsAppxProvider : IAppxProvider {
    WindowsAppxProvider() { }

    [string[]] GetInstalled() {
        return [string[]]@(Get-AppxPackage -ErrorAction Stop | ForEach-Object { $_.Name } | Sort-Object -Unique)
    }

    [string[]] GetProvisioned() {
        return [string[]]@(Get-AppxProvisionedPackage -Online -ErrorAction Stop | ForEach-Object { $_.DisplayName } | Sort-Object -Unique)
    }

    [void] RemoveInstalled([string] $Name) {
        $pkgs = @(Get-AppxPackage -Name $Name -ErrorAction Stop | Where-Object { $_.Name -eq $Name })
        foreach ($p in $pkgs) { Remove-AppxPackage -Package $p.PackageFullName -ErrorAction Stop }
    }

    [void] RemoveProvisioned([string] $Name) {
        $pkgs = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop | Where-Object { $_.DisplayName -eq $Name })
        foreach ($p in $pkgs) { Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction Stop | Out-Null }
    }

    # Kopya: başka kullanıcıda / sistemde duran paket ya da provisioned paketin bildirimi (AppxManifest.xml).
    [void] RestoreInstalled([string] $Name) {
        $manifest = ''
        $any = @(Get-AppxPackage -AllUsers -Name $Name -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $Name -and $_.InstallLocation })
        if ($any.Count -gt 0) { $manifest = Join-Path $any[0].InstallLocation 'AppxManifest.xml' }
        if (-not $manifest -or -not (Test-Path -LiteralPath $manifest)) {
            $prov = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq $Name -and $_.InstallLocation })
            if ($prov.Count -gt 0) {
                $manifest = [Environment]::ExpandEnvironmentVariables([string]$prov[0].InstallLocation)
                if ($manifest -notmatch '\.xml$') { $manifest = Join-Path $manifest 'AppxManifest.xml' }
            }
        }
        if (-not $manifest -or -not (Test-Path -LiteralPath $manifest)) { throw "Paketin makinede kopyası yok: $Name" }
        Add-AppxPackage -Register $manifest -DisableDevelopmentMode -ErrorAction Stop
    }
}
