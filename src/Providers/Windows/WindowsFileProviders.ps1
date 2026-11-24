# Gerçek dosya (System.IO) ve kısayol (WScript.Shell COM) sağlayıcıları. Yollar açılmış (%DEĞİŞKEN%'siz) gelir.

class WindowsFileProvider : IFileProvider {
    WindowsFileProvider() { }

    [bool] FileExists([string] $Path) { return [System.IO.File]::Exists($Path) }

    [long] GetSize([string] $Path) {
        if (-not [System.IO.File]::Exists($Path)) { return -1 }
        return (New-Object System.IO.FileInfo($Path)).Length
    }

    [byte[]] ReadBytes([string] $Path) { return [System.IO.File]::ReadAllBytes($Path) }

    [void] WriteBytes([string] $Path, [byte[]] $Bytes) {
        $dir = [System.IO.Path]::GetDirectoryName($Path)
        if ($dir -and -not [System.IO.Directory]::Exists($dir)) { [void][System.IO.Directory]::CreateDirectory($dir) }
        [System.IO.File]::WriteAllBytes($Path, $Bytes)
    }

    [void] DeleteFile([string] $Path) {
        if ([System.IO.File]::Exists($Path)) { [System.IO.File]::Delete($Path) }
    }

    [string[]] ListFiles([string] $Directory) {
        if (-not [System.IO.Directory]::Exists($Directory)) { return [string[]]@() }
        $arr = [string[]]@([System.IO.Directory]::GetFiles($Directory))
        [System.Array]::Sort($arr, [System.StringComparer]::OrdinalIgnoreCase)
        return $arr
    }

    [void] DeleteEmptyDirectory([string] $Directory) {
        if (-not [System.IO.Directory]::Exists($Directory)) { return }
        if (@([System.IO.Directory]::GetFileSystemEntries($Directory)).Count -gt 0) { return }
        [System.IO.Directory]::Delete($Directory)
    }

    [string] GetKnownFolder([string] $Name) {
        $folder = $null
        try { $folder = [System.Enum]::Parse([System.Environment+SpecialFolder], $Name, $true) }
        catch { return '' }
        return [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]$folder)
    }
}

# Kabuk: Start-Process ile URI açar (ms-settings:, http(s):).
class WindowsShellProvider : IShellProvider {
    WindowsShellProvider() { }

    [void] OpenUri([string] $Uri) { Start-Process -FilePath $Uri }
}

class WindowsShortcutProvider : IShortcutProvider {
    WindowsShortcutProvider() { }

    static [string[]] PropertyNames() { return [string[]]@('TargetPath', 'Arguments', 'WorkingDirectory', 'IconLocation', 'Description') }

    [hashtable] ReadShortcut([string] $Path) {
        if (-not [System.IO.File]::Exists($Path)) { return $null }
        $shell = New-Object -ComObject WScript.Shell
        try {
            $lnk = $shell.CreateShortcut($Path)
            $result = @{}
            foreach ($n in [WindowsShortcutProvider]::PropertyNames()) { $result[$n] = [string]$lnk.$n }
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($lnk)
            return $result
        }
        finally { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) }
    }

    # Var olan kısayol önce silinir: CreateShortcut eski özellikleri yükler, verilmeyenler boş kalmalı.
    [void] WriteShortcut([string] $Path, [hashtable] $Properties) {
        $dir = [System.IO.Path]::GetDirectoryName($Path)
        if ($dir -and -not [System.IO.Directory]::Exists($dir)) { [void][System.IO.Directory]::CreateDirectory($dir) }
        if ([System.IO.File]::Exists($Path)) { [System.IO.File]::Delete($Path) }
        $shell = New-Object -ComObject WScript.Shell
        try {
            $lnk = $shell.CreateShortcut($Path)
            foreach ($n in [WindowsShortcutProvider]::PropertyNames()) {
                if ($Properties.ContainsKey($n) -and $Properties[$n]) { $lnk.$n = [string]$Properties[$n] }
            }
            $lnk.Save()
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($lnk)
        }
        finally { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) }
    }
}
