# Eylem fabrikası: tweak'teki Type alanı → eylem sınıfı. Yeni eylem türü eklerken yalnız bu dosya genişler.
# Bu fazda: Registry, Service. (ScheduledTask, Appx, Winget, Power, File, Shortcut, Script, Native → Faz 2+.)

function Get-FaiActionType {
    <# .SYNOPSIS  Bilinen eylem türü adları. #>
    return [string[]]@('Registry', 'Service')
}

function New-FaiAction {
    <# .SYNOPSIS  Eylem tanımından (hashtable, Type alanlı) ActionBase türevi üretir. Tanım doğrulanmış olmalı. #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true, Position = 0)] [hashtable] $Definition)

    switch ([string]$Definition['Type']) {
        'Registry' { return [RegistryAction]::new($Definition) }
        'Service' { return [ServiceAction]::new($Definition) }
        default { throw ("Bilinmeyen eylem türü: '{0}' (bilinenler: {1})" -f $Definition['Type'], ((Get-FaiActionType) -join ', ')) }
    }
}

function Get-FaiActionError {
    <# .SYNOPSIS  Eylem tanımının şema hataları: '<Path>.<alan>: <neden>' metinleri (yoksa boş). #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)] [AllowNull()] [object] $Definition,
        [Parameter(Position = 1)] [string] $Path = 'Action'
    )

    $errs = New-Object 'System.Collections.Generic.List[string]'
    if ($Definition -isnot [System.Collections.IDictionary]) {
        $errs.Add("${Path}: eylem hashtable olmalı")
        return $errs.ToArray()
    }
    if (-not $Definition.Contains('Type')) {
        $errs.Add("${Path}.Type: zorunlu alan eksik")
        return $errs.ToArray()
    }
    $type = $Definition['Type']
    if ($type -isnot [string] -or (Get-FaiActionType) -cnotcontains $type) {
        $errs.Add("${Path}.Type: bilinmeyen eylem türü '$type' (bilinenler: " + ((Get-FaiActionType) -join ', ') + ')')
        return $errs.ToArray()
    }
    $messages = @()
    switch ($type) {
        'Registry' { $messages = [RegistryAction]::Validate($Definition) }
        'Service' { $messages = [ServiceAction]::Validate($Definition) }
    }
    foreach ($m in $messages) { $errs.Add("${Path}.$m") }
    return $errs.ToArray()
}
