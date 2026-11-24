# Kabuk yenileme (explorer.exe, duvar kağıdı, tema yayını, Başlat), tek renkli görüntü (System.Drawing) ve paketli
# uygulama ayarları (settings.dat hive'ı, RegLoadAppKey + ShellNative ham değer).
# Native tipler bundle ayrıştırılırken yoktur: sınıf gövdesinde [FaiWinOP.Native.X] yazılamaz, ('...' -as [type]) kullanılır.
# Aynısı System.Drawing için de geçerli (5.1'de derleme yüklenmeden sınıf ayrıştırılamaz): yalnız metin tip adları.

function Get-FaiShellNativeType {
    <# .SYNOPSIS  ShellNative.cs'i (gerekirse derleyip) tipini döndürür. #>
    $t = 'FaiWinOP.Native.ShellNative' -as [type]
    if ($null -eq $t) {
        Add-Type -TypeDefinition (Get-FaiNativeSource -Name 'ShellNative') -Language CSharp -ErrorAction Stop
        $t = 'FaiWinOP.Native.ShellNative' -as [type]
    }
    return $t
}

class WindowsDesktopProvider : IDesktopProvider {
    WindowsDesktopProvider() { }

    # Bu oturumdaki explorer süreçleri (CI / hizmet oturumunda yok).
    static [object[]] ShellProcesses() {
        $sid = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
        return @(Get-Process -Name 'explorer' -ErrorAction SilentlyContinue | Where-Object { $_.SessionId -eq $sid })
    }

    [bool] IsShellRunning() { return (@([WindowsDesktopProvider]::ShellProcesses()).Count -gt 0) }

    [void] Refresh([string] $Kind) {
        switch ($Kind) {
            'Shell' { [WindowsDesktopProvider]::RestartShell() }
            'Desktop' { [WindowsDesktopProvider]::ApplyDesktop() }
            'Settings' {
                $t = Get-FaiShellNativeType
                $t::BroadcastSettingChange('ImmersiveColorSet')
                $t::BroadcastSettingChange('WindowsThemeElement')
            }
            'StartMenu' {
                if (-not $this.IsShellRunning()) { return }
                Get-Process -Name 'StartMenuExperienceHost' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            }
            default { throw "Bilinmeyen yenileme türü: $Kind" }
        }
    }

    [void] Wait([int] $Milliseconds) { Start-Sleep -Milliseconds $Milliseconds }

    # explorer'ı sonlandırır: Gezgin bellekteki düzeni geri yazamaz, yeniden başlarken kayıt defterini okur. Winlogon
    # (AutoRestartShell) kabuğu yeniden başlatır; 15 sn içinde başlamazsa elle başlatılır.
    static [void] RestartShell() {
        $old = @([WindowsDesktopProvider]::ShellProcesses())
        if ($old.Count -eq 0) { return }
        $oldIds = @($old | ForEach-Object { $_.Id })
        $old | Stop-Process -Force -ErrorAction SilentlyContinue
        $deadline = [DateTime]::Now.AddSeconds(15)
        while ([DateTime]::Now -lt $deadline) {
            Start-Sleep -Milliseconds 500
            $new = @([WindowsDesktopProvider]::ShellProcesses() | Where-Object { $oldIds -notcontains $_.Id })
            if ($new.Count -gt 0) {
                # Görev çubuğunun kurulmasını bekle.
                Start-Sleep -Seconds 3
                return
            }
        }
        Start-Process -FilePath (Join-Path $env:SystemRoot 'explorer.exe')
        Start-Sleep -Seconds 3
    }

    # HKCU\Control Panel\Desktop\WallPaper (boş = düz renk) ve Colors\Background ('R G B') oturuma uygulanır.
    static [void] ApplyDesktop() {
        $t = Get-FaiShellNativeType
        $colors = Get-ItemProperty -Path 'HKCU:\Control Panel\Colors' -Name 'Background' -ErrorAction SilentlyContinue
        if ($null -ne $colors) {
            $rgb = @(([string]$colors.Background).Trim() -split '\s+' | ForEach-Object { [int]$_ })
            if ($rgb.Count -eq 3) { $t::SetDesktopColor($rgb[0], $rgb[1], $rgb[2]) }
        }
        $desk = Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'WallPaper' -ErrorAction SilentlyContinue
        $wall = ''
        if ($null -ne $desk) { $wall = [string]$desk.WallPaper }
        $t::SetWallpaper($wall)
    }
}

