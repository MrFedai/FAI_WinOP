# Snapshot deposu: her uygulama oturumu için bir JSON dosyası (<Root>\<oturum-kimliği>.json).
# Her kayıt (entry) bir eylemin tanımını ve uygulamadan ÖNCE alınan snapshot'ını tutar; -Undo bunlardan eylemi
# yeniden kurup ters sırada Revert çağırır. Oturum dosyası her kayıttan sonra diske yazılır (çökmeye dayanıklı).
# Yazım atomik: aynı klasörde <kimlik>.json.tmp yazılıp diske boşaltılır, sonra File.Replace / Move ile yer değiştirir
# (yarım yazılmış oturum dosyası kalmaz; Replace hedefin izinlerini korur, yeni dosya klasörün iznini devralır).
# Geri alma kayıt başına işaretlenir (kayıtta UndoneAt): başarısız kayıt oturumu kilitlemez, yeniden denemede yalnız
# kalanlar denenir. Atlanan (-SkipFailed) kayıtta UndoSkippedAt; oturum UndoneAt ile kapanır.

class BackupSession {
    [string] $Id
    [string] $Path
    [string] $ProfileName
    [string] $Created
    [string] $UndoneAt = ''
    # Bu nesnenin diske kaç kez yazıldığı (testler: eylem başına gereksiz ikinci tam yazım olmasın).
    [int] $SaveCount = 0
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
        $bytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes($json)
        $tmp = $this.Path + '.tmp'
        $fs = New-Object System.IO.FileStream($tmp, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try {
            $fs.Write($bytes, 0, $bytes.Length)
            # Yer değiştirmeden önce diske: güç kesilirse eski ya da yeni tam dosya kalır.
            $fs.Flush($true)
        }
        finally { $fs.Dispose() }
        # $null .NET string parametresine '' olarak geçer (Replace boş yolu reddeder): yedek dosyası yok = NullString.
        if ([System.IO.File]::Exists($this.Path)) { [System.IO.File]::Replace($tmp, $this.Path, [NullString]::Value) }
        else { [System.IO.File]::Move($tmp, $this.Path) }
        $this.SaveCount++
    }

    [void] MarkUndone() {
        $this.UndoneAt = (Get-Date).ToString('s')
        $this.Save()
    }

    # Kayıt geri alındı: hemen diske (yeniden denemede atlanır).
    [void] MarkEntryUndone([int] $Index) {
        $this.Entries[$Index]['UndoneAt'] = (Get-Date).ToString('s')
        $this.Save()
    }

    [bool] IsEntryUndone([int] $Index) { return [bool]$this.Entries[$Index]['UndoneAt'] }

    # Geri alınamayan kayıtlar atlanır ve oturum kapatılır (tek yazım).
    [void] CloseSkipping([int[]] $Indexes) {
        $now = (Get-Date).ToString('s')
        foreach ($i in $Indexes) { $this.Entries[$i]['UndoSkippedAt'] = $now }
        $this.UndoneAt = $now
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
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Backup session not found: $Id" }
        if ($null -ne $this.Security -and -not $this.Security.IsTrusted($path)) {
            throw "Backup session untrusted (owner is not SYSTEM / Administrators, or it is a link), not used: $path"
        }
        $data = $null
        try { $data = Read-JsonFile -Path $path }
        catch { throw "Backup session corrupt (unreadable): $path — $($_.Exception.Message)" }
        if ($data -isnot [hashtable] -or -not $data['Id']) { throw "Backup session corrupt (unreadable): $path" }
        return [BackupSession]::FromHashtable($data, $path)
    }

    # Geri alınmamış en son oturum; yoksa $null. Güvenilmeyen ya da bozuk (yarım yazılmış) oturum uyarıyla
    # (Warnings) atlanır, bir öncekine bakılır.
    [BackupSession] GetLatest() {
        $ids = $this.ListSessionIds()
        for ($i = $ids.Count - 1; $i -ge 0; $i--) {
            if ($null -ne $this.Security) {
                $path = Join-Path $this.Root ($ids[$i] + '.json')
                if (-not $this.Security.IsTrusted($path)) {
                    $this.Warnings.Add("untrusted backup session skipped (owner is not SYSTEM / Administrators, or it is a link): $path")
                    continue
                }
            }
            $s = $null
            try { $s = $this.Load($ids[$i]) }
            catch {
                $this.Warnings.Add("corrupt backup session skipped: $($_.Exception.Message)")
                continue
            }
            if (-not $s.IsUndone()) { return $s }
        }
        return $null
    }
}
