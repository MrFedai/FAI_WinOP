# Tweak: bir .psd1 dosyasından (veri) gelen ayar tanımı. Eylemler parametre yer tutucuları ('{{ad}}') içerebilir;
# profil Params ile varsayılanları geçersiz kılar (ör. sound.volume { level = 15 }).

# Yer tutucu: '{{ad}}'. Metnin tamamı yer tutucuysa değerin türü korunur; metin içindeyse metne gömülür.
function Get-FaiPlaceholderPattern { return '\{\{\s*([A-Za-z][A-Za-z0-9_]*)\s*\}\}' }

function Expand-FaiParam {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)] [AllowNull()] [object] $Value,
        [Parameter(Position = 1)] [hashtable] $Params
    )

    if ($Value -is [string]) {
        $pattern = Get-FaiPlaceholderPattern
        $whole = [regex]::Match($Value, '^\s*' + $pattern + '\s*$')
        if ($whole.Success) {
            $name = $whole.Groups[1].Value
            if (-not $Params.ContainsKey($name)) { throw "Tanımsız parametre: $name" }
            return , $Params[$name]
        }
        $expanded = $Value
        foreach ($m in [regex]::Matches($Value, $pattern)) {
            $name = $m.Groups[1].Value
            if (-not $Params.ContainsKey($name)) { throw "Tanımsız parametre: $name" }
            $expanded = $expanded.Replace($m.Value, [string]$Params[$name])
        }
        return $expanded
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $table = @{}
        foreach ($key in @($Value.Keys)) {
            $table[$key] = Expand-FaiParam -Value $Value[$key] -Params $Params
        }
        return $table
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string] -and $Value -isnot [byte[]]) {
        $list = New-Object 'System.Collections.Generic.List[object]'
        foreach ($item in $Value) { $list.Add((Expand-FaiParam -Value $item -Params $Params)) }
        return , $list.ToArray()
    }
    return $Value
}

function Get-FaiPlaceholder {
    <# .SYNOPSIS  Değerdeki (iç içe) bütün yer tutucu adlarını döndürür. #>
    [CmdletBinding()]
    param([Parameter(Position = 0)] [AllowNull()] [object] $Value)

    $names = New-Object 'System.Collections.Generic.List[string]'
    if ($Value -is [string]) {
        foreach ($m in [regex]::Matches($Value, (Get-FaiPlaceholderPattern))) { $names.Add($m.Groups[1].Value) }
    }
    elseif ($Value -is [System.Collections.IDictionary]) {
        foreach ($key in @($Value.Keys)) {
            foreach ($n in @(Get-FaiPlaceholder -Value $Value[$key])) { $names.Add($n) }
        }
    }
    elseif ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [byte[]]) {
        foreach ($item in $Value) {
            foreach ($n in @(Get-FaiPlaceholder -Value $item)) { $names.Add($n) }
        }
    }
    return $names.ToArray()
}

class Tweak {
    [string] $Id
    [string] $Title
    [string] $Description
    [string] $Category
    [string] $Risk = 'Safe'
    # Caution / Risk sorusunda gösterilen ek uyarı metni (isteğe bağlı).
    [string] $Confirm = ''
    # Uygulama / geri alma sonrası kabuk yenilemeleri (Get-FaiRefreshKind): Shell, Desktop, Settings, StartMenu.
    [string[]] $Refresh = @()
    [Condition[]] $Conditions = @()
    # Ham eylem tanımları (yer tutucular açılmamış).
    [hashtable[]] $ActionDefs = @()
    [hashtable] $Params = @{}
    # Params varsayılanlarıyla kurulmuş eylemler.
    [ActionBase[]] $Actions = @()

    Tweak() { }

