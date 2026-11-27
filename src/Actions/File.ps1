# FileAction: metin dosyası yazar ya da dosya siler. Yalnız $Ctx.Files üzerinden.
#
#   @{ Type='File'; Path='%LOCALAPPDATA%\Uygulama\ayar.json'; Content='{ "a": 1 }' }              # UTF-8 (BOM'suz)
#   @{ Type='File'; Path='%USERPROFILE%\x.ini'; Content="a=1`r`n"; Encoding='Unicode' }
#   @{ Type='File'; Path='%PUBLIC%\Desktop\Edge.lnk'; Ensure='Absent' }                           # sil
#   @{ Type='File'; Path='%LOCALAPPDATA%\...\start2.bin'; Base64='AAEC...' }                        # ikili içerik
# Encoding: UTF8 (BOM'suz, varsayılan) | UTF8BOM | Unicode (UTF-16 LE, BOM'lu) | ASCII.
# Snapshot dosyanın baytlarını (base64) tutar; geri alma birebir geri yazar ya da yeni oluşanı siler.
# Yedek sınırı MaxBackupBytes: daha büyük dosyaya dokunulmaz (Snapshot hata verir, eylem uygulanmaz).
# Not: oluşturulan üst klasörler geri almada silinmez.

class FileAction : ActionBase {
    static [long] $MaxBackupBytes = 5MB

    FileAction([hashtable] $Definition) : base($Definition) { }

