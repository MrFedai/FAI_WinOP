# ScriptAction: başka eylem türüyle ifade edilemeyen iş için PowerShell betiği. Yalnız $Ctx.Scripts üzerinden.
#
#   @{ Type='Script'; Description='Örnek'
#      Test     = '(Get-Item ...).Prop -eq 1'           # isteğe bağlı, SALT OKUNUR; $true → yapılacak iş yok
#      Snapshot = '(Get-Item ...).Prop'                 # isteğe bağlı, SALT OKUNUR; dönen değer JSON'a yazılabilir olmalı
#      Apply    = 'Set-... -Value 1'                    # zorunlu
#      Revert   = 'param($Snapshot) Set-... -Value $Snapshot' }   # zorunlu; Snapshot'ın değerini alır
# Test yoksa eylem her çalıştırmada uygulanır. Betik son çaredir: önce Registry / Service / File... eylemleri.
# Dry-run'da yalnız Test çalışır; Test durum değiştirmemelidir.

class ScriptAction : ActionBase {
    ScriptAction([hashtable] $Definition) : base($Definition) { }

    static [string[]] CodeFields() { return [string[]]@('Test', 'Snapshot', 'Apply', 'Revert') }

    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        foreach ($m in (Get-FaiUnknownKeyError $Def (@('Type', 'Description') + [ScriptAction]::CodeFields()))) { $e.Add($m) }
        foreach ($f in @('Apply', 'Revert')) { if (-not $Def.Contains($f)) { $e.Add("${f}: required field missing") } }
        foreach ($f in [ScriptAction]::CodeFields()) {
            if (-not $Def.Contains($f)) { continue }
            if ($Def[$f] -isnot [string] -or [string]::IsNullOrWhiteSpace($Def[$f])) { $e.Add("${f}: must be non-empty PowerShell code (text)"); continue }
            foreach ($pe in (Test-FaiScriptText $Def[$f])) { $e.Add("${f}: parse error, $pe") }
        }
        if ($Def.Contains('Description') -and $Def['Description'] -isnot [string]) { $e.Add('Description: must be text') }
        return $e.ToArray()
    }

    # Test betiği çıktısının doğruluk yorumu: PowerShell'de boş olmayan "False" / "0" metni $true sayılır; burada yanlış.
    static [bool] IsTruthy([object] $Value) {
        if ($null -eq $Value) { return $false }
        if ($Value -is [bool]) { return [bool]$Value }
        if ($Value -is [string]) {
            $t = ([string]$Value).Trim()
            if ($t.Length -eq 0) { return $false }
            $d = 0.0
            if ([double]::TryParse($t, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$d)) { return ($d -ne 0) }
            return ($t -ine 'false')
        }
        if ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal] -or $Value -is [single] -or $Value -is [byte] -or $Value -is [int16] -or $Value -is [uint16] -or $Value -is [uint32] -or $Value -is [uint64] -or $Value -is [sbyte]) { return ([double]$Value -ne 0) }
        return [bool]$Value
    }

    [bool] Test([ExecutionContext] $Ctx) {
        if (-not $this.Definition.ContainsKey('Test')) { return $false }
        $result = $Ctx.Scripts.Query([string]$this.Definition['Test'], $null)
        return [ScriptAction]::IsTruthy((@($result) | Select-Object -Last 1))
    }

    [hashtable] Snapshot([ExecutionContext] $Ctx) {
        if (-not $this.Definition.ContainsKey('Snapshot')) { return @{ Value = $null } }
        $value = $Ctx.Scripts.Query([string]$this.Definition['Snapshot'], $null)
        return @{ Value = $value }
    }

    [void] Apply([ExecutionContext] $Ctx) { [void]$Ctx.Scripts.Run([string]$this.Definition['Apply'], $null) }

    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) { [void]$Ctx.Scripts.Run([string]$this.Definition['Revert'], $Snapshot['Value']) }

    [string] Describe() {
        $text = 'custom operation'
        if ($this.Definition.ContainsKey('Description') -and $this.Definition['Description']) { $text = [string]$this.Definition['Description'] }
        return ('Script: {0}' -f $text)
    }
}
