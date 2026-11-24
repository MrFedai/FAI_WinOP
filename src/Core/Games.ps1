# Oyun başına ayarlar (gaming.per-game): profilin 'games' listesinden üretilen tweak.
#
#   "games": [ { "exe": "cs2.exe", "priority": "High", "smtOff": true, "excludeCore0": true } ]
#
# priority     → IFEO ...\Image File Execution Options\<exe>\PerfOptions CpuPriorityClass (Windows her açılışta uygular).
# smtOff       → yalnız her fiziksel çekirdeğin ilk mantıksal işlemcisi (SMT / HT kardeşi kullanılmaz).
# excludeCore0 → çekirdek 0'ın mantıksal işlemcileri kullanılmaz (kesme / sistem işleri çoğunlukla orada).
# İşlemci benzeşimi (affinity) IFEO'da yok: maskeler açılışta başlayan bir SYSTEM görevine (GameAffinity eylemi) yazılır;
# görev oyun süreci başlayınca benzeşimi ayarlar. Maskeler bu makinenin mantıksal işlemci / çekirdek sayısından hesaplanır.

function Get-FaiGamePriorityMap {
    <# .SYNOPSIS  priority adı → CpuPriorityClass değeri (Gerçek zamanlı bilerek yok). #>
    return [ordered]@{ Idle = 1; BelowNormal = 5; Normal = 2; AboveNormal = 6; High = 3 }
}

function Get-FaiGameExePattern { return '^[A-Za-z0-9][A-Za-z0-9._ \-]*\.[Ee][Xx][Ee]$' }

