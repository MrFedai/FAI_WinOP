# RegistryAction: kayıt defteri değeri yazar ya da siler. Yalnız $Ctx.Registry (IRegistryProvider) üzerinden.
#
#   @{ Type='Registry'; Path='HKCU:\Software\...'; Name='Ad'; Value=1; Kind='DWord' }
#   @{ Type='Registry'; Path='HKCU:\Software\...'; Name='Ad'; Ensure='Absent' }          # değeri sil
# Kind: String | ExpandString | Binary | DWord | MultiString | QWord. Value '{{parametre}}' olabilir (Tweak.Params).
# Not: Undo, uygulamadan önce var olmayan değeri siler; değer için oluşan boş anahtarı silmez.

class RegistryAction : ActionBase {
    RegistryAction([hashtable] $Definition) : base($Definition) { }

    static [string[]] Kinds() { return [string[]]@('String', 'ExpandString', 'Binary', 'DWord', 'MultiString', 'QWord') }

    # Şema hataları; her ileti '<alan>: <neden>' biçiminde (boşsa geçerli).
    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        $allowed = @('Type', 'Path', 'Name', 'Value', 'Kind', 'Ensure')
        foreach ($k in @($Def.Keys)) {
            if ($allowed -cnotcontains [string]$k) { $e.Add("${k}: bilinmeyen alan (izin verilenler: " + ($allowed -join ', ') + ')') }
        }
        if (-not $Def.Contains('Path')) { $e.Add('Path: zorunlu alan eksik') }
        elseif ($Def['Path'] -isnot [string] -or $Def['Path'] -notmatch '^(HKLM|HKCU|HKCR|HKU|HKCC):\\.+') {
            $e.Add('Path: ''HKLM:\...'' biçiminde olmalı (HKLM, HKCU, HKCR, HKU, HKCC)')
        }
        if (-not $Def.Contains('Name')) { $e.Add('Name: zorunlu alan eksik') }
        elseif ($Def['Name'] -isnot [string]) { $e.Add('Name: metin olmalı (boş metin = varsayılan değer)') }

        $ensure = 'Present'
        if ($Def.Contains('Ensure')) {
            if ($Def['Ensure'] -isnot [string] -or @('Present', 'Absent') -cnotcontains $Def['Ensure']) { $e.Add('Ensure: Present ya da Absent olmalı') }
            else { $ensure = $Def['Ensure'] }
        }
        if ($ensure -eq 'Absent') {
            if ($Def.Contains('Value')) { $e.Add('Value: Ensure=Absent iken verilmez') }
            if ($Def.Contains('Kind')) { $e.Add('Kind: Ensure=Absent iken verilmez') }
            return $e.ToArray()
        }

        $kind = $null
        if (-not $Def.Contains('Kind')) { $e.Add('Kind: zorunlu alan eksik') }
        elseif ($Def['Kind'] -isnot [string] -or [RegistryAction]::Kinds() -cnotcontains $Def['Kind']) {
            $e.Add('Kind: ' + ([RegistryAction]::Kinds() -join ', ') + ' değerlerinden biri olmalı')
        }
        else { $kind = $Def['Kind'] }

