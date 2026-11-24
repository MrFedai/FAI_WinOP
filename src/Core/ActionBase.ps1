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
}
