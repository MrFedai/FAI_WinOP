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
        foreach ($f in @('Apply', 'Revert')) { if (-not $Def.Contains($f)) { $e.Add("${f}: zorunlu alan eksik") } }
        foreach ($f in [ScriptAction]::CodeFields()) {
            if (-not $Def.Contains($f)) { continue }
            if ($Def[$f] -isnot [string] -or [string]::IsNullOrWhiteSpace($Def[$f])) { $e.Add("${f}: boş olmayan PowerShell kodu (metin) olmalı"); continue }
            foreach ($pe in (Test-FaiScriptText $Def[$f])) { $e.Add("${f}: ayrıştırma hatası, $pe") }
        }
        if ($Def.Contains('Description') -and $Def['Description'] -isnot [string]) { $e.Add('Description: metin olmalı') }
        return $e.ToArray()
    }

    [bool] Test([ExecutionContext] $Ctx) {
        if (-not $this.Definition.ContainsKey('Test')) { return $false }
        $result = $Ctx.Scripts.Query([string]$this.Definition['Test'], $null)
        return [bool](@($result) | Select-Object -Last 1)
    }

    [hashtable] Snapshot([ExecutionContext] $Ctx) {
        if (-not $this.Definition.ContainsKey('Snapshot')) { return @{ Value = $null } }
        $value = $Ctx.Scripts.Query([string]$this.Definition['Snapshot'], $null)
        return @{ Value = $value }
    }

    [void] Apply([ExecutionContext] $Ctx) { [void]$Ctx.Scripts.Run([string]$this.Definition['Apply'], $null) }

    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) { [void]$Ctx.Scripts.Run([string]$this.Definition['Revert'], $Snapshot['Value']) }

    [string] Describe() {
        $text = 'özel işlem'
        if ($this.Definition.ContainsKey('Description') -and $this.Definition['Description']) { $text = [string]$this.Definition['Description'] }
        return ('Betik: {0}' -f $text)
    }
}