        if (-not $Def.Contains('Value')) { $e.Add('Value: zorunlu alan eksik') }
        elseif ($null -ne $kind -and @(Get-FaiPlaceholder -Value $Def['Value']).Count -eq 0) {
            $v = $Def['Value']
            switch ($kind) {
                'DWord' {
                    $ok = ($v -is [int] -or $v -is [long]) -and $v -ge -2147483648 -and $v -le 4294967295
                    if (-not $ok) { $e.Add('Value: DWord için 32 bit tamsayı olmalı') }
                }
                'QWord' { if (-not ($v -is [int] -or $v -is [long])) { $e.Add('Value: QWord için tamsayı olmalı') } }
                'String' { if ($v -isnot [string]) { $e.Add('Value: String için metin olmalı') } }
                'ExpandString' { if ($v -isnot [string]) { $e.Add('Value: ExpandString için metin olmalı') } }
                'MultiString' {
                    if (-not (Test-FaiIsList $v) -or @($v | Where-Object { $_ -isnot [string] }).Count -gt 0) { $e.Add('Value: MultiString için metin dizisi olmalı') }
                }
                'Binary' {
                    $bad = @($v | Where-Object { -not (($_ -is [int] -or $_ -is [long] -or $_ -is [byte]) -and $_ -ge 0 -and $_ -le 255) })
                    if (-not (Test-FaiIsList $v) -or $bad.Count -gt 0) { $e.Add('Value: Binary için 0-255 arası sayı dizisi olmalı') }
                }
            }
        }
        return $e.ToArray()
    }

    [bool] IsAbsent() { return ([string]$this.Definition['Ensure'] -eq 'Absent') }

    [string] Target() { return ('{0}\{1}' -f $this.Definition['Path'], $this.Definition['Name']) }

    [bool] Test([ExecutionContext] $Ctx) {
        $path = [string]$this.Definition['Path']
        $name = [string]$this.Definition['Name']
        $exists = $Ctx.Registry.ValueExists($path, $name)
        if ($this.IsAbsent()) { return (-not $exists) }
        if (-not $exists) { return $false }
        $kind = [string]$this.Definition['Kind']
        if ($Ctx.Registry.GetValueKind($path, $name) -ne $kind) { return $false }
        $want = ConvertTo-FaiRegistryValue -Value $this.Definition['Value'] -Kind $kind
        return (Test-FaiValueEqual -Left $Ctx.Registry.GetValue($path, $name) -Right $want)
    }

    [hashtable] Snapshot([ExecutionContext] $Ctx) {
        $path = [string]$this.Definition['Path']
        $name = [string]$this.Definition['Name']
        if (-not $Ctx.Registry.ValueExists($path, $name)) { return @{ Exists = $false } }
        return @{
            Exists = $true
            Value  = $Ctx.Registry.GetValue($path, $name)
            Kind   = $Ctx.Registry.GetValueKind($path, $name)
        }
    }

    [void] Apply([ExecutionContext] $Ctx) {
        $path = [string]$this.Definition['Path']
        $name = [string]$this.Definition['Name']
        if ($this.IsAbsent()) {
            $Ctx.Registry.DeleteValue($path, $name)
            return
        }
        $kind = [string]$this.Definition['Kind']
        $value = ConvertTo-FaiRegistryValue -Value $this.Definition['Value'] -Kind $kind
        $Ctx.Registry.SetValue($path, $name, $value, $kind)
    }

    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        $path = [string]$this.Definition['Path']
        $name = [string]$this.Definition['Name']
        if ($Snapshot['Exists']) {
            $kind = [string]$Snapshot['Kind']
            $value = ConvertTo-FaiRegistryValue -Value $Snapshot['Value'] -Kind $kind
            $Ctx.Registry.SetValue($path, $name, $value, $kind)
        }
        elseif ($Ctx.Registry.ValueExists($path, $name)) {
            $Ctx.Registry.DeleteValue($path, $name)
        }
    }

    [string] Describe() {
        if ($this.IsAbsent()) { return ('Kayıt defteri: {0} silinir' -f $this.Target()) }
        $v = $this.Definition['Value']
        $shown = (@($v) | ForEach-Object { [string]$_ }) -join ','
        return ('Kayıt defteri: {0} = {1} ({2})' -f $this.Target(), $shown, $this.Definition['Kind'])
    }

    [string] Preview([ExecutionContext] $Ctx) {
        $path = [string]$this.Definition['Path']
        $name = [string]$this.Definition['Name']
        $now = 'yok'
        if ($Ctx.Registry.ValueExists($path, $name)) {
            $now = (@($Ctx.Registry.GetValue($path, $name)) | ForEach-Object { [string]$_ }) -join ','
        }
        return ('{0} [şu an: {1}]' -f $this.Describe(), $now)
    }
}