function Get-FaiAffinityMask {
    <#
    .SYNOPSIS
        Mantıksal işlemci maskesi (bit i = mantıksal işlemci i). SMT'li çekirdek sayısı = Logical - Cores; bunların
        mantıksal işlemcileri önce ve yan yana sayılır (0-1 = çekirdek 0, 2-3 = çekirdek 1 ...), SMT'siz çekirdekler
        (hibrit Intel'de E çekirdekleri) sonra tek tek. AMD / Intel SMT'li ve SMT'siz işlemcilerde Windows'un sıralaması
        budur.
    .PARAMETER SmtOff
        Her SMT'li çekirdeğin yalnız ilk mantıksal işlemcisi + SMT'siz bütün çekirdekler.
    .PARAMETER ExcludeCore0
        Çekirdek 0'ın mantıksal işlemcileri çıkarılır (SMT varsa 0 ve 1, yoksa 0).
    #>
    [CmdletBinding()]
    [OutputType([long])]
    param(
        [Parameter(Mandatory = $true)] [int] $Logical,
        [Parameter(Mandatory = $true)] [int] $Cores,
        [switch] $SmtOff,
        [switch] $ExcludeCore0
    )

    if ($Logical -lt 1 -or $Cores -lt 1) { throw "İşlemci sayısı geçersiz: $Logical mantıksal, $Cores çekirdek" }
    if ($Logical -gt 64) { throw "64'ten fazla mantıksal işlemci desteklenmiyor (işlemci grupları): $Logical" }
    if ($Cores -gt $Logical -or $Logical -gt 2 * $Cores) { throw "Mantıksal / çekirdek oranı tanınmıyor: $Logical / $Cores" }
    $smtCores = $Logical - $Cores
    [long]$mask = 0
    for ($lp = 0; $lp -lt $Logical; $lp++) {
        $inSmt = $lp -lt (2 * $smtCores)
        if ($SmtOff.IsPresent -and $inSmt -and ($lp % 2) -eq 1) { continue }
        if ($ExcludeCore0.IsPresent) {
            if ($lp -eq 0) { continue }
            if ($smtCores -gt 0 -and $lp -eq 1) { continue }
        }
        $mask = $mask -bor ([long]1 -shl $lp)
    }
    if ($mask -eq 0) { throw 'Benzeşim maskesi boş kaldı (çekirdek sayısı çok az)' }
    return $mask
}

function Get-FaiGameError {
    <# .SYNOPSIS  Profilin 'games' listesinin şema hataları ('games[i].alan: neden'). #>
    [CmdletBinding()]
    param([Parameter(Position = 0)] [AllowNull()] [object] $Games)

    $errs = New-Object 'System.Collections.Generic.List[string]'
    if (-not (Test-FaiIsList $Games)) {
        $errs.Add('games: dizi olmalı')
        return $errs.ToArray()
    }
    $allowed = @('exe', 'priority', 'smtOff', 'excludeCore0')
    $seen = @{}
    $i = 0
    foreach ($g in @($Games)) {
        $path = "games[$i]"
        $i++
        if ($g -isnot [System.Collections.IDictionary]) { $errs.Add("${path}: { exe, priority, smtOff, excludeCore0 } nesnesi olmalı"); continue }
        foreach ($k in @($g.Keys)) {
            if ($allowed -cnotcontains [string]$k) { $errs.Add("${path}.${k}: bilinmeyen alan (izin verilenler: " + ($allowed -join ', ') + ')') }
        }
        if (-not $g.Contains('exe')) { $errs.Add("${path}.exe: zorunlu alan eksik") }
        elseif ($g['exe'] -isnot [string] -or $g['exe'] -notmatch (Get-FaiGameExePattern)) {
            $errs.Add("${path}.exe: yalnız dosya adı olmalı (ör. cs2.exe; yol değil)")
        }
        else {
            $key = ([string]$g['exe']).ToLowerInvariant()
            if ($seen.ContainsKey($key)) { $errs.Add("${path}.exe: '$($g['exe'])' birden çok kez listelenmiş") }
            $seen[$key] = $true
        }
        if ($g.Contains('priority') -and ($g['priority'] -isnot [string] -or @((Get-FaiGamePriorityMap).Keys) -cnotcontains $g['priority'])) {
            $errs.Add("${path}.priority: " + (@((Get-FaiGamePriorityMap).Keys) -join ', ') + ' değerlerinden biri olmalı')
        }
        foreach ($b in @('smtOff', 'excludeCore0')) {
            if ($g.Contains($b) -and $g[$b] -isnot [bool]) { $errs.Add("${path}.${b}: true ya da false olmalı") }
        }
        if (-not $g.Contains('priority') -and -not [bool]$g['smtOff'] -and -not [bool]$g['excludeCore0']) {
            $errs.Add("${path}: en az bir ayar gerekir (priority, smtOff ya da excludeCore0)")
        }
    }
    return $errs.ToArray()
}

function Get-FaiGameAffinityScript {
    <#
    .SYNOPSIS
        gaming.per-game izleyici görevinin betiği: listedeki exe başlayınca (Win32_ProcessStartTrace) süreç benzeşimini
        maskeye ayarlar; görev başlarken açık olanlara da uygular. Günlük <StateDirectory>\GameAffinity.log.
    .PARAMETER Games
        @{ Exe; Mask } listesi (Exe doğrulanmış dosya adı).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [object[]] $Games,
        [string] $StateDirectory = '%ProgramData%\FAI_WinOP'
    )
    $rows = New-Object 'System.Collections.Generic.List[string]'
    $where = New-Object 'System.Collections.Generic.List[string]'
    foreach ($g in $Games) {
        $exe = ([string]$g['Exe']).ToLowerInvariant()
        if ($exe -notmatch (Get-FaiGameExePattern)) { throw "Oyun dosya adı geçersiz: $exe" }
        $rows.Add(("    '{0}' = [long]{1}" -f $exe, [long]$g['Mask']))
        $where.Add(("ProcessName='{0}'" -f $exe))
    }
    $lines = @(
        '# FAI_WinOP gaming.per-game: oyun süreci başlayınca işlemci benzeşimini (affinity) ayarlar.'
        '# Otomatik üretildi; elle düzenlemeyin. Kaldırmak için FAI_WinOP -Undo (görev ve betik birlikte gider).'
        '$ErrorActionPreference = ''Continue'''
        '$games = @{'
        ($rows -join "`r`n")
        '}'
        ('$dir = [Environment]::ExpandEnvironmentVariables(''{0}'')' -f $StateDirectory)
        '$log = Join-Path $dir ''GameAffinity.log'''
        'function Write-AffinityLog([string] $Text) { Add-Content -LiteralPath $log -Value (''{0:yyyy-MM-dd HH:mm:ss} {1}'' -f (Get-Date), $Text) -Encoding UTF8 }'
        'function Set-GameAffinity([int] $ProcessId, [string] $Name) {'
        '    $mask = $games[$Name.ToLowerInvariant()]'
        '    try {'
        '        $p = Get-Process -Id $ProcessId -ErrorAction Stop'
        '        $p.ProcessorAffinity = [IntPtr]$mask'
        '        Write-AffinityLog (''{0} ({1}): benzeşim 0x{2:X}'' -f $Name, $ProcessId, $mask)'
        '    }'
        '    catch { Write-AffinityLog (''{0} ({1}): ayarlanamadı: {2}'' -f $Name, $ProcessId, $_.Exception.Message) }'
        '}'
        'foreach ($n in @($games.Keys)) {'
        '    foreach ($p in @(Get-Process -Name ([IO.Path]::GetFileNameWithoutExtension($n)) -ErrorAction SilentlyContinue)) { Set-GameAffinity $p.Id $n }'
        '}'
        ('$query = "SELECT * FROM Win32_ProcessStartTrace WHERE {0}"' -f ($where -join ' OR '))
        'Register-CimIndicationEvent -Query $query -SourceIdentifier ''FaiGameStart'' | Out-Null'
        'Write-AffinityLog ''izleme başladı'''
        'while ($true) {'
        '    $e = Wait-Event -SourceIdentifier ''FaiGameStart'''
        '    $name = [string]$e.SourceEventArgs.NewEvent.ProcessName'
        '    $procId = [int]$e.SourceEventArgs.NewEvent.ProcessID'
        '    Remove-Event -EventIdentifier $e.EventIdentifier'
        '    if ($games.ContainsKey($name.ToLowerInvariant())) { Start-Sleep -Milliseconds 500; Set-GameAffinity $procId $name }'
        '}'
    )
    return (($lines -join "`r`n") + "`r`n")
}

