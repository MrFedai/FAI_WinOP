# Eylem taban sınıfı (soyut). Somut eylemler src/Actions/ altında; hepsi Windows'a yalnız $Ctx sağlayıcılarıyla dokunur.
#
#   Test      → hedef durum zaten sağlanıyor mu (salt okunur)
#   Snapshot  → uygulamadan ÖNCE mevcut durumu yakalar (salt okunur); JSON'a yazılabilir hashtable döner
#   Apply     → hedef durumu uygular (YAZMA)
#   Revert    → Snapshot'taki duruma birebir geri döner (YAZMA); snapshot'ta olmayan değer silinir
#   Describe  → eylemin ne yaptığı (tek satır, Türkçe)
#   Preview   → Describe + şu anki durum (dry-run raporu için, salt okunur)

class ActionBase {
    [string] $Type
    [hashtable] $Definition
    # Eylem düzeyi koşul (tanımda 'When'; New-FaiAction bağlar). Sağlanmazsa motor eylemi bu makinede atlar.
    [Condition] $When = $null

    ActionBase() { }

    ActionBase([hashtable] $Definition) {
        $this.Definition = $Definition
        $this.Type = [string]$Definition['Type']
    }

    [bool] Test([ExecutionContext] $Ctx) { throw [System.NotImplementedException]::new('ActionBase.Test') }
    [hashtable] Snapshot([ExecutionContext] $Ctx) { throw [System.NotImplementedException]::new('ActionBase.Snapshot') }
    [void] Apply([ExecutionContext] $Ctx) { throw [System.NotImplementedException]::new('ActionBase.Apply') }
    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) { throw [System.NotImplementedException]::new('ActionBase.Revert') }
    [string] Describe() { throw [System.NotImplementedException]::new('ActionBase.Describe') }

    [string] Preview([ExecutionContext] $Ctx) { return $this.Describe() }

    # Geri alma önizlemesi (salt okunur): snapshot'taki önceki duruma dönülünce ne olacağı. Varsayılan genel;
    # türler şu an → geri alınca biçiminde ezer.
    [string] PreviewRevert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        return ('geri alınacak: {0} → önceki duruma [{1}]' -f $this.Describe(), [ActionBase]::SnapshotSummary($Snapshot))
    }

    # Snapshot'ın kısa özeti: anahtar=değer, en çok 120 karakter; uzun dizi / bayt kısaltılır.
    static [string] SnapshotSummary([hashtable] $Snapshot) {
        if ($null -eq $Snapshot -or $Snapshot.Count -eq 0) { return 'boş' }
        $parts = New-Object 'System.Collections.Generic.List[string]'
        foreach ($k in @($Snapshot.Keys | Sort-Object)) {
            $v = $Snapshot[$k]
            $txt = ''
            if ($null -eq $v) { $txt = 'null' }
            elseif ($v -is [hashtable]) { $txt = '{…}' }
            elseif ($v -is [System.Array]) {
                $items = @($v)
                $shown = @($items | Select-Object -First 4 | ForEach-Object { [string]$_ })
                $txt = '[' + ($shown -join ',')
                if ($items.Count -gt $shown.Count) { $txt += (',… {0} öğe' -f $items.Count) }
                $txt += ']'
            }
            else { $txt = [string]$v }
            if ($txt.Length -gt 40) { $txt = $txt.Substring(0, 37) + '...' }
            $parts.Add(('{0}={1}' -f $k, $txt))
        }
        $all = $parts -join ', '
        if ($all.Length -gt 120) { $all = $all.Substring(0, 117) + '...' }
        return $all
    }

    # When yoksa ya da sağlanıyorsa $true (salt okunur).
    [bool] Applies([ISystemInfoProvider] $Sys) {
        if ($null -eq $this.When) { return $true }
        return $this.When.Test($Sys)
    }
}