class WindowsImageProvider : IImageProvider {
    WindowsImageProvider() { }

    static [void] LoadDrawing() { Add-Type -AssemblyName System.Drawing -ErrorAction Stop }

    # Dosya kilitlenmesin diye baytlardan açılır; görüntü değilse $null.
    static [object] Open([string] $Path) {
        if (-not [System.IO.File]::Exists($Path)) { return $null }
        [WindowsImageProvider]::LoadDrawing()
        $ms = New-Object System.IO.MemoryStream(, [System.IO.File]::ReadAllBytes($Path))
        try { return New-Object System.Drawing.Bitmap($ms) }
        catch { return $null }
    }

    static [int[]] ParseColor([string] $Color) {
        $c = $Color.TrimStart('#')
        return [int[]]@([Convert]::ToInt32($c.Substring(0, 2), 16), [Convert]::ToInt32($c.Substring(2, 2), 16), [Convert]::ToInt32($c.Substring(4, 2), 16))
    }

    [int[]] GetSize([string] $Path) {
        $bmp = [WindowsImageProvider]::Open($Path)
        if ($null -eq $bmp) { return $null }
        try { return [int[]]@($bmp.Width, $bmp.Height) }
        finally { $bmp.Dispose() }
    }

    # 33 x 33 noktalık ızgara (köşeler dahil) örneklenir; saydam piksel tek renk sayılmaz.
    [bool] IsSolid([string] $Path, [string] $Color) {
        $bmp = [WindowsImageProvider]::Open($Path)
        if ($null -eq $bmp) { return $false }
        $rgb = [WindowsImageProvider]::ParseColor($Color)
        try {
            $steps = 32
            for ($i = 0; $i -le $steps; $i++) {
                for ($j = 0; $j -le $steps; $j++) {
                    $x = [int][Math]::Floor(($bmp.Width - 1) * $i / $steps)
                    $y = [int][Math]::Floor(($bmp.Height - 1) * $j / $steps)
                    $p = $bmp.GetPixel($x, $y)
                    if ($p.A -ne 255 -or $p.R -ne $rgb[0] -or $p.G -ne $rgb[1] -or $p.B -ne $rgb[2]) { return $false }
                }
            }
            return $true
        }
        finally { $bmp.Dispose() }
    }

    [byte[]] NewSolid([int] $Width, [int] $Height, [string] $Color, [string] $Format) {
        [WindowsImageProvider]::LoadDrawing()
        $rgb = [WindowsImageProvider]::ParseColor($Color)
        $names = @{ png = 'Png'; jpg = 'Jpeg'; bmp = 'Bmp' }
        if (-not $names.ContainsKey($Format.ToLowerInvariant())) { throw "Desteklenmeyen görüntü biçimi: $Format" }
        $fmtType = 'System.Drawing.Imaging.ImageFormat' -as [type]
        $fmt = $fmtType::($names[$Format.ToLowerInvariant()])
        $pixel = ('System.Drawing.Imaging.PixelFormat' -as [type])::Format24bppRgb
        $bmp = New-Object System.Drawing.Bitmap($Width, $Height, $pixel)
        $g = ('System.Drawing.Graphics' -as [type])::FromImage($bmp)
        $ms = New-Object System.IO.MemoryStream
        try {
            $g.Clear(('System.Drawing.Color' -as [type])::FromArgb(255, $rgb[0], $rgb[1], $rgb[2]))
            $bmp.Save($ms, $fmt)
            return $ms.ToArray()
        }
        finally {
            $g.Dispose()
            $bmp.Dispose()
            $ms.Dispose()
        }
    }
}

# settings.dat bir kayıt defteri hive'ıdır (kök\LocalState altında değerler). Hive RegLoadAppKey ile bu sürece özel
# açılır (ShellNative.LoadAppKey: yönetici gerekmez, HKU'ya bağlanmaz, anahtar kapanınca bırakılır). Okuma kopyadan
# (uygulama açıkken de); yazma asıl dosyaya, uygulamanın süreçleri kapatıldıktan sonra.
# reg.exe load gerçek uygulama hive'larında "The filename or extension is too long" verdi (Faz 8, gerçek makine).
class WindowsAppSettingsProvider : IAppSettingsProvider {
    WindowsAppSettingsProvider() { }

    static [string] DatPath([string] $Package) {
        return [System.IO.Path]::Combine($env:LOCALAPPDATA, 'Packages', $Package, 'Settings', 'settings.dat')
    }