    static [string[]] Encodings() { return [string[]]@('UTF8', 'UTF8BOM', 'Unicode', 'ASCII') }

    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        foreach ($m in (Get-FaiUnknownKeyError $Def @('Type', 'Path', 'Content', 'Base64', 'Encoding', 'Ensure'))) { $e.Add($m) }
        if (-not $Def.Contains('Path')) { $e.Add('Path: required field missing') }
        elseif (-not (Test-FaiWindowsPath $Def['Path'])) { $e.Add('Path: must be an absolute path (C:\..., %VARIABLE%\...)') }
        $ensure = 'Present'
        if ($Def.Contains('Ensure')) {
            if ($Def['Ensure'] -isnot [string] -or @('Present', 'Absent') -cnotcontains $Def['Ensure']) { $e.Add('Ensure: must be Present or Absent') }
            else { $ensure = $Def['Ensure'] }
        }
        if ($ensure -eq 'Absent') {
            if ($Def.Contains('Content')) { $e.Add('Content: not allowed when Ensure=Absent') }
            if ($Def.Contains('Base64')) { $e.Add('Base64: not allowed when Ensure=Absent') }
            if ($Def.Contains('Encoding')) { $e.Add('Encoding: not allowed when Ensure=Absent') }
            return $e.ToArray()
        }
        if ($Def.Contains('Base64')) {
            if ($Def.Contains('Content')) { $e.Add('Content: not allowed with Base64') }
            if ($Def.Contains('Encoding')) { $e.Add('Encoding: not allowed with Base64 (content is binary)') }
            if (-not (Test-FaiHasPlaceholder $Def['Base64'])) {
                $ok = $Def['Base64'] -is [string]
                if ($ok) { try { [void][Convert]::FromBase64String($Def['Base64']) } catch { $ok = $false } }
                if (-not $ok) { $e.Add('Base64: must be valid base64 text') }
            }
            return $e.ToArray()
        }
        if (-not $Def.Contains('Content')) { $e.Add('Content: required field missing (or Base64)') }
        elseif ($Def['Content'] -isnot [string]) { $e.Add('Content: must be text') }
        if ($Def.Contains('Encoding') -and ($Def['Encoding'] -isnot [string] -or [FileAction]::Encodings() -cnotcontains $Def['Encoding'])) {
            $e.Add('Encoding: must be one of ' + ([FileAction]::Encodings() -join ', '))
        }
        return $e.ToArray()
    }

    static [byte[]] Encode([string] $Text, [string] $EncodingName) {
        $enc = $null
        switch ($EncodingName) {
            'UTF8BOM' { $enc = New-Object System.Text.UTF8Encoding($true) }
            'Unicode' { $enc = New-Object System.Text.UnicodeEncoding($false, $true) }
            'ASCII' { $enc = New-Object System.Text.ASCIIEncoding }
            default { $enc = New-Object System.Text.UTF8Encoding($false) }
        }
        $pre = $enc.GetPreamble()
        $body = $enc.GetBytes($Text)
        $all = New-Object byte[] ($pre.Length + $body.Length)
        [System.Array]::Copy($pre, 0, $all, 0, $pre.Length)
        [System.Array]::Copy($body, 0, $all, $pre.Length, $body.Length)
        return $all
    }

    static [bool] BytesEqual([byte[]] $A, [byte[]] $B) {
        if ($A.Length -ne $B.Length) { return $false }
        for ($i = 0; $i -lt $A.Length; $i++) { if ($A[$i] -ne $B[$i]) { return $false } }
        return $true
    }

    # Dosyanın tam bayt yedeği (Shortcut da kullanır). Boyut sınırı aşılırsa hata.
    static [hashtable] BackupFile([ExecutionContext] $Ctx, [string] $FullPath) {
        if (-not $Ctx.Files.FileExists($FullPath)) { return @{ Exists = $false } }
        $size = $Ctx.Files.GetSize($FullPath)
        if ($size -gt [FileAction]::MaxBackupBytes) {
            throw ('File exceeds the backup limit ({0} bytes > {1}); left untouched: {2}' -f $size, [FileAction]::MaxBackupBytes, $FullPath)
        }
        return @{ Exists = $true; Bytes = [Convert]::ToBase64String($Ctx.Files.ReadBytes($FullPath)) }
    }

    static [void] RestoreFile([ExecutionContext] $Ctx, [string] $FullPath, [hashtable] $Snapshot) {
        if ($Snapshot['Exists']) {
            $bytes = [Convert]::FromBase64String([string]$Snapshot['Bytes'])
            $same = $Ctx.Files.FileExists($FullPath) -and [FileAction]::BytesEqual($Ctx.Files.ReadBytes($FullPath), $bytes)
            if (-not $same) { $Ctx.Files.WriteBytes($FullPath, $bytes) }
        }
        elseif ($Ctx.Files.FileExists($FullPath)) {
            $Ctx.Files.DeleteFile($FullPath)
        }
    }

    [string] FullPath() { return (Expand-FaiPath ([string]$this.Definition['Path'])) }

    [bool] IsAbsent() { return ([string]$this.Definition['Ensure'] -eq 'Absent') }

    [byte[]] WantBytes() {
        if ($this.Definition.ContainsKey('Base64')) { return [Convert]::FromBase64String([string]$this.Definition['Base64']) }
        return [FileAction]::Encode([string]$this.Definition['Content'], [string]$this.Definition['Encoding'])
    }

    [bool] Test([ExecutionContext] $Ctx) {
        $p = $this.FullPath()
        $exists = $Ctx.Files.FileExists($p)
        if ($this.IsAbsent()) { return (-not $exists) }
        if (-not $exists) { return $false }
        return [FileAction]::BytesEqual($Ctx.Files.ReadBytes($p), $this.WantBytes())
    }

    [hashtable] Snapshot([ExecutionContext] $Ctx) { return [FileAction]::BackupFile($Ctx, $this.FullPath()) }

    [void] Apply([ExecutionContext] $Ctx) {
        $p = $this.FullPath()
        if ($this.IsAbsent()) {
            if ($Ctx.Files.FileExists($p)) { $Ctx.Files.DeleteFile($p) }
            return
        }
        $Ctx.Files.WriteBytes($p, $this.WantBytes())
    }

    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) { [FileAction]::RestoreFile($Ctx, $this.FullPath(), $Snapshot) }

    [string] Describe() {
        if ($this.IsAbsent()) { return ('File: {0} is deleted' -f $this.Definition['Path']) }
        if ($this.Definition.ContainsKey('Base64')) { return ('File: {0} is written ({1} bytes, binary)' -f $this.Definition['Path'], $this.WantBytes().Length) }
        $enc = 'UTF8'
        if ($this.Definition.ContainsKey('Encoding')) { $enc = [string]$this.Definition['Encoding'] }
        return ('File: {0} is written ({1} characters, {2})' -f $this.Definition['Path'], ([string]$this.Definition['Content']).Length, $enc)
    }

    [string] Preview([ExecutionContext] $Ctx) {
        $size = $Ctx.Files.GetSize($this.FullPath())
        $now = 'none'
        if ($size -ge 0) { $now = '{0} bytes' -f $size }
        return ('{0} [current: {1}]' -f $this.Describe(), $now)
    }

    [string] PreviewRevert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        $size = $Ctx.Files.GetSize($this.FullPath())
        $now = 'none'
        if ($size -ge 0) { $now = '{0} bytes' -f $size }
        $will = 'file deleted (it did not exist before)'
        if ($Snapshot['Exists']) {
            $len = 0
            try { $len = [Convert]::FromBase64String([string]$Snapshot['Bytes']).Length } catch { $len = 0 }
            $will = 'previous content ({0} bytes) restored' -f $len
        }
        return ('File: {0} — currently {1} → will revert to {2}' -f $this.Definition['Path'], $now, $will)
    }
}
