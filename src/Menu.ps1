# Etkileşimli menü (profil verilmeden çalıştırılınca). Girdi yalnız $Context.Prompt.ReadLine'dan gelir (testte
# FakePromptProvider kuyruğu). Seçim söz dizimi: '1 3 5', '1,3', '2-4'; 'h' hepsi, 'y' hiçbiri, Enter tamam.
# Çalıştırmadan önce Ö (önizle: dry-run) / U (uygula) / G (geri) sorulur; önizleme sonrası aynı soru tekrar gelir.
# Boş yanıt ana menüde yeniden çizer; art arda çok boş yanıt (kapalı girdi) menüyü kapatır.

function Get-FaiCategoryLabel {
    <# .SYNOPSIS  Kategori adı → Türkçe başlık (bilinmeyen ad kendisi). Sıra: menüdeki sıra. #>
    return [ordered]@{
        setup    = 'Kurulum'
        ui       = 'Arayüz'
        bloat    = 'Bloatware'
        privacy  = 'Gizlilik'
        sound    = 'Ses'
        power    = 'Güç'
        graphics = 'Grafik'
        gaming   = 'Oyun'
        system   = 'Sistem'
        refresh  = 'Araçlar'
    }
}

function Get-FaiMenuCategory {
    <#
    .SYNOPSIS
        Katalogu kategorilere böler: @{ Name; Label; Tweaks (Id sıralı) } listesi, Get-FaiCategoryLabel sırasıyla;
        bilinmeyen kategoriler sonda alfabetik.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [hashtable] $Catalog)

    $labels = Get-FaiCategoryLabel
    $groups = @{}
    foreach ($t in @($Catalog.Values)) {
        $c = [string]$t.Category
        if (-not $groups.ContainsKey($c)) { $groups[$c] = New-Object 'System.Collections.Generic.List[object]' }
        $groups[$c].Add($t)
    }
    $order = New-Object 'System.Collections.Generic.List[string]'
    foreach ($k in $labels.Keys) { if ($groups.ContainsKey($k)) { $order.Add($k) } }
    foreach ($k in @($groups.Keys | Sort-Object)) { if (-not $order.Contains($k)) { $order.Add($k) } }
    $out = New-Object 'System.Collections.Generic.List[object]'
    foreach ($k in $order) {
        $label = $k
        if ($labels.Contains($k)) { $label = $labels[$k] }
        $out.Add(@{ Name = $k; Label = $label; Tweaks = @($groups[$k] | Sort-Object Id) })
    }
    return , $out.ToArray()
}

function Get-FaiRiskColor {
    param([string] $Risk)
    switch ($Risk) {
        'Safe' { return 'Green' }
        'Caution' { return 'Yellow' }
        'Risk' { return 'Red' }
    }
    return 'Gray'
}

function ConvertFrom-FaiSelection {
    <#
    .SYNOPSIS
        '1 3 5' / '1,3' / '2-4' → 1 tabanlı sıra numaraları (tekrarsız, artan). Aralık dışı ya da bozuk parça hata.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [AllowEmptyString()] [string] $Text,
        [Parameter(Mandatory = $true)] [int] $Count
    )

    $set = New-Object 'System.Collections.Generic.SortedSet[int]'
    foreach ($part in ($Text -split '[\s,;]+')) {
        if (-not $part) { continue }
        if ($part -match '^(\d+)-(\d+)$') {
            $a = [int]$Matches[1]
            $b = [int]$Matches[2]
            if ($a -gt $b) { $tmp = $a; $a = $b; $b = $tmp }
            if ($a -lt 1 -or $b -gt $Count) { throw "Aralık dışı: $part (1-$Count)" }
            for ($i = $a; $i -le $b; $i++) { [void]$set.Add($i) }
        }
        elseif ($part -match '^\d+$') {
            $n = [int]$part
            if ($n -lt 1 -or $n -gt $Count) { throw "Aralık dışı: $part (1-$Count)" }
            [void]$set.Add($n)
        }
        else { throw "Anlaşılmadı: $part" }
    }
    $out = New-Object 'System.Collections.Generic.List[int]'
    foreach ($n in $set) { $out.Add($n) }
    return , $out.ToArray()
}

function Show-FaiMenuTweakList {
    <# .SYNOPSIS  Onay kutulu liste: '[x]  3. Başlık  (id)  Risk' risk rengiyle. #>
    param([object[]] $Tweaks, $Selected)

    for ($i = 0; $i -lt $Tweaks.Count; $i++) {
        $t = $Tweaks[$i]
        $box = '[ ]'
        if ($Selected.Contains([string]$t.Id)) { $box = '[x]' }
        $tags = @($t.Risk)
        if ($t.Tool) { $tags += 'araç' }
        if ($t.AlwaysConfirm) { $tags += 'her seferinde sorar' }
        Write-Host ('  {0} {1,2}. {2}  ({3})  {4}' -f $box, ($i + 1), $t.Title, $t.Id, ($tags -join ', ')) -ForegroundColor (Get-FaiRiskColor $t.Risk)
    }
}