    [bool] HasSettings([string] $Package) { return [System.IO.File]::Exists([WindowsAppSettingsProvider]::DatPath($Package)) }

    static [Microsoft.Win32.RegistryKey] Open([string] $File, [bool] $Writable) {
        $t = Get-FaiShellNativeType
        try { return $t::LoadAppKey($File, $Writable) }
        catch {
            $e = $_.Exception
            if ($null -ne $e.InnerException) { $e = $e.InnerException }
            throw ("settings.dat açılamadı ({0}): {1}" -f $File, $e.Message)
        }
    }

    # Paketin süreçleri (kurulum klasörü WindowsApps\<ad>_*): ayar dosyasını kilitler.
    static [void] StopPackage([string] $Package) {
        $prefix = '*\WindowsApps\' + $Package.Split('_')[0] + '_*'
        Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path -like $prefix } |
            Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
    }

    # 'Alt\Ad' → @(alt yol, ad): alt yol LocalState'e göreli ('' = LocalState).
    static [string[]] SplitName([string] $Name) {
        $i = $Name.LastIndexOf('\')
        if ($i -lt 0) { return [string[]]@('', $Name) }
        return [string[]]@($Name.Substring(0, $i), $Name.Substring($i + 1))
    }

    static [string] KeyPath([string] $Sub) {
        if ($Sub) { return ('LocalState\{0}' -f $Sub) }
        return 'LocalState'
    }

    [hashtable] GetValue([string] $Package, [string] $Name) {
        $parts = [WindowsAppSettingsProvider]::SplitName($Name)
        $src = [WindowsAppSettingsProvider]::DatPath($Package)
        if (-not [System.IO.File]::Exists($src)) { return $null }
        $t = Get-FaiShellNativeType
        $tmp = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), 'FAI_' + [guid]::NewGuid().ToString('N') + '.dat')
        [System.IO.File]::Copy($src, $tmp)
        try {
            $root = [WindowsAppSettingsProvider]::Open($tmp, $false)
            try {
                $key = $root.OpenSubKey([WindowsAppSettingsProvider]::KeyPath($parts[0]))
                if ($null -eq $key) { return $null }
                try {
                    $type = 0
                    $data = $null
                    if (-not $t::QueryRaw($key, $parts[1], [ref]$type, [ref]$data)) { return $null }
                    return @{ Type = [int]$type; Data = [byte[]]$data }
                }
                finally { $key.Dispose() }
            }
            finally { $root.Dispose() }
        }
        finally {
            foreach ($f in @($tmp, "$tmp.LOG1", "$tmp.LOG2")) {
                if ([System.IO.File]::Exists($f)) { try { [System.IO.File]::Delete($f) } catch { Write-Verbose "geçici dosya silinemedi: $f" } }
            }
        }
    }

    # Yazma için açar: @{ Root; Key }. CloseWrite ile kapatılmalı.
    hidden [hashtable] OpenWrite([string] $Package, [string] $Sub) {
        $src = [WindowsAppSettingsProvider]::DatPath($Package)
        if (-not [System.IO.File]::Exists($src)) { throw "Paket ayar dosyası yok: $src" }
        [WindowsAppSettingsProvider]::StopPackage($Package)
        $root = [WindowsAppSettingsProvider]::Open($src, $true)
        try { $key = $root.CreateSubKey([WindowsAppSettingsProvider]::KeyPath($Sub)) }
        catch {
            $root.Dispose()
            throw
        }
        return @{ Root = $root; Key = $key }
    }

    hidden [void] CloseWrite([hashtable] $Handle) {
        try {
            $Handle['Key'].Flush()
            $Handle['Key'].Dispose()
        }
        finally { $Handle['Root'].Dispose() }
    }

    [void] SetValue([string] $Package, [string] $Name, [int] $Type, [byte[]] $Data) {
        $t = Get-FaiShellNativeType
        $parts = [WindowsAppSettingsProvider]::SplitName($Name)
        $h = $this.OpenWrite($Package, $parts[0])
        try { $t::SetRaw($h['Key'], $parts[1], $Type, $Data) }
        finally { $this.CloseWrite($h) }
    }

    [void] DeleteValue([string] $Package, [string] $Name) {
        $parts = [WindowsAppSettingsProvider]::SplitName($Name)
        $h = $this.OpenWrite($Package, $parts[0])
        try { $h['Key'].DeleteValue($parts[1], $false) }
        finally { $this.CloseWrite($h) }
    }
}
