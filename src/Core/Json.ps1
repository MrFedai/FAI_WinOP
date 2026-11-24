# JSON ve değer yardımcıları (Windows PowerShell 5.1'de ConvertFrom-Json -AsHashtable yok).
#
# 5.1 tuzakları:
#   - Fonksiyondan dizi döndürmek boru hattında açılır (tek elemanlı dizi eleman olur, boş dizi hiçbir şey olur);
#     bu yüzden diziler 'return ,$dizi' ile tek nesne olarak döndürülür.
#   - ConvertFrom-Json en üst düzey diziyi de açar; ConvertFrom-JsonText bunu sarmalayarak aşar.

function ConvertTo-Hashtable {
    <#
    .SYNOPSIS
        PSCustomObject / sözlük ağacını iç içe hashtable'a çevirir; diziler dizi, null null, sayı ve bool türleri aynı kalır.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [object] $InputObject
    )

    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [string] -or $InputObject -is [System.ValueType]) { return $InputObject }

    if ($InputObject -is [byte[]]) { return , $InputObject }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $table = @{}
        foreach ($key in @($InputObject.Keys)) {
            $table[[string]$key] = ConvertTo-Hashtable -InputObject $InputObject[$key]
        }
        return $table
    }

    if ($InputObject -is [System.Collections.IEnumerable]) {
        $list = New-Object 'System.Collections.Generic.List[object]'
        foreach ($item in $InputObject) {
            $list.Add((ConvertTo-Hashtable -InputObject $item))
        }
        return , $list.ToArray()
    }

    if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
        $table = @{}
        foreach ($prop in $InputObject.PSObject.Properties) {
            $table[$prop.Name] = ConvertTo-Hashtable -InputObject $prop.Value
        }
        return $table
    }

    return $InputObject
}

function ConvertFrom-JsonText {
    <#
    .SYNOPSIS
        JSON metnini iç içe hashtable / dizi / skaler olarak okur (en üst düzey dizi ve boş dizi dahil).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [AllowEmptyString()]
        [string] $Json
    )

    if ([string]::IsNullOrWhiteSpace($Json)) { throw 'JSON metni boş.' }
    # En üst düzey diziyi ConvertFrom-Json açmasın diye bir nesneye sarılır.
    $parsed = ('{"v":' + $Json + "`n}") | ConvertFrom-Json
    $names = @($parsed.PSObject.Properties | ForEach-Object { $_.Name })
    if ($names.Count -ne 1 -or $names[0] -ne 'v') { throw 'JSON metni tek bir değer olmalı.' }
    return (ConvertTo-Hashtable -InputObject $parsed.v)
}

function Read-JsonFile {
    <# .SYNOPSIS  UTF-8 (BOM'lu ya da BOM'suz) JSON dosyasını ConvertFrom-JsonText ile okur. #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true, Position = 0)] [string] $Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Dosya yok: $Path" }
    $text = [System.IO.File]::ReadAllText((Convert-Path -LiteralPath $Path), [System.Text.Encoding]::UTF8)
    return (ConvertFrom-JsonText -Json $text.TrimStart([char]0xFEFF))
}

function ConvertTo-FaiRegistryValue {
    <#
    .SYNOPSIS
        Değeri kayıt defteri türüne (Kind) göre .NET türüne çevirir (JSON'dan dönen Int32/Int64/Object[] farklarını giderir).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)] [AllowNull()] [object] $Value,
        [Parameter(Position = 1, Mandatory = $true)] [string] $Kind
    )

    switch ($Kind) {
        'DWord' {
            $n = [long]$Value
            if ($n -gt [int]::MaxValue -and $n -le [uint32]::MaxValue) { $n = $n - 4294967296 }
            return [int]$n
        }
        'QWord' { return [long]$Value }
        'String' { return [string]$Value }
        'ExpandString' { return [string]$Value }
        'MultiString' {
            $strings = New-Object 'System.Collections.Generic.List[string]'
            foreach ($s in @($Value)) { $strings.Add([string]$s) }
            return , $strings.ToArray()
        }
        'Binary' {
            $bytes = New-Object 'System.Collections.Generic.List[byte]'
            foreach ($b in @($Value)) { $bytes.Add([byte]$b) }
            return , $bytes.ToArray()
        }
        default { throw "Bilinmeyen kayıt defteri türü: $Kind" }
    }
}

function Test-FaiValueEqual {
    <# .SYNOPSIS  İki değeri karşılaştırır: diziler eleman eleman, sayılar sayı olarak, metinler büyük/küçük harfe duyarlı. #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)] [AllowNull()] [object] $Left,
        [Parameter(Position = 1)] [AllowNull()] [object] $Right
    )

    if ($null -eq $Left -or $null -eq $Right) { return ($null -eq $Left -and $null -eq $Right) }
    $leftIsList = $Left -is [System.Collections.IEnumerable] -and $Left -isnot [string]
    $rightIsList = $Right -is [System.Collections.IEnumerable] -and $Right -isnot [string]
    if ($leftIsList -or $rightIsList) {
        if (-not ($leftIsList -and $rightIsList)) { return $false }
        $l = @($Left)
        $r = @($Right)
        if ($l.Count -ne $r.Count) { return $false }
        for ($i = 0; $i -lt $l.Count; $i++) {
            if (-not (Test-FaiValueEqual -Left $l[$i] -Right $r[$i])) { return $false }
        }
        return $true
    }
    $numeric = @([int], [long], [byte], [uint32], [int16], [uint16], [sbyte], [uint64])
    $leftNum = $numeric -contains $Left.GetType()
    $rightNum = $numeric -contains $Right.GetType()
    if ($leftNum -and $rightNum) { return ([decimal]$Left -eq [decimal]$Right) }
    return ([string]$Left -ceq [string]$Right)
}
