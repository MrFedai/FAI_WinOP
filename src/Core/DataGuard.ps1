# Veri klasörünün (%ProgramData%\FAI_WinOP) korunması. Windows'a yalnız IFileSecurityProvider üzerinden dokunur.
#
# Neden: klasörde yönetici / SYSTEM olarak çalıştırılan ya da güvenilen dosyalar durur: yedek oturumları (-Undo eylem
# tanımını oradan okur), açılış görevlerinin betikleri (SYSTEM), yeniden başlatma sonrası devam kopyası (RunOnce).
# %ProgramData% varsayılan izninde standart kullanıcı alt klasör / dosya oluşturabilir ve sahibi olur; araçtan önce
# klasörü açan, içine bağlantı (junction / symlink) koyan yönetici sürecini başka yere yazdırabilir. Bu yüzden her
# yönetici çalıştırmasının ilk işi Protect-FaiDataDirectory:
#   1) kök bağlantıysa, klasör değilse ya da sahibi güvenilir değilse kenara alınır (<ad>.untrusted-<zaman>), yenisi açılır
#   2) kökün izni: kalıtım kapalı; yalnız SYSTEM + Administrators (tam), sahip Administrators. Doğru değilse düzeltilir.
#   3) 'shared' alt klasörü: aynı izin + Users okuma. Yükseltilmemiş Windows bileşenlerinin okuması gereken dosyalar
#      burada: görev çubuğu düzeni (Gezgin, kullanıcı bağlamı), yeniden başlatma sonrası devam kopyası.
#   4) içerik taranır: sahibi güvenilir olmayan ya da bağlantı olan her öğe kenara alınır (içine girilmez)
# Kenara alınan hiçbir şey silinmez; araç '.untrusted-' adlı öğeleri kullanmaz. Taşınamayan öğe hatadır (çalışma durur).
# Yönetici gerektirmeyen işler (-ExportProfile, -ExportLayout) bu klasöre hiç dokunmaz (Cli: Initialize-FaiRunStorage).

function Get-FaiSharedDataName {
    <# .SYNOPSIS  Veri klasöründe Users'ın okuyabildiği alt klasörün adı. #>
    return 'shared'
}

function Test-FaiQuarantinedName {
    <# .SYNOPSIS  Ad, daha önce kenara alınmış bir öğenin adı mı (<ad>.untrusted-<14 rakam>[-n]). #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [string] $Name)
    return ($Name -match '\.untrusted-\d{14}(-\d+)?$')
}

function Test-FaiRestrictedAcl {
    <#
    .SYNOPSIS
        GetAcl sonucu beklenen izin mi: kalıtım kapalı, sahip Administrators, yalnız açık (kalıtılmamış, alt öğelere geçen)
        izin kuralları: SYSTEM + Administrators tam, ReaderSid'ler okuma; başka kural yok.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [hashtable] $Acl,
        [string[]] $ReaderSid = @()
    )
    if (-not [bool]$Acl['Protected']) { return $false }
    if ([string]$Acl['Owner'] -ne 'S-1-5-32-544') { return $false }
    $expected = @{ 'S-1-5-18' = 'Full'; 'S-1-5-32-544' = 'Full' }
    foreach ($r in $ReaderSid) { $expected[$r] = 'Read' }
    $seen = @{}
    foreach ($rule in @($Acl['Rules'])) {
        if ($null -eq $rule) { continue }
        $sid = [string]$rule['Sid']
        if ([bool]$rule['Deny'] -or [bool]$rule['Inherited'] -or -not [bool]$rule['Inherits']) { return $false }
        if (-not $expected.ContainsKey($sid) -or $expected[$sid] -ne [string]$rule['Access']) { return $false }
        $seen[$sid] = $true
    }
    return ($seen.Count -eq $expected.Count)
}

function Move-FaiUntrustedItem {
    <# .SYNOPSIS  Öğeyi aynı klasörde <ad>.untrusted-<zaman>[-n] adına taşır (bağlantının kendisi); yeni yolu döndürür. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [IFileSecurityProvider] $Security,
        [Parameter(Mandatory = $true)] [string] $Path
    )
    $base = '{0}.untrusted-{1}' -f $Path, (Get-Date -Format 'yyyyMMddHHmmss')
    $target = $base
    $n = 0
    while ($Security.GetItemType($target) -ne '') {
        $n++
        $target = '{0}-{1}' -f $base, $n
    }
    $Security.MoveItem($Path, $target)
    return $target
}

function Protect-FaiDataDirectory {
    <#
    .SYNOPSIS
        Veri klasörünü açar / korur (dosya başındaki 4 adım). Yönetici gerekir.
    .OUTPUTS
        @{ Quarantined = <kenara alınan öğelerin yeni yolları>; AclFixed = <izni düzeltilen klasörler> }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)] [IFileSecurityProvider] $Security,
        [Parameter(Mandatory = $true)] [string] $Path
    )

    $moved = New-Object 'System.Collections.Generic.List[string]'
    $fixed = New-Object 'System.Collections.Generic.List[string]'
    $root = $Path.TrimEnd('\')
    $sharedPath = $root + '\' + (Get-FaiSharedDataName)
    $readers = @{ $root = [string[]]@(); $sharedPath = [string[]]@('S-1-5-32-545') }

    foreach ($dir in @($root, $sharedPath)) {
        $type = $Security.GetItemType($dir)
        if ($type -ne '' -and -not ($type -eq 'Directory' -and $Security.IsTrusted($dir))) {
            $moved.Add((Move-FaiUntrustedItem -Security $Security -Path $dir))
        }
        $created = $false
        if ($Security.GetItemType($dir) -eq '') {
            $Security.CreateDirectory($dir)
            $created = $true
        }
        # Yeni açılan klasör bağlantıysa (taşıma ile oluşturma arasında araya giren) dokunulmaz: izin bağlantının hedefine yazılırdı.
        if ($Security.IsReparsePoint($dir)) { throw "Veri klasörü bir bağlantı (junction / symlink), kullanılmadı: $dir" }
        if (-not (Test-FaiRestrictedAcl -Acl $Security.GetAcl($dir) -ReaderSid $readers[$dir])) {
            $Security.SetRestrictedAcl($dir, $readers[$dir])
            if (-not $created) { $fixed.Add($dir) }
        }
        if (-not $Security.IsTrusted($dir)) { throw "Veri klasörünün sahibi SYSTEM / Administrators değil, kullanılmadı: $dir" }
    }

    # İzin kilitlendi (yeni yazma olmaz); şimdi içerik.
    $pending = New-Object 'System.Collections.Generic.Stack[string]'
    $pending.Push($root)
    while ($pending.Count -gt 0) {
        $dir = $pending.Pop()
        foreach ($entry in $Security.GetEntries($dir)) {
            $name = $entry.Substring($entry.LastIndexOf('\') + 1)
            if (Test-FaiQuarantinedName -Name $name) { continue }
            if (-not $Security.IsTrusted($entry)) {
                $moved.Add((Move-FaiUntrustedItem -Security $Security -Path $entry))
                continue
            }
            if ($Security.GetItemType($entry) -eq 'Directory') { $pending.Push($entry) }
        }
    }
    return @{ Quarantined = $moved.ToArray(); AclFixed = $fixed.ToArray() }
}
