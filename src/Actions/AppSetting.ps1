# AppSettingAction: paketli (Store) uygulamanın kendi ayarı (settings.dat, LocalState). Yalnız $Ctx.AppSettings üzerinden.
#
#   @{ Type='AppSetting'; Package='Microsoft.WindowsNotepad_8wekyb3d8bbwe'; Name='GhostFile'; Kind='Bool'; Value=$false }
#   @{ Type='AppSetting'; Package='...'; Key='PersistentSettings'; Name='...'; Kind='Bool'; Value=$false }  # LocalState altı
# Key (isteğe bağlı): LocalState'e göreli alt anahtar; sağlayıcıya ad 'Key\Name' olarak geçer.
# Kind: Bool (tür 0x5F5E10B, 1 bayt) | Int32 (tür 0x5F5E104, 4 bayt, küçük uçlu). Veri = yük + 8 bayt FILETIME (yazma anı);
# karşılaştırma yalnız türe ve yüke bakar. Uygulama açıksa yazarken kapatılır.
# Ayar dosyası yoksa (uygulama kurulu değil ya da hiç açılmamış) yapılacak iş sayılmaz: Test $true döner ve günlüğe yazılır;
# uygulama bir kez açıldıktan sonraki çalıştırmada uygulanır.
# Undo: eski tür + veri birebir geri yazılır; önceden yoksa değer silinir.

class AppSettingAction : ActionBase {
    AppSettingAction([hashtable] $Definition) : base($Definition) { }

