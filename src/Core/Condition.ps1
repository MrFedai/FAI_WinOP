# Koşul: tweak'in bu makinede uygulanıp uygulanmayacağını belirler (ISystemInfoProvider üzerinden, salt okunur).
#
# Tweak dosyasında yazım:
#   'IsLaptop'  'HasNvidia'  'HasAmdGpu'  'HasIntelGpu'      mantıksal koşullar
#   @{ Not = 'IsLaptop' }                                     olumsuzlama (yalnız mantıksal koşul adı)
#   @{ Edition = 'Pro' }  @{ Edition = @('Pro','Enterprise') } sürüm adı (büyük/küçük harf duyarsız)
#   @{ MinBuild = 22621 }  @{ MinRamGB = 16 }                 alt sınır (>=)

class Condition {
    [string] $Name
    [object] $Value
    [bool] $Negate = $false

    Condition() { }

    static [string[]] BooleanNames() { return [string[]]@('IsLaptop', 'HasNvidia', 'HasAmdGpu', 'HasIntelGpu') }
    static [string[]] ValuedNames() { return [string[]]@('Edition', 'MinBuild', 'MinRamGB') }

    # Ham tanım için hata iletileri (boşsa geçerli).
    static [string[]] Validate([object] $Raw) {
        $errors = New-Object 'System.Collections.Generic.List[string]'
        if ($Raw -is [string]) {
            if ([Condition]::BooleanNames() -notcontains $Raw) {
                $errors.Add("unknown condition '$Raw' (known: " + ([Condition]::BooleanNames() -join ', ') + ')')
            }
            return $errors.ToArray()
        }
        if ($Raw -isnot [System.Collections.IDictionary]) {
            $errors.Add('condition must be a string or a single-key hashtable')
            return $errors.ToArray()
        }
        $keys = @($Raw.Keys)
        if ($keys.Count -ne 1) {
            $errors.Add('condition hashtable must have exactly one key')
            return $errors.ToArray()
        }
        $key = [string]$keys[0]
        $val = $Raw[$keys[0]]
        switch ($key) {
            'Not' {
                if ($val -isnot [string] -or [Condition]::BooleanNames() -notcontains $val) {
                    $errors.Add("Not takes only a boolean condition name (" + ([Condition]::BooleanNames() -join ', ') + ')')
                }
            }
            'Edition' {
                $items = @($val)
                if ($items.Count -eq 0 -or @($items | Where-Object { $_ -isnot [string] -or -not $_ }).Count -gt 0) {
                    $errors.Add('Edition must be a string or an array of strings')
                }
            }
            { $_ -eq 'MinBuild' -or $_ -eq 'MinRamGB' } {
                $isNumber = $val -is [int] -or $val -is [long] -or $val -is [double] -or $val -is [decimal]
                if (-not $isNumber -or $val -lt 0) { $errors.Add("$key must be zero or a positive number") }
            }
            default {
                $errors.Add("unknown condition key '$key' (known: Not, " + ([Condition]::ValuedNames() -join ', ') + ')')
            }
        }
        return $errors.ToArray()
    }

    static [Condition] Parse([object] $Raw) {
        $errors = [Condition]::Validate($Raw)
        if ($errors.Count -gt 0) { throw ('Invalid condition: ' + ($errors -join '; ')) }
        $c = [Condition]::new()
        if ($Raw -is [string]) {
            $c.Name = $Raw
            return $c
        }
        $key = [string]@($Raw.Keys)[0]
        $val = $Raw[$key]
        if ($key -eq 'Not') {
            $c.Name = [string]$val
            $c.Negate = $true
        }
        else {
            $c.Name = $key
            $c.Value = $val
        }
        return $c
    }

    [bool] Test([ISystemInfoProvider] $Sys) {
        $result = $false
        switch ($this.Name) {
            'IsLaptop' { $result = $Sys.IsLaptop() }
            'HasNvidia' { $result = $Sys.HasNvidia() }
            'HasAmdGpu' { $result = $Sys.HasAmdGpu() }
            'HasIntelGpu' { $result = $Sys.HasIntelGpu() }
            'Edition' {
                $edition = $Sys.GetEdition()
                foreach ($want in @($this.Value)) {
                    if ([string]::Equals([string]$want, $edition, [System.StringComparison]::OrdinalIgnoreCase)) { $result = $true }
                }
            }
            'MinBuild' { $result = ($Sys.GetBuild() -ge [int]$this.Value) }
            'MinRamGB' { $result = ($Sys.GetRamGB() -ge [double]$this.Value) }
            default { throw "Unknown condition: $($this.Name)" }
        }
        if ($this.Negate) { return (-not $result) }
        return $result
    }

    [string] Describe() {
        $text = $this.Name
        if ($null -ne $this.Value) { $text = '{0} {1}' -f $this.Name, (@($this.Value) -join '/') }
        if ($this.Negate) { $text = 'not: ' + $text }
        return $text
    }
}