function ConvertTo-FaiGamesTweak {
    <#
    .SYNOPSIS
        Profilin 'games' listesinden 'gaming.per-game' tweak'i: öncelik için IFEO Registry eylemleri, benzeşim maskesi
        gereken oyunlar için tek GameAffinity eylemi (yoksa eklenmez).
    .PARAMETER Logical
        Mantıksal işlemci sayısı (ISystemInfoProvider.GetLogicalProcessorCount).
    .PARAMETER Cores
        Fiziksel çekirdek sayısı (ISystemInfoProvider.GetCoreCount).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [object[]] $Games,
        [Parameter(Mandatory = $true)] [int] $Logical,
        [Parameter(Mandatory = $true)] [int] $Cores
    )

    $errors = @(Get-FaiGameError -Games $Games)
    if ($errors.Count -gt 0) { throw ("games geçersiz:`n  " + ($errors -join "`n  ")) }
    $ifeo = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'
    $prio = Get-FaiGamePriorityMap
    $actions = New-Object 'System.Collections.Generic.List[hashtable]'
    $masks = New-Object 'System.Collections.Generic.List[hashtable]'
    foreach ($g in $Games) {
        $exe = [string]$g['exe']
        if ($g.Contains('priority')) {
            $actions.Add(@{ Type = 'Registry'; Path = ('{0}\{1}\PerfOptions' -f $ifeo, $exe); Name = 'CpuPriorityClass'; Value = [int]$prio[[string]$g['priority']]; Kind = 'DWord' })
        }
        if ([bool]$g['smtOff'] -or [bool]$g['excludeCore0']) {
            $mask = Get-FaiAffinityMask -Logical $Logical -Cores $Cores -SmtOff:([bool]$g['smtOff']) -ExcludeCore0:([bool]$g['excludeCore0'])
            $masks.Add(@{ Exe = $exe.ToLowerInvariant(); Mask = $mask })
        }
    }
    if ($masks.Count -gt 0) {
        $actions.Add(@{ Type = 'GameAffinity'; Games = $masks.ToArray(); TaskPath = '\FAI_WinOP\GameAffinity'; ScriptPath = '%ProgramData%\FAI_WinOP\GameAffinity.ps1' })
    }

    $data = @{
        Id          = 'gaming.per-game'
        Title       = 'Oyun başına öncelik ve işlemci benzeşimi'
        Description = ('Profilin games listesi ({0} oyun): IFEO CpuPriorityClass; SMT kapalı / çekirdek 0 hariç maskeleri bu makineden ({1} mantıksal, {2} çekirdek) hesaplanır ve açılış görevi oyun başlayınca uygular.' -f @($Games).Count, $Logical, $Cores)
        Category    = 'gaming'
        Risk        = 'Safe'
        Actions     = $actions.ToArray()
    }
    return [Tweak]::FromHashtable($data, 'profil games')
}
