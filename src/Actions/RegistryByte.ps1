# RegistryByteAction: ikili (REG_BINARY) değerin tek baytını (isteğe bağlı bit maskesiyle) değiştirir; değerin geri kalanı
# olduğu gibi kalır. Örnek: görev çubuğunu otomatik gizle (StuckRects3 'Settings' 8. bayt, 0. bit).
#
#   @{ Type='RegistryByte'; Path='HKCU:\...\StuckRects3'; Name='Settings'; Offset=8; Mask=1; Value=1 }
# Mask yoksa 255 (bütün bayt). Yeni bayt = (eski -band -bnot Mask) -bor (Value -band Mask).
# Değer yoksa ya da Offset'ten kısaysa uygulanamaz (değeri Windows oluşturur; ör. Gezgin ilk açılışta): hata.
# Undo: baytın eski hali geri yazılır (değerin diğer baytlarına dokunulmaz).

class RegistryByteAction : ActionBase {
    RegistryByteAction([hashtable] $Definition) : base($Definition) { }

    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        foreach ($m in (Get-FaiUnknownKeyError $Def @('Type', 'Path', 'Name', 'Offset', 'Mask', 'Value'))) { $e.Add($m) }
        if (-not $Def.Contains('Path')) { $e.Add('Path: required field missing') }
        elseif ($Def['Path'] -isnot [string] -or $Def['Path'] -notmatch '^(HKLM|HKCU|HKCR|HKU|HKCC):\\.+') {
            $e.Add('Path: must be in the form ''HKLM:\...'' (HKLM, HKCU, HKCR, HKU, HKCC)')
        }
        if (-not $Def.Contains('Name')) { $e.Add('Name: required field missing') }
        elseif ($Def['Name'] -isnot [string]) { $e.Add('Name: must be text') }
        if (-not $Def.Contains('Offset')) { $e.Add('Offset: required field missing') }
        elseif (-not (Test-FaiIsInteger $Def['Offset']) -or $Def['Offset'] -lt 0) { $e.Add('Offset: must be an integer, 0 or greater') }
        foreach ($f in @('Mask', 'Value')) {
            if (-not $Def.Contains($f)) {
                if ($f -eq 'Value') { $e.Add('Value: required field missing') }
                continue
            }
            if (Test-FaiHasPlaceholder $Def[$f]) { continue }
            $v = $Def[$f]
            if ($v -is [bool]) { continue }
            if (-not (Test-FaiIsInteger $v) -or $v -lt 0 -or $v -gt 255) { $e.Add("${f}: must be an integer from 0 to 255") }
        }
        return $e.ToArray()
    }

    [int] Mask() {
        if (-not $this.Definition.ContainsKey('Mask')) { return 255 }
        return [int]$this.Definition['Mask']
    }

    # Değer bool verilebilir (parametre: autoHide = $true): $true → maskenin tamamı.
    [int] Want() {
        $v = $this.Definition['Value']
        if ($v -is [bool]) {
            if ($v) { return $this.Mask() }
            return 0
        }
        return ([int]$v -band $this.Mask())
    }

    # Mevcut bayt; değer yoksa / ikili değilse / kısaysa -1.
    [int] Current([ExecutionContext] $Ctx) {
        $path = [string]$this.Definition['Path']
        $name = [string]$this.Definition['Name']
        if (-not $Ctx.Registry.ValueExists($path, $name) -or $Ctx.Registry.GetValueKind($path, $name) -ne 'Binary') { return -1 }
        $bytes = [byte[]](ConvertTo-FaiRegistryValue -Value $Ctx.Registry.GetValue($path, $name) -Kind 'Binary')
        $off = [int]$this.Definition['Offset']
        if ($bytes.Length -le $off) { return -1 }
        return [int]$bytes[$off]
    }

    [bool] Test([ExecutionContext] $Ctx) {
        $cur = $this.Current($Ctx)
        if ($cur -lt 0) { return $false }
        return (($cur -band $this.Mask()) -eq $this.Want())
    }

    [hashtable] Snapshot([ExecutionContext] $Ctx) {
        $cur = $this.Current($Ctx)
        if ($cur -lt 0) { throw ('{0} is missing or has no byte {1} (Windows creates the value)' -f $this.Target(), $this.Definition['Offset']) }
        return @{ Byte = $cur }
    }

    hidden [void] WriteByte([ExecutionContext] $Ctx, [int] $NewByte) {
        $path = [string]$this.Definition['Path']
        $name = [string]$this.Definition['Name']
        $bytes = [byte[]](ConvertTo-FaiRegistryValue -Value $Ctx.Registry.GetValue($path, $name) -Kind 'Binary')
        $bytes[[int]$this.Definition['Offset']] = [byte]$NewByte
        $Ctx.Registry.SetValue($path, $name, $bytes, 'Binary')
    }

    [void] Apply([ExecutionContext] $Ctx) {
        $cur = $this.Current($Ctx)
        if ($cur -lt 0) { throw ('{0} is missing or has no byte {1} (Windows creates the value)' -f $this.Target(), $this.Definition['Offset']) }
        $mask = $this.Mask()
        $this.WriteByte($Ctx, (($cur -band (-bnot $mask) -band 255) -bor $this.Want()))
    }

    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        if ($this.Current($Ctx) -lt 0) { return }
        $this.WriteByte($Ctx, [int]$Snapshot['Byte'])
    }

    [string] Target() { return ('{0}\{1}' -f $this.Definition['Path'], $this.Definition['Name']) }

    [string] Describe() {
        return ('Registry: {0} [byte {1}, mask 0x{2:X2}] = 0x{3:X2}' -f $this.Target(), $this.Definition['Offset'], $this.Mask(), $this.Want())
    }

    [string] Preview([ExecutionContext] $Ctx) {
        $cur = $this.Current($Ctx)
        $now = 'none'
        if ($cur -ge 0) { $now = '0x{0:X2}' -f $cur }
        return ('{0} [current: {1}]' -f $this.Describe(), $now)
    }

    [string] PreviewRevert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        $cur = $this.Current($Ctx)
        $now = 'none'
        if ($cur -ge 0) { $now = '0x{0:X2}' -f $cur }
        return ('Registry: {0} [byte {1}] — currently {2} → will revert to 0x{3:X2}' -f $this.Target(), $this.Definition['Offset'], $now, [int]$Snapshot['Byte'])
    }
}