    # Doğrulanmış .psd1 verisinden Tweak üretir; şemaya uymuyorsa alan yolu + nedenle birlikte hata fırlatır.
    static [Tweak] FromHashtable([hashtable] $Data, [string] $Source) {
        $errors = @(Get-FaiTweakError -Data $Data)
        if ($errors.Count -gt 0) {
            throw ("Tweak geçersiz ({0}):`n  {1}" -f $Source, ($errors -join "`n  "))
        }
        $t = [Tweak]::new()
        $t.Id = [string]$Data['Id']
        $t.Title = [string]$Data['Title']
        $t.Description = [string]$Data['Description']
        $t.Category = [string]$Data['Category']
        if ($Data.ContainsKey('Risk')) { $t.Risk = [string]$Data['Risk'] }
        if ($Data.ContainsKey('Confirm')) { $t.Confirm = [string]$Data['Confirm'] }
        if ($Data.ContainsKey('Params')) { $t.Params = $Data['Params'] }
        if ($Data.ContainsKey('Refresh')) { $t.Refresh = [string[]]@($Data['Refresh']) }
        $conds = New-Object 'System.Collections.Generic.List[Condition]'
        if ($Data.ContainsKey('Conditions')) {
            foreach ($c in @($Data['Conditions'])) { $conds.Add([Condition]::Parse($c)) }
        }
        $t.Conditions = $conds.ToArray()
        $defs = New-Object 'System.Collections.Generic.List[hashtable]'
        foreach ($a in @($Data['Actions'])) { $defs.Add([hashtable]$a) }
        $t.ActionDefs = $defs.ToArray()
        $t.Actions = $t.BuildActions($t.Params)
        return $t
    }

    # Verilen parametre değerleriyle eylemleri kurar (yer tutucular açılır, her eylem yeniden doğrulanır).
    [ActionBase[]] BuildActions([hashtable] $ParamValues) {
        $list = New-Object 'System.Collections.Generic.List[ActionBase]'
        $i = 0
        foreach ($def in $this.ActionDefs) {
            $expanded = [hashtable](Expand-FaiParam -Value $def -Params $ParamValues)
            $errors = @(Get-FaiActionError -Definition $expanded -Path ("Actions[{0}]" -f $i))
            if ($errors.Count -gt 0) {
                throw ("Tweak '{0}' parametreleriyle geçersiz:`n  {1}" -f $this.Id, ($errors -join "`n  "))
            }
            $list.Add((New-FaiAction -Definition $expanded))
            $i++
        }
        return $list.ToArray()
    }

    # Profilin parametre geçersiz kılmalarıyla yeni bir Tweak döndürür (asıl nesne değişmez).
    [Tweak] WithParams([hashtable] $Overrides) {
        $merged = @{}
        foreach ($k in @($this.Params.Keys)) { $merged[$k] = $this.Params[$k] }
        if ($null -ne $Overrides) {
            foreach ($k in @($Overrides.Keys)) {
                if (-not $this.Params.ContainsKey($k)) {
                    throw ("Tweak '{0}' için tanımsız parametre: {1} (tanımlılar: {2})" -f $this.Id, $k, (@($this.Params.Keys) -join ', '))
                }
                $merged[$k] = $Overrides[$k]
            }
        }
        $t = [Tweak]::new()
        $t.Id = $this.Id
        $t.Title = $this.Title
        $t.Description = $this.Description
        $t.Category = $this.Category
        $t.Risk = $this.Risk
        $t.Confirm = $this.Confirm
        $t.Refresh = $this.Refresh
        $t.Conditions = $this.Conditions
        $t.ActionDefs = $this.ActionDefs
        $t.Params = $merged
        $t.Actions = $t.BuildActions($merged)
        return $t
    }

    # Sağlanmayan ilk koşulun açıklaması; hepsi sağlanıyorsa boş metin.
    [string] FirstFailedCondition([ISystemInfoProvider] $Sys) {
        foreach ($c in $this.Conditions) {
            if (-not $c.Test($Sys)) { return $c.Describe() }
        }
        return ''
    }
}
