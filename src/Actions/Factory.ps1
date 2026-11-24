# Eylem fabrikası: tweak'teki Type alanı → eylem sınıfı. Yeni eylem türü eklerken yalnız bu dosya genişler
# (Get-FaiActionType, New-FaiAction, Get-FaiActionError) + src/Actions/<Tür>.ps1.

function Get-FaiActionType {
    <# .SYNOPSIS  Bilinen eylem türü adları. #>
    return [string[]]@('Registry', 'RegistryEach', 'Service', 'ScheduledTask', 'Appx', 'Winget', 'Power', 'File', 'Shortcut', 'Script', 'Volume', 'TimerResolution', 'App', 'DefaultBrowser')
}

function New-FaiAction {
    <# .SYNOPSIS  Eylem tanımından (hashtable, Type alanlı) ActionBase türevi üretir. Tanım doğrulanmış olmalı. #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true, Position = 0)] [hashtable] $Definition)

    switch ([string]$Definition['Type']) {
        'Registry' { return [RegistryAction]::new($Definition) }
        'RegistryEach' { return [RegistryEachAction]::new($Definition) }
        'Service' { return [ServiceAction]::new($Definition) }
        'ScheduledTask' { return [ScheduledTaskAction]::new($Definition) }
        'Appx' { return [AppxAction]::new($Definition) }
        'Winget' { return [WingetAction]::new($Definition) }
        'Power' { return [PowerAction]::new($Definition) }
        'File' { return [FileAction]::new($Definition) }
        'Shortcut' { return [ShortcutAction]::new($Definition) }
        'Script' { return [ScriptAction]::new($Definition) }
        'Volume' { return [VolumeAction]::new($Definition) }
        'TimerResolution' { return [TimerResolutionAction]::new($Definition) }
        'App' { return [AppAction]::new($Definition) }
        'DefaultBrowser' { return [DefaultBrowserAction]::new($Definition) }
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
    $actionType = $Definition['Type']
    if ($actionType -isnot [string] -or (Get-FaiActionType) -cnotcontains $actionType) {
        $errs.Add("${Path}.Type: bilinmeyen eylem türü '$actionType' (bilinenler: " + ((Get-FaiActionType) -join ', ') + ')')
        return $errs.ToArray()
    }
    $messages = @()
    switch ($actionType) {
        'Registry' { $messages = [RegistryAction]::Validate($Definition) }
        'RegistryEach' { $messages = [RegistryEachAction]::Validate($Definition) }
        'Service' { $messages = [ServiceAction]::Validate($Definition) }
        'ScheduledTask' { $messages = [ScheduledTaskAction]::Validate($Definition) }
        'Appx' { $messages = [AppxAction]::Validate($Definition) }
        'Winget' { $messages = [WingetAction]::Validate($Definition) }
        'Power' { $messages = [PowerAction]::Validate($Definition) }
        'File' { $messages = [FileAction]::Validate($Definition) }
        'Shortcut' { $messages = [ShortcutAction]::Validate($Definition) }
        'Script' { $messages = [ScriptAction]::Validate($Definition) }
        'Volume' { $messages = [VolumeAction]::Validate($Definition) }
        'TimerResolution' { $messages = [TimerResolutionAction]::Validate($Definition) }
        'App' { $messages = [AppAction]::Validate($Definition) }
        'DefaultBrowser' { $messages = [DefaultBrowserAction]::Validate($Definition) }
    }
    foreach ($m in $messages) { $errs.Add("${Path}.$m") }
    return $errs.ToArray()
}

# --- Eylem doğrulama yardımcıları (Validate yöntemleri kullanır) -------------------------------------------------

function Get-FaiUnknownKeyError {
    <# .SYNOPSIS  İzin verilmeyen alanlar için '<alan>: bilinmeyen alan (...)' iletileri. #>
    [CmdletBinding()]
    param([Parameter(Position = 0)] [System.Collections.IDictionary] $Definition, [Parameter(Position = 1)] [string[]] $Allowed)

    $out = New-Object 'System.Collections.Generic.List[string]'
    foreach ($k in @($Definition.Keys)) {
        if ($Allowed -cnotcontains [string]$k) { $out.Add("${k}: bilinmeyen alan (izin verilenler: " + ($Allowed -join ', ') + ')') }
    }
    return , $out.ToArray()
}

function Test-FaiHasPlaceholder {
    <# .SYNOPSIS  Değer (iç içe) '{{parametre}}' içeriyor mu; içeriyorsa tür denetimi parametre açıldıktan sonra yapılır. #>
    [CmdletBinding()]
    param([Parameter(Position = 0)] [AllowNull()] [object] $Value)
    return (@(Get-FaiPlaceholder -Value $Value).Count -gt 0)
}

function Test-FaiIsInteger {
    <# .SYNOPSIS  Değer tamsayı mı (int / long; psd1 ve JSON'dan gelen türler). #>
    [CmdletBinding()]
    param([Parameter(Position = 0)] [AllowNull()] [object] $Value)
    return ($Value -is [int] -or $Value -is [long])
}

function Test-FaiWindowsPath {
    <# .SYNOPSIS  Mutlak Windows yolu mu: 'C:\...', '\\sunucu\...' ya da '%DEĞİŞKEN%\...'. #>
    [CmdletBinding()]
    param([Parameter(Position = 0)] [AllowNull()] [object] $Value)
    if ($Value -isnot [string]) { return $false }
    return ($Value -match '^([A-Za-z]:\\|\\\\[^\\]+\\|%[A-Za-z_][A-Za-z0-9_()]*%\\).+')
}

function Expand-FaiPath {
    <# .SYNOPSIS  Yoldaki %DEĞİŞKEN%'leri açar (tanımsız olan olduğu gibi kalır). #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true, Position = 0)] [string] $Path)
    return [Environment]::ExpandEnvironmentVariables($Path)
}

function Test-FaiScriptText {
    <# .SYNOPSIS  PowerShell kodunun ayrıştırma hataları (yoksa boş). #>
    [CmdletBinding()]
    param([Parameter(Position = 0)] [string] $Code)
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseInput($Code, [ref]$tokens, [ref]$parseErrors)
    $out = New-Object 'System.Collections.Generic.List[string]'
    foreach ($e in @($parseErrors)) { if ($null -ne $e) { $out.Add(('{0}. satır: {1}' -f $e.Extent.StartLineNumber, $e.Message)) } }
    return , $out.ToArray()
}