function Invoke-FaiMenuChecklist {
    <#
    .SYNOPSIS
        Bir kategorinin onay kutulu listesi: numaralar seçimi tersine çevirir; 'h' hepsi, 'y' hiçbiri, Enter / 't' tamam.
        Selected (HashSet[string]) yerinde güncellenir.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [ExecutionContext] $Context,
        [Parameter(Mandatory = $true)] [string] $Title,
        [Parameter(Mandatory = $true)] [object[]] $Tweaks,
        [Parameter(Mandatory = $true)] $Selected
    )

    while ($true) {
        Write-Host ''
        Write-Host $Title -ForegroundColor White
        Show-FaiMenuTweakList -Tweaks $Tweaks -Selected $Selected
        $answer = ([string]$Context.Prompt.ReadLine('Numara(lar) seç / kaldır, h: hepsi, y: hiçbiri, Enter: tamam')).Trim().ToLowerInvariant()
        if ($answer -eq '' -or $answer -eq 't') { return }
        if ($answer -eq 'h') { foreach ($t in $Tweaks) { [void]$Selected.Add([string]$t.Id) }; continue }
        if ($answer -eq 'y') { foreach ($t in $Tweaks) { [void]$Selected.Remove([string]$t.Id) }; continue }
        try { $nums = ConvertFrom-FaiSelection -Text $answer -Count $Tweaks.Count }
        catch {
            Write-Host $_.Exception.Message -ForegroundColor Red
            continue
        }
        foreach ($n in $nums) {
            $id = [string]$Tweaks[$n - 1].Id
            if ($Selected.Contains($id)) { [void]$Selected.Remove($id) } else { [void]$Selected.Add($id) }
        }
    }
}

function Invoke-FaiMenuRun {
    <#
    .SYNOPSIS
        Ö: önizle (dry-run, sonra yine sorar) · U: uygula · G: geri. Uygulanırsa (ya da işlem yapılmazsa) döner.
        Action: bağlamı alıp Reporter döndüren betik bloğu. Kapanış (GetNewClosure) kullanılmaz: dinamik modül
        betik kapsamındaki fonksiyonları göremez; blok çağıranın değişkenlerini dinamik kapsamla bulur.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [ExecutionContext] $Context,
        [Parameter(Mandatory = $true)] [string] $Title,
        [Parameter(Mandatory = $true)] [scriptblock] $Action
    )

    while ($true) {
        $answer = ([string]$Context.Prompt.ReadLine(("{0} — Ö: önizle, U: uygula, G: geri" -f $Title))).Trim().ToLowerInvariant()
        if ($answer -eq 'ö' -or $answer -eq 'o') {
            $was = $Context.DryRun
            $Context.DryRun = $true
            try { Write-FaiReport -Report (& $Action $Context) }
            catch { Write-Host ('HATA: {0}' -f $_.Exception.Message) -ForegroundColor Red }
            finally { $Context.DryRun = $was }
            continue
        }
        if ($answer -eq 'u') {
            try { Write-FaiReport -Report (& $Action $Context) }
            catch { Write-Host ('HATA: {0}' -f $_.Exception.Message) -ForegroundColor Red }
            return
        }
        return
    }
}