    static [hashtable] Kinds() { return @{ Bool = 100000011; Int32 = 100000004 } }

    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        foreach ($m in (Get-FaiUnknownKeyError $Def @('Type', 'Package', 'Key', 'Name', 'Kind', 'Value'))) { $e.Add($m) }
        if (-not $Def.Contains('Package')) { $e.Add('Package: zorunlu alan eksik') }
        elseif ($Def['Package'] -isnot [string] -or $Def['Package'] -notmatch '^[A-Za-z0-9][A-Za-z0-9.\-]*_[a-z0-9]{13}$') { $e.Add('Package: paket ailesi adı olmalı (ör. Microsoft.WindowsNotepad_8wekyb3d8bbwe)') }
        if (-not $Def.Contains('Name')) { $e.Add('Name: zorunlu alan eksik') }
        elseif ($Def['Name'] -isnot [string] -or [string]::IsNullOrWhiteSpace($Def['Name']) -or $Def['Name'].Contains('\')) { $e.Add('Name: boş olmayan, ters bölüsüz metin olmalı') }
        if ($Def.Contains('Key')) {
            $k = $Def['Key']
            if ($k -isnot [string] -or [string]::IsNullOrWhiteSpace($k) -or $k.StartsWith('\') -or $k.EndsWith('\')) { $e.Add('Key: LocalState''e göreli anahtar yolu olmalı (ör. PersistentSettings)') }
        }
        $kind = $null
        if (-not $Def.Contains('Kind')) { $e.Add('Kind: zorunlu alan eksik') }
        elseif ($Def['Kind'] -isnot [string] -or -not [AppSettingAction]::Kinds().ContainsKey($Def['Kind'])) { $e.Add('Kind: Bool ya da Int32 olmalı') }
        else { $kind = $Def['Kind'] }
        if (-not $Def.Contains('Value')) { $e.Add('Value: zorunlu alan eksik') }
        elseif ($null -ne $kind -and -not (Test-FaiHasPlaceholder $Def['Value'])) {
            $v = $Def['Value']
            if ($kind -eq 'Bool' -and $v -isnot [bool]) { $e.Add('Value: Bool için $true / $false olmalı') }
            if ($kind -eq 'Int32' -and (-not (Test-FaiIsInteger $v) -or $v -lt [int]::MinValue -or $v -gt [int]::MaxValue)) { $e.Add('Value: Int32 için 32 bit tamsayı olmalı') }
        }
        return $e.ToArray()
    }

    [int] TypeCode() { return [int][AppSettingAction]::Kinds()[[string]$this.Definition['Kind']] }

    [byte[]] Payload() {
        if ([string]$this.Definition['Kind'] -eq 'Bool') {
            if ([bool]$this.Definition['Value']) { return [byte[]]@(1) }
            return [byte[]]@(0)
        }
        return [System.BitConverter]::GetBytes([int]$this.Definition['Value'])
    }

    static [bool] SamePayload([byte[]] $Data, [byte[]] $Payload) {
        if ($null -eq $Data -or $Data.Length -ne $Payload.Length + 8) { return $false }
        for ($i = 0; $i -lt $Payload.Length; $i++) { if ($Data[$i] -ne $Payload[$i]) { return $false } }
        return $true
    }

    [string] Package() { return [string]$this.Definition['Package'] }

    # Sağlayıcıya geçen ad: 'Key\Name' ya da yalnız Name (LocalState'te).
    [string] ValueName() {
        if ($this.Definition.ContainsKey('Key')) { return ('{0}\{1}' -f $this.Definition['Key'], $this.Definition['Name']) }
        return [string]$this.Definition['Name']
    }

    [bool] Test([ExecutionContext] $Ctx) {
        if (-not $Ctx.AppSettings.HasSettings($this.Package())) {
            $Ctx.Logger.Info(('{0}: ayar dosyası yok (uygulama kurulu değil ya da hiç açılmadı), atlanır' -f $this.Package()))
            return $true
        }
        $cur = $Ctx.AppSettings.GetValue($this.Package(), $this.ValueName())
        if ($null -eq $cur -or [int]$cur['Type'] -ne $this.TypeCode()) { return $false }
        return [AppSettingAction]::SamePayload([byte[]]$cur['Data'], $this.Payload())
    }

    [hashtable] Snapshot([ExecutionContext] $Ctx) {
        $cur = $Ctx.AppSettings.GetValue($this.Package(), $this.ValueName())
        if ($null -eq $cur) { return @{ Exists = $false } }
        return @{ Exists = $true; Type = [int]$cur['Type']; Data = [Convert]::ToBase64String([byte[]]$cur['Data']) }
    }

    [void] Apply([ExecutionContext] $Ctx) {
        $payload = $this.Payload()
        $stamp = [System.BitConverter]::GetBytes([DateTime]::UtcNow.ToFileTimeUtc())
        $data = New-Object byte[] ($payload.Length + 8)
        [System.Array]::Copy($payload, 0, $data, 0, $payload.Length)
        [System.Array]::Copy($stamp, 0, $data, $payload.Length, 8)
        $Ctx.AppSettings.SetValue($this.Package(), $this.ValueName(), $this.TypeCode(), $data)
    }

    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        $name = $this.ValueName()
        if ($Snapshot['Exists']) {
            $Ctx.AppSettings.SetValue($this.Package(), $name, [int]$Snapshot['Type'], [Convert]::FromBase64String([string]$Snapshot['Data']))
        }
        elseif ($null -ne $Ctx.AppSettings.GetValue($this.Package(), $name)) { $Ctx.AppSettings.DeleteValue($this.Package(), $name) }
    }

    [string] Describe() {
        return ('Uygulama ayarı: {0} {1} = {2} ({3})' -f $this.Package().Split('_')[0], $this.ValueName(), $this.Definition['Value'], $this.Definition['Kind'])
    }

    [string] Preview([ExecutionContext] $Ctx) {
        $now = 'yok'
        $cur = $Ctx.AppSettings.GetValue($this.Package(), $this.ValueName())
        if ($null -ne $cur) { $now = ([System.BitConverter]::ToString([byte[]]$cur['Data'])) }
        return ('{0} [şu an: {1}]' -f $this.Describe(), $now)
    }
}
