# Snapshot deposu: her uygulama oturumu için bir JSON dosyası (<Root>\<oturum-kimliği>.json).
# Her kayıt (entry) bir eylemin tanımını ve uygulamadan ÖNCE alınan snapshot'ını tutar; -Undo bunlardan eylemi
# yeniden kurup ters sırada Revert çağırır. Oturum dosyası her kayıttan sonra diske yazılır (çökmeye dayanıklı).

class BackupSession {
    [string] $Id
    [string] $Path
    [string] $ProfileName
    [string] $Created
    [string] $UndoneAt = ''
    [System.Collections.ArrayList] $Entries = (New-Object System.Collections.ArrayList)

    BackupSession() { }

    # Eylemin tanımı + snapshot'ı eklenir ve oturum diske yazılır. Uygulamadan ÖNCE çağrılır.
    [void] AddEntry([string] $TweakId, [int] $ActionIndex, [hashtable] $ActionDefinition, [hashtable] $Snapshot) {
        $this.AddEntry($TweakId, $ActionIndex, $ActionDefinition, $Snapshot, [string[]]@())
    }

    # Refresh: geri almadan sonra gereken kabuk yenilemeleri (tweak'in Refresh listesi).
    [void] AddEntry([string] $TweakId, [int] $ActionIndex, [hashtable] $ActionDefinition, [hashtable] $Snapshot, [string[]] $Refresh) {
        [void]$this.Entries.Add(@{
                TweakId     = $TweakId
                ActionIndex = $ActionIndex
                Action      = $ActionDefinition
                Snapshot    = $Snapshot
                Refresh     = $Refresh
            })
        $this.Save()
    }

    [hashtable] ToHashtable() {
        return @{
            Id          = $this.Id
            ProfileName = $this.ProfileName
            Created     = $this.Created
            UndoneAt    = $this.UndoneAt
            Entries     = $this.Entries.ToArray()
        }
    }

    [void] Save() {
        $dir = Split-Path -Parent $this.Path
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $json = $this.ToHashtable() | ConvertTo-Json -Depth 20
        [System.IO.File]::WriteAllText($this.Path, $json, (New-Object System.Text.UTF8Encoding($false)))
    }

    [void] MarkUndone() {
        $this.UndoneAt = (Get-Date).ToString('s')
        $this.Save()
    }

    [bool] IsUndone() { return [bool]$this.UndoneAt }

    static [BackupSession] FromHashtable([hashtable] $Data, [string] $Path) {
        $s = [BackupSession]::new()
        $s.Path = $Path
        $s.Id = [string]$Data['Id']
        $s.ProfileName = [string]$Data['ProfileName']
        $s.Created = [string]$Data['Created']
        $s.UndoneAt = [string]$Data['UndoneAt']
        foreach ($e in @($Data['Entries'])) { [void]$s.Entries.Add($e) }
        return $s
    }
}

class BackupStore {
    [string] $Root
    # Kaç oturum açıldı (dry-run'da 0 olmalı; testler bunu doğrular).
    [int] $SessionsOpened = 0
    # Verilirse oturum dosyası okunmadan önce denetlenir: bağlantıysa ya da sahibi SYSTEM / Administrators değilse
    # kullanılmaz (yönetici olmayan kullanıcının bıraktığı eylem tanımı -Undo'da yönetici olarak çalışırdı).
    [IFileSecurityProvider] $Security
    # Atlanan güvenilmeyen oturumlar (GetLatest); motor günlüğe yazar.
    [System.Collections.Generic.List[string]] $Warnings = (New-Object 'System.Collections.Generic.List[string]')

    BackupStore([string] $Root) { $this.Root = $Root }

    [BackupSession] BeginSession([string] $ProfileName) {
        $this.SessionsOpened++
        $now = Get-Date
        $stamp = $now.ToString('yyyyMMdd-HHmmss-fff')
        $seq = 0
        $id = '{0}-{1:00}' -f $stamp, $seq
        while (Test-Path -LiteralPath (Join-Path $this.Root ($id + '.json'))) {
            $seq++
            $id = '{0}-{1:00}' -f $stamp, $seq
        }
        $s = [BackupSession]::new()
        $s.Id = $id
        $s.Path = Join-Path $this.Root ($id + '.json')
        $s.ProfileName = $ProfileName
        $s.Created = $now.ToString('s')
        # Kimlik hemen rezerve edilsin (aynı milisaniyede ikinci oturum çakışmasın).
        $s.Save()
        return $s
    }

    # Oturum kimlikleri, eskiden yeniye.
    [string[]] ListSessionIds() {
        if (-not (Test-Path -LiteralPath $this.Root -PathType Container)) { return [string[]]@() }
        $names = [string[]]@(Get-ChildItem -LiteralPath $this.Root -Filter '*.json' -File | ForEach-Object { $_.BaseName })
        [System.Array]::Sort($names, [System.StringComparer]::Ordinal)
        return $names
    }

    [BackupSession] Load([string] $Id) {
        $path = Join-Path $this.Root ($Id + '.json')
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Yedek oturumu yok: $Id" }
        if ($null -ne $this.Security -and -not $this.Security.IsTrusted($path)) {
            throw "Yedek oturumu güvenilmez (sahibi SYSTEM / Administrators değil ya da bağlantı), kullanılmadı: $path"
        }
        $data = Read-JsonFile -Path $path
        return [BackupSession]::FromHashtable($data, $path)
    }

    # Geri alınmamış en son oturum; yoksa $null.
    [BackupSession] GetLatest() {
        $ids = $this.ListSessionIds()
        for ($i = $ids.Count - 1; $i -ge 0; $i--) {
            if ($null -ne $this.Security) {
                $path = Join-Path $this.Root ($ids[$i] + '.json')
                if (-not $this.Security.IsTrusted($path)) {
                    $this.Warnings.Add("güvenilmeyen yedek oturumu atlandı (sahibi SYSTEM / Administrators değil ya da bağlantı): $path")
                    continue
                }
            }
            $s = $this.Load($ids[$i])
            if (-not $s.IsUndone()) { return $s }
        }
        return $null
    }
}
