# Gerçek Windows Update sağlayıcısı: Windows Update Agent COM API'si (Microsoft.Update.Session). Arama bir iki dakika
# sürebilir; kurulum güncelleme başına ilerleme basar ([i/N] yüzde, geçen süre, tahmini kalan).
# Ölçüt: kurulmamış, gizlenmemiş yazılım güncellemeleri (sürücüler 'Driver' türünde: dahil değil, sürücüler ayrı iş).

class WindowsUpdateProvider : IUpdateProvider {
    WindowsUpdateProvider() { }

    static [string] Criteria() { return "IsInstalled=0 and IsHidden=0 and Type='Software'" }

    hidden [object] NewSession() {
        $s = New-Object -ComObject 'Microsoft.Update.Session'
        $s.ClientApplicationID = 'FAI_WinOP'
        return $s
    }

    hidden [object[]] Search([object] $Session) {
        $result = $Session.CreateUpdateSearcher().Search([WindowsUpdateProvider]::Criteria())
        $list = New-Object 'System.Collections.Generic.List[object]'
        for ($i = 0; $i -lt $result.Updates.Count; $i++) { $list.Add($result.Updates.Item($i)) }
        return $list.ToArray()
    }

    [string[]] GetPending() {
        return [string[]]@($this.Search($this.NewSession()) | ForEach-Object { [string]$_.Title })
    }

    [hashtable] InstallPending() {
        $session = $this.NewSession()
        $updates = @($this.Search($session))
        $total = $updates.Count
        $ok = 0
        $failed = 0
        $reboot = $false
        $clock = [System.Diagnostics.Stopwatch]::StartNew()
        for ($i = 0; $i -lt $total; $i++) {
            $u = $updates[$i]
            $eta = ''
            if ($i -gt 0) { $eta = ', tahmini kalan {0:mm\:ss}' -f [TimeSpan]::FromSeconds($clock.Elapsed.TotalSeconds / $i * ($total - $i)) }
            Write-Host ('[{0}/{1}] %{2} — {3} (geçen {4:mm\:ss}{5})' -f ($i + 1), $total, [int](100 * $i / $total), $u.Title, $clock.Elapsed, $eta)
            try {
                if (-not $u.EulaAccepted) { $u.AcceptEula() }
                $coll = New-Object -ComObject 'Microsoft.Update.UpdateColl'
                [void]$coll.Add($u)
                if (-not $u.IsDownloaded) {
                    $dl = $session.CreateUpdateDownloader()
                    $dl.Updates = $coll
                    [void]$dl.Download()
                }
                $inst = $session.CreateUpdateInstaller()
                $inst.Updates = $coll
                $r = $inst.Install()
                # ResultCode: 2 başarılı, 3 hatalarla başarılı.
                if ([int]$r.ResultCode -eq 2 -or [int]$r.ResultCode -eq 3) { $ok++ }
                else {
                    $failed++
                    Write-Host ('  kurulamadı (sonuç {0}, HRESULT 0x{1:X8})' -f $r.ResultCode, $r.HResult) -ForegroundColor Yellow
                }
                if ($r.RebootRequired) { $reboot = $true }
            }
            catch {
                $failed++
                Write-Host ('  kurulamadı: {0}' -f $_.Exception.Message) -ForegroundColor Yellow
            }
        }
        if ($total -gt 0) { Write-Host ('[{0}/{0}] %100 — {1} kuruldu, {2} başarısız ({3:mm\:ss})' -f $total, $ok, $failed, $clock.Elapsed) }
        return @{ Installed = $ok; Failed = $failed; RebootRequired = ($reboot -or $this.IsRebootPending()) }
    }

    [bool] IsRebootPending() {
        try {
            if ((New-Object -ComObject 'Microsoft.Update.SystemInfo').RebootRequired) { return $true }
        }
        catch { $null = $_ }
        $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)
        try {
            $k = $base.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
            if ($null -ne $k) {
                $k.Dispose()
                return $true
            }
            return $false
        }
        finally { $base.Dispose() }
    }
}