function Invoke-FaiMenu {
    <#
    .SYNOPSIS
        Ana menü: 1 profil · 2 tweak seç ve çalıştır · 3 son oturumu geri al · 4 Windows Update · 5 araçlar · 0 çıkış.
        Çıkış kodu döndürür (0).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [ExecutionContext] $Context,
        [Parameter(Mandatory = $true)] [hashtable] $Catalog,
        [hashtable] $AppCatalog = @{}
    )

    $selected = New-Object 'System.Collections.Generic.HashSet[string]'
    $categories = Get-FaiMenuCategory -Catalog $Catalog
    $empty = 0
    while ($true) {
        Write-Host ''
        Write-Host 'FAI_WinOP — ana menü' -ForegroundColor White
        Write-Host '  1  Profil uygula'
        Write-Host ('  2  Tweak seç ve çalıştır (seçili: {0})' -f $selected.Count)
        Write-Host '  3  Son oturumu geri al'
        Write-Host '  4  Windows Update: duraklat / aç'
        Write-Host '  5  Araçlar'
        Write-Host '  0  Çıkış'
        $answer = ([string]$Context.Prompt.ReadLine('Seçim')).Trim().ToLowerInvariant()
        if ($answer -eq '') {
            $empty++
            if ($empty -ge 5) { Write-Host 'Girdi yok; çıkılıyor.'; return 0 }
            continue
        }
        $empty = 0
        switch ($answer) {
            '0' { return 0 }
            'q' { return 0 }
            '1' {
                $names = @(Get-FaiEmbeddedProfileName)
                Write-Host ''
                for ($i = 0; $i -lt $names.Count; $i++) { Write-Host ('  {0}  {1}' -f ($i + 1), $names[$i]) }
                Write-Host '  d  Dosya yolu ya da https URL gir'
                $pick = ([string]$Context.Prompt.ReadLine('Profil (Enter: geri)')).Trim()
                if (-not $pick) { break }
                $spec = ''
                if ($pick.ToLowerInvariant() -eq 'd') { $spec = ([string]$Context.Prompt.ReadLine('Yol / URL')).Trim() }
                elseif ($pick -match '^\d+$' -and [int]$pick -ge 1 -and [int]$pick -le $names.Count) { $spec = $names[[int]$pick - 1] }
                else { $spec = $pick }
                if (-not $spec) { break }
                try { $fp = Resolve-FaiProfile -Spec $spec }
                catch { Write-Host ('HATA: {0}' -f $_.Exception.Message) -ForegroundColor Red; break }
                Invoke-FaiMenuRun -Context $Context -Title ("Profil '{0}'" -f $fp.Name) -Action {
                    param($cx) Invoke-FaiEngine -FaiProfile $fp -Context $cx -Catalog $Catalog -AppCatalog $AppCatalog
                }
            }
            '2' {
                while ($true) {
                    Write-Host ''
                    Write-Host 'Kategoriler' -ForegroundColor White
                    for ($i = 0; $i -lt $categories.Count; $i++) {
                        $c = $categories[$i]
                        $n = @($c.Tweaks | Where-Object { $selected.Contains([string]$_.Id) }).Count
                        Write-Host ('  {0,2}  {1}  ({2}/{3})' -f ($i + 1), $c.Label, $n, $c.Tweaks.Count)
                    }
                    $pick = ([string]$Context.Prompt.ReadLine(('Kategori numarası, c: seçilenleri çalıştır ({0}), Enter: geri' -f $selected.Count))).Trim().ToLowerInvariant()
                    if ($pick -eq '') { break }
                    if ($pick -eq 'c') {
                        if ($selected.Count -eq 0) { Write-Host 'Seçili tweak yok.' -ForegroundColor Yellow; continue }
                        $ids = @($selected | Sort-Object)
                        $fp = New-FaiSelectionProfile -Ids $ids -Catalog $Catalog -AppCatalog $AppCatalog
                        Invoke-FaiMenuRun -Context $Context -Title ('{0} tweak' -f $ids.Count) -Action {
                            param($cx) Invoke-FaiEngine -FaiProfile $fp -Context $cx -Catalog $Catalog -AppCatalog $AppCatalog -AllowTools
                        }
                        continue
                    }
                    if ($pick -match '^\d+$' -and [int]$pick -ge 1 -and [int]$pick -le $categories.Count) {
                        $c = $categories[[int]$pick - 1]
                        Invoke-FaiMenuChecklist -Context $Context -Title $c.Label -Tweaks $c.Tweaks -Selected $selected
                        continue
                    }
                    Write-Host "Anlaşılmadı: $pick" -ForegroundColor Red
                }
            }
            '3' {
                if ($Context.Prompt.Confirm('Geri alınmamış son oturum geri alınacak.')) {
                    try { Write-FaiReport -Report (Invoke-FaiEngine -Undo -Context $Context -Catalog $Catalog -AppCatalog $AppCatalog) }
                    catch { Write-Host ('HATA: {0}' -f $_.Exception.Message) -ForegroundColor Red }
                }
            }
            '4' {
                $pick = ([string]$Context.Prompt.ReadLine('d: 365 gün duraklat, a: aç, Enter: geri')).Trim().ToLowerInvariant()
                if ($pick -eq 'd') { Invoke-FaiMenuRun -Context $Context -Title 'Güncellemeleri duraklat' -Action { param($cx) Invoke-FaiUpdatesSwitch -Context $cx -Off } }
                elseif ($pick -eq 'a') { Invoke-FaiMenuRun -Context $Context -Title 'Güncellemeleri aç' -Action { param($cx) Invoke-FaiUpdatesSwitch -Context $cx -On } }
            }
            '5' {
                $tools = @($Catalog.Values | Where-Object { $_.Tool } | Sort-Object Id)
                if ($tools.Count -eq 0) { Write-Host 'Araç yok.'; break }
                Write-Host ''
                for ($i = 0; $i -lt $tools.Count; $i++) {
                    Write-Host ('  {0}  {1}  ({2})' -f ($i + 1), $tools[$i].Title, $tools[$i].Id) -ForegroundColor (Get-FaiRiskColor $tools[$i].Risk)
                }
                $pick = ([string]$Context.Prompt.ReadLine('Araç numarası (Enter: geri)')).Trim()
                if (-not ($pick -match '^\d+$' -and [int]$pick -ge 1 -and [int]$pick -le $tools.Count)) { break }
                $fp = New-FaiSelectionProfile -Ids @([string]$tools[[int]$pick - 1].Id) -Catalog $Catalog -Name 'arac'
                Invoke-FaiMenuRun -Context $Context -Title $tools[[int]$pick - 1].Title -Action {
                    param($cx) Invoke-FaiEngine -FaiProfile $fp -Context $cx -Catalog $Catalog -AllowTools
                }
            }
            default { Write-Host "Anlaşılmadı: $answer" -ForegroundColor Red }
        }
    }
}
