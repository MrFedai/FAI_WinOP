# SolidImageAction: tek renkli görüntü dosyası. Yalnız $Ctx.Images (üretim / okuma) ve $Ctx.Files (yazma) üzerinden.
#
#   @{ Type='SolidImage'; Path='%ProgramData%\FAI_WinOP\Black.png'; Color='000000'; Width=1920; Height=1080 }
#   @{ Type='SolidImage'; Directory='%ProgramData%\Microsoft\User Account Pictures'; Filter=@('*.png','*.bmp'); Color='000000' }
# Path: dosya yoksa Width x Height oluşturulur, varsa boyutu korunarak yeniden boyanır. Biçim uzantıdan (png, jpg, bmp).
# Directory: klasördeki (alt klasörler hariç) Filter'a uyan VAR OLAN görüntüler boyutları korunarak boyanır; yeni dosya
# oluşmaz, görüntü olmayan dosya atlanır.
# Snapshot dosyaların baytlarını tutar (FileAction.BackupFile, boyut sınırı aynı); Undo birebir geri yazar / yeni dosyayı siler.

class SolidImageAction : ActionBase {
    SolidImageAction([hashtable] $Definition) : base($Definition) { }

    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        foreach ($m in (Get-FaiUnknownKeyError $Def @('Type', 'Path', 'Directory', 'Filter', 'Color', 'Width', 'Height'))) { $e.Add($m) }
        $hasPath = $Def.Contains('Path')
        $hasDir = $Def.Contains('Directory')
        if ($hasPath -eq $hasDir) { $e.Add('Path / Directory: ikisinden tam olarak biri verilmeli') }
        if ($hasPath) {
            if (-not (Test-FaiWindowsPath $Def['Path'])) { $e.Add('Path: must be an absolute path (C:\..., %VARIABLE%\...)') }
            elseif (-not [SolidImageAction]::FormatOf([string]$Def['Path'])) { $e.Add('Path: extension must be .png, .jpg or .bmp') }
            foreach ($f in @('Width', 'Height')) {
                if (-not $Def.Contains($f)) { $e.Add("${f}: required with Path") }
                elseif (-not (Test-FaiHasPlaceholder $Def[$f]) -and (-not (Test-FaiIsInteger $Def[$f]) -or $Def[$f] -lt 1 -or $Def[$f] -gt 16384)) { $e.Add("${f}: must be an integer from 1 to 16384") }
            }
            if ($Def.Contains('Filter')) { $e.Add('Filter: only allowed with Directory') }
        }
        if ($hasDir) {
            if (-not (Test-FaiWindowsPath $Def['Directory'])) { $e.Add('Directory: must be an absolute path (C:\..., %VARIABLE%\...)') }
            if (-not $Def.Contains('Filter')) { $e.Add('Filter: required with Directory (e.g. @(''*.png''))') }
            else {
                $bad = @(@($Def['Filter']) | Where-Object { $_ -isnot [string] -or [string]::IsNullOrWhiteSpace($_) })
                if (@($Def['Filter']).Count -eq 0 -or $bad.Count -gt 0) { $e.Add('Filter: must be non-empty text or a list of text (-like pattern)') }
            }
            foreach ($f in @('Width', 'Height')) { if ($Def.Contains($f)) { $e.Add("${f}: only allowed with Path (Directory keeps the size)") } }
        }
        if (-not $Def.Contains('Color')) { $e.Add('Color: required field missing') }
        elseif (-not (Test-FaiHasPlaceholder $Def['Color']) -and ($Def['Color'] -isnot [string] -or $Def['Color'] -notmatch '^[0-9A-Fa-f]{6}$')) { $e.Add('Color: must be RRGGBB (hex), e.g. 000000') }
        return $e.ToArray()
    }

    # Uzantıdan biçim; desteklenmiyorsa boş metin.
    static [string] FormatOf([string] $Path) {
        switch -regex ([System.IO.Path]::GetExtension($Path).ToLowerInvariant()) {
            '^\.png$' { return 'png' }
            '^\.jpe?g$' { return 'jpg' }
            '^\.bmp$' { return 'bmp' }
        }
        return ''
    }

    [string] Color() { return ([string]$this.Definition['Color']).ToUpperInvariant() }

    # Kapsamdaki dosyalar (açılmış yollar).
    [string[]] Files([ExecutionContext] $Ctx) {
        if ($this.Definition.ContainsKey('Path')) { return [string[]]@((Expand-FaiPath ([string]$this.Definition['Path']))) }
        $out = New-Object 'System.Collections.Generic.List[string]'
        foreach ($f in @($Ctx.Files.ListFiles((Expand-FaiPath ([string]$this.Definition['Directory']))))) {
            $name = (Get-FaiFileName $f)
            foreach ($pat in @($this.Definition['Filter'])) {
                if ($name -like [string]$pat -and [SolidImageAction]::FormatOf($f)) { $out.Add($f); break }
            }
        }
        return $out.ToArray()
    }

    # Boyanacak dosyalar (salt okunur). Directory kipinde okunamayan (görüntü olmayan) dosya atlanır.
    [string[]] Pending([ExecutionContext] $Ctx) {
        $out = New-Object 'System.Collections.Generic.List[string]'
        foreach ($f in $this.Files($Ctx)) {
            if (-not $Ctx.Files.FileExists($f)) {
                if ($this.Definition.ContainsKey('Path')) { $out.Add($f) }
                continue
            }
            if ($Ctx.Images.IsSolid($f, $this.Color())) { continue }
            if ($this.Definition.ContainsKey('Directory') -and $null -eq $Ctx.Images.GetSize($f)) { continue }
            $out.Add($f)
        }
        return $out.ToArray()
    }

    [bool] Test([ExecutionContext] $Ctx) { return (@($this.Pending($Ctx)).Count -eq 0) }

    [hashtable] Snapshot([ExecutionContext] $Ctx) {
        $list = New-Object System.Collections.ArrayList
        foreach ($f in $this.Pending($Ctx)) {
            $b = [FileAction]::BackupFile($Ctx, $f)
            $b['Path'] = $f
            [void]$list.Add($b)
        }
        return @{ Files = $list.ToArray() }
    }

    [void] Apply([ExecutionContext] $Ctx) {
        foreach ($f in $this.Pending($Ctx)) {
            $size = $null
            if ($Ctx.Files.FileExists($f)) { $size = $Ctx.Images.GetSize($f) }
            if ($null -eq $size) { $size = [int[]]@([int]$this.Definition['Width'], [int]$this.Definition['Height']) }
            $bytes = $Ctx.Images.NewSolid([int]$size[0], [int]$size[1], $this.Color(), [SolidImageAction]::FormatOf($f))
            $Ctx.Files.WriteBytes($f, $bytes)
        }
    }

    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        foreach ($s in @($Snapshot['Files'])) {
            if ($null -eq $s) { continue }
            [FileAction]::RestoreFile($Ctx, [string]$s['Path'], [hashtable]$s)
        }
    }

    [string] Describe() {
        if ($this.Definition.ContainsKey('Path')) {
            return ('Image: {0} solid color #{1} ({2}x{3}, existing size is kept)' -f $this.Definition['Path'], $this.Color(), $this.Definition['Width'], $this.Definition['Height'])
        }
        return ('Image: {0}\{1} solid color #{2} (size is kept)' -f $this.Definition['Directory'], (@($this.Definition['Filter']) -join ','), $this.Color())
    }

    [string] Preview([ExecutionContext] $Ctx) {
        $pending = @($this.Pending($Ctx))
        $names = @($pending | Select-Object -First 6 | ForEach-Object { (Get-FaiFileName $_) }) -join ', '
        if ($pending.Count -gt 6) { $names += (', … +{0}' -f ($pending.Count - 6)) }
        return ('{0} [{1} files to paint: {2}]' -f $this.Describe(), $pending.Count, $names)
    }
}
