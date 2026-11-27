# RegistryAction: kayıt defteri değeri yazar ya da siler. Yalnız $Ctx.Registry (IRegistryProvider) üzerinden.
#
#   @{ Type='Registry'; Path='HKCU:\Software\...'; Name='Ad'; Value=1; Kind='DWord' }
#   @{ Type='Registry'; Path='HKCU:\Software\...'; Name='Ad'; Ensure='Absent' }          # değeri sil
# Kind: String | ExpandString | Binary | DWord | MultiString | QWord. Value '{{parametre}}' olabilir (Tweak.Params).
# Undo, uygulamadan önce var olmayan değeri siler; değer için oluşturulan anahtarlar (Snapshot.MissingFrom: ilk eksik
# üst anahtar) boş kaldıysa onları da aşağıdan yukarı siler. İçine başka değer yazılmış anahtara dokunulmaz.

class RegistryAction : ActionBase {
    RegistryAction([hashtable] $Definition) : base($Definition) { }

    static [string[]] Kinds() { return [string[]]@('String', 'ExpandString', 'Binary', 'DWord', 'MultiString', 'QWord') }

    # Şema hataları; her ileti '<alan>: <neden>' biçiminde (boşsa geçerli).
    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        $allowed = @('Type', 'Path', 'Name', 'Value', 'Kind', 'Ensure')
        foreach ($k in @($Def.Keys)) {
            if ($allowed -cnotcontains [string]$k) { $e.Add("${k}: bilinmeyen alan (izin verilenler: " + ($allowed -join ', ') + ')') }
        }
        if (-not $Def.Contains('Path')) { $e.Add('Path: zorunlu alan eksik') }
        elseif ($Def['Path'] -isnot [string] -or $Def['Path'] -notmatch '^(HKLM|HKCU|HKCR|HKU|HKCC):\\.+') {
            $e.Add('Path: ''HKLM:\...'' biçiminde olmalı (HKLM, HKCU, HKCR, HKU, HKCC)')
        }
        if (-not $Def.Contains('Name')) { $e.Add('Name: zorunlu alan eksik') }
        elseif ($Def['Name'] -isnot [string]) { $e.Add('Name: metin olmalı (boş metin = varsayılan değer)') }

        $ensure = 'Present'
        if ($Def.Contains('Ensure')) {
            if ($Def['Ensure'] -isnot [string] -or @('Present', 'Absent') -cnotcontains $Def['Ensure']) { $e.Add('Ensure: Present ya da Absent olmalı') }
            else { $ensure = $Def['Ensure'] }
        }
        if ($ensure -eq 'Absent') {
            if ($Def.Contains('Value')) { $e.Add('Value: Ensure=Absent iken verilmez') }
            if ($Def.Contains('Kind')) { $e.Add('Kind: Ensure=Absent iken verilmez') }
            return $e.ToArray()
        }

        $kind = $null
        if (-not $Def.Contains('Kind')) { $e.Add('Kind: zorunlu alan eksik') }
        elseif ($Def['Kind'] -isnot [string] -or [RegistryAction]::Kinds() -cnotcontains $Def['Kind']) {
            $e.Add('Kind: ' + ([RegistryAction]::Kinds() -join ', ') + ' değerlerinden biri olmalı')
        }
        else { $kind = $Def['Kind'] }

        if (-not $Def.Contains('Value')) { $e.Add('Value: zorunlu alan eksik') }
        elseif ($null -ne $kind -and @(Get-FaiPlaceholder -Value $Def['Value']).Count -eq 0) {
            $v = $Def['Value']
            switch ($kind) {
                'DWord' {
                    $ok = ($v -is [int] -or $v -is [long]) -and $v -ge -2147483648 -and $v -le 4294967295
                    if (-not $ok) { $e.Add('Value: DWord için 32 bit tamsayı olmalı') }
                }
                'QWord' { if (-not ($v -is [int] -or $v -is [long])) { $e.Add('Value: QWord için tamsayı olmalı') } }
                'String' { if ($v -isnot [string]) { $e.Add('Value: String için metin olmalı') } }
                'ExpandString' { if ($v -isnot [string]) { $e.Add('Value: ExpandString için metin olmalı') } }
                'MultiString' {
                    if (-not (Test-FaiIsList $v) -or @($v | Where-Object { $_ -isnot [string] }).Count -gt 0) { $e.Add('Value: MultiString için metin dizisi olmalı') }
                }
                'Binary' {
                    $bad = @($v | Where-Object { -not (($_ -is [int] -or $_ -is [long] -or $_ -is [byte]) -and $_ -ge 0 -and $_ -le 255) })
                    if (-not (Test-FaiIsList $v) -or $bad.Count -gt 0) { $e.Add('Value: Binary için 0-255 arası sayı dizisi olmalı') }
                }
            }
        }
        return $e.ToArray()
    }

    [bool] IsAbsent() { return ([string]$this.Definition['Ensure'] -eq 'Absent') }

    [string] Target() { return ('{0}\{1}' -f $this.Definition['Path'], $this.Definition['Name']) }

    [bool] Test([ExecutionContext] $Ctx) {
        $path = [string]$this.Definition['Path']
        $name = [string]$this.Definition['Name']
        $exists = $Ctx.Registry.ValueExists($path, $name)
        if ($this.IsAbsent()) { return (-not $exists) }
        if (-not $exists) { return $false }
        $kind = [string]$this.Definition['Kind']
        if ($Ctx.Registry.GetValueKind($path, $name) -ne $kind) { return $false }
        $want = ConvertTo-FaiRegistryValue -Value $this.Definition['Value'] -Kind $kind
        return (Test-FaiValueEqual -Left $Ctx.Registry.GetValue($path, $name) -Right $want)
    }

    [hashtable] Snapshot([ExecutionContext] $Ctx) {
        $path = [string]$this.Definition['Path']
        $name = [string]$this.Definition['Name']
        if (-not $Ctx.Registry.ValueExists($path, $name)) {
            $snap = @{ Exists = $false }
            if (-not $this.IsAbsent()) {
                $missing = [RegistryAction]::TopMissingKey($Ctx, $path)
                if ($missing) { $snap['MissingFrom'] = $missing }
            }
            return $snap
        }
        $kind = $Ctx.Registry.GetValueKind($path, $name)
        if ([RegistryAction]::Kinds() -cnotcontains $kind) {
            # REG_NONE / bilinmeyen tür: ham tür numarası + bayt (JSON'a yazılabilir int dizisi).
            $raw = $Ctx.Registry.GetRawValue($path, $name)
            if ($null -ne $raw) {
                return @{
                    Exists  = $true
                    Kind    = 'Raw'
                    RawType = [int]$raw['Type']
                    Bytes   = [int[]]@($raw['Bytes'] | ForEach-Object { [int]$_ })
                }
            }
        }
        return @{
            Exists = $true
            Value  = $Ctx.Registry.GetValue($path, $name)
            Kind   = $kind
        }
    }

    [void] Apply([ExecutionContext] $Ctx) {
        $path = [string]$this.Definition['Path']
        $name = [string]$this.Definition['Name']
        if ($this.IsAbsent()) {
            $Ctx.Registry.DeleteValue($path, $name)
            return
        }
        $kind = [string]$this.Definition['Kind']
        $value = ConvertTo-FaiRegistryValue -Value $this.Definition['Value'] -Kind $kind
        $Ctx.Registry.SetValue($path, $name, $value, $kind)
    }

    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        $path = [string]$this.Definition['Path']
        $name = [string]$this.Definition['Name']
        if ($Snapshot['Exists'] -and [string]$Snapshot['Kind'] -ceq 'Raw') {
            # Boş / null Bytes → 0 baytlık dizi (@($null) 1 baytlık 0 üretmesin).
            $src = @($Snapshot['Bytes'] | Where-Object { $null -ne $_ })
            $bytes = New-Object 'byte[]' $src.Count
            for ($i = 0; $i -lt $src.Count; $i++) { $bytes[$i] = [byte][int]$src[$i] }
            $Ctx.Registry.SetRawValue($path, $name, [int]$Snapshot['RawType'], $bytes)
        }
        elseif ($Snapshot['Exists']) {
            $kind = [string]$Snapshot['Kind']
            $value = ConvertTo-FaiRegistryValue -Value $Snapshot['Value'] -Kind $kind
            $Ctx.Registry.SetValue($path, $name, $value, $kind)
        }
        else {
            if ($Ctx.Registry.ValueExists($path, $name)) { $Ctx.Registry.DeleteValue($path, $name) }
            if ($Snapshot['MissingFrom']) { [RegistryAction]::RemoveCreatedKeys($Ctx, $path, [string]$Snapshot['MissingFrom']) }
        }
    }

    # Yoldaki ilk eksik anahtar ('HKLM:\A\B' eksikse 'HKLM:\A\B'); hepsi varsa boş metin. Salt okunur.
    static [string] TopMissingKey([ExecutionContext] $Ctx, [string] $Path) {
        $m = [regex]::Match($Path.TrimEnd('\'), '^([A-Za-z]+:)\\(.+)$')
        if (-not $m.Success) { return '' }
        $cur = $m.Groups[1].Value
        foreach ($part in ($m.Groups[2].Value -split '\\')) {
            $cur = $cur + '\' + $part
            if (-not $Ctx.Registry.KeyExists($cur)) { return $cur }
        }
        return ''
    }

    # Path'ten Top'a (dahil) yukarı doğru boş kalan anahtarları siler; dolu anahtarda durur.
    static [void] RemoveCreatedKeys([ExecutionContext] $Ctx, [string] $Path, [string] $Top) {
        $cur = $Path.TrimEnd('\')
        $topLen = $Top.TrimEnd('\').Length
        while ($cur.Length -ge $topLen) {
            if ($Ctx.Registry.KeyExists($cur)) {
                $Ctx.Registry.DeleteEmptyKey($cur)
                if ($Ctx.Registry.KeyExists($cur)) { return }
            }
            $i = $cur.LastIndexOf('\')
            if ($i -lt 0) { return }
            $cur = $cur.Substring(0, $i)
        }
    }

    [string] Describe() {
        if ($this.IsAbsent()) { return ('Kayıt defteri: {0} silinir' -f $this.Target()) }
        $v = $this.Definition['Value']
        $shown = (@($v) | ForEach-Object { [string]$_ }) -join ','
        return ('Kayıt defteri: {0} = {1} ({2})' -f $this.Target(), $shown, $this.Definition['Kind'])
    }

    [string] Preview([ExecutionContext] $Ctx) {
        $path = [string]$this.Definition['Path']
        $name = [string]$this.Definition['Name']
        $now = 'yok'
        if ($Ctx.Registry.ValueExists($path, $name)) {
            $now = (@($Ctx.Registry.GetValue($path, $name)) | ForEach-Object { [string]$_ }) -join ','
        }
        return ('{0} [şu an: {1}]' -f $this.Describe(), $now)
    }

    [string] PreviewRevert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        $path = [string]$this.Definition['Path']
        $name = [string]$this.Definition['Name']
        $now = 'yok'
        if ($Ctx.Registry.ValueExists($path, $name)) {
            $now = (@($Ctx.Registry.GetValue($path, $name)) | ForEach-Object { [string]$_ }) -join ','
        }
        $will = ''
        if (-not $Snapshot['Exists']) {
            $will = 'değer silinecek'
            if ($Snapshot['MissingFrom']) { $will += (', oluşturulan anahtar da silinecek (' + [string]$Snapshot['MissingFrom'] + ')') }
        }
        elseif ([string]$Snapshot['Kind'] -ceq 'Raw') {
            $will = 'ham tür {0}, {1} bayt geri yazılacak' -f $Snapshot['RawType'], @($Snapshot['Bytes']).Count
        }
        else {
            $will = 'değer {0} ({1}) geri yazılacak' -f ((@($Snapshot['Value']) | ForEach-Object { [string]$_ }) -join ','), $Snapshot['Kind']
        }
        return ('Kayıt defteri: {0} — şu an {1} → geri alınca {2}' -f $this.Target(), $now, $will)
    }
}

# RegistryEachAction: Path'in her doğrudan alt anahtarına aynı değeri yazar; Exclude kalıplarına (-like, büyük/küçük harf
# duyarsız) uyan alt anahtarlar atlanır. Örnek: bildirim gönderenlerinin hepsini kapat, istisna listesi hariç.
#
#   @{ Type='RegistryEach'; Path='HKCU:\Software\...\Notifications\Settings'; Name='Enabled'; Value=0; Kind='DWord'
#      Exclude=@('Windows.Defender*', '{{exceptions}}') }
# Exclude öğesi metin ya da (parametreden gelen) metin dizisi olabilir; düzleştirilir. Hedef, uygulama anında var olan alt
# anahtarlardır: yeni anahtar oluşturmaz, sonradan eklenen anahtar bir sonraki çalıştırmada yakalanır.
# Undo: snapshot'taki her alt anahtarın değeri eski haline döner (önceden yoksa silinir); arada silinmiş anahtar yeniden açılmaz.
# İsteğe bağlı süzgeçler (Faz 7; ör. ekran kartı sınıf anahtarı):
#   Include=@('[0-9][0-9][0-9][0-9]')                yalnız adı bu -like kalıplarından birine uyan alt anahtarlar
#   Match=@{ Name='ProviderName'; Like=@('NVIDIA*') } yalnız bu değeri kalıba uyan alt anahtarlar (değer yoksa hedef değil)
#   SubKey='UMD'                                     hedef <Path>\<alt>\<SubKey> (yalnız varsa; Match yine <alt>'ta bakılır)

class RegistryEachAction : ActionBase {
    RegistryEachAction([hashtable] $Definition) : base($Definition) { }

    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        foreach ($m in (Get-FaiUnknownKeyError $Def @('Type', 'Path', 'Name', 'Value', 'Kind', 'Exclude', 'Include', 'Match', 'SubKey'))) { $e.Add($m) }
        # Path / Name / Value / Kind kuralları RegistryAction ile aynı (Ensure yok: her zaman yazar).
        $core = @{ Type = 'Registry' }
        foreach ($k in @('Path', 'Name', 'Value', 'Kind')) { if ($Def.Contains($k)) { $core[$k] = $Def[$k] } }
        foreach ($m in [RegistryAction]::Validate($core)) { $e.Add($m) }
        if ($Def.Contains('Exclude') -and -not (Test-FaiHasPlaceholder $Def['Exclude'])) {
            # Parametre açılınca öğe metin dizisi olabilir: bir düzey düzleştirilir (Patterns ile aynı).
            $flat = @(foreach ($item in @($Def['Exclude'])) { foreach ($p in @($item)) { $p } })
            $bad = @($flat | Where-Object { $_ -isnot [string] -or [string]::IsNullOrWhiteSpace($_) })
            if (-not (Test-FaiIsList $Def['Exclude']) -or $bad.Count -gt 0) { $e.Add('Exclude: boş olmayan metin dizisi olmalı (-like kalıpları)') }
        }
        if ($Def.Contains('Include')) {
            $bad = @(@($Def['Include']) | Where-Object { $_ -isnot [string] -or [string]::IsNullOrWhiteSpace($_) })
            if (-not (Test-FaiIsList $Def['Include']) -or $bad.Count -gt 0) { $e.Add('Include: boş olmayan metin dizisi olmalı (-like kalıpları)') }
        }
        if ($Def.Contains('SubKey')) {
            $sk = $Def['SubKey']
            if ($sk -isnot [string] -or [string]::IsNullOrWhiteSpace($sk) -or $sk.StartsWith('\') -or $sk.EndsWith('\')) { $e.Add('SubKey: göreli anahtar yolu olmalı (ör. UMD)') }
        }
        if ($Def.Contains('Match')) {
            $mt = $Def['Match']
            if ($mt -isnot [System.Collections.IDictionary]) { $e.Add('Match: @{ Name=''değer adı''; Like=@(''kalıp'') } olmalı') }
            else {
                foreach ($m in (Get-FaiUnknownKeyError $mt @('Name', 'Like'))) { $e.Add('Match.' + $m) }
                if (-not $mt.Contains('Name') -or $mt['Name'] -isnot [string] -or [string]::IsNullOrWhiteSpace($mt['Name'])) { $e.Add('Match.Name: boş olmayan metin olmalı') }
                $like = @()
                if ($mt.Contains('Like')) { $like = @($mt['Like']) }
                $bad = @($like | Where-Object { $_ -isnot [string] -or [string]::IsNullOrWhiteSpace($_) })
                if ($like.Count -eq 0 -or $bad.Count -gt 0) { $e.Add('Match.Like: boş olmayan metin ya da metin dizisi olmalı (-like kalıpları)') }
            }
        }
        return $e.ToArray()
    }

    # Düzleştirilmiş Exclude kalıpları.
    [string[]] Patterns() {
        $out = New-Object 'System.Collections.Generic.List[string]'
        if (-not $this.Definition.ContainsKey('Exclude')) { return $out.ToArray() }
        foreach ($item in @($this.Definition['Exclude'])) {
            foreach ($p in @($item)) { if ($p -is [string] -and $p.Trim()) { $out.Add($p.Trim()) } }
        }
        return $out.ToArray()
    }

    [bool] IsExcluded([string] $KeyName) {
        foreach ($p in $this.Patterns()) { if ($KeyName -like $p) { return $true } }
        return $false
    }

    [bool] IsIncluded([string] $KeyName) {
        if (-not $this.Definition.ContainsKey('Include')) { return $true }
        foreach ($p in @($this.Definition['Include'])) { if ($KeyName -like [string]$p) { return $true } }
        return $false
    }

    # Alt anahtarın kendi yolu (Match buradan okunur).
    [string] ItemPath([string] $KeyName) { return ('{0}\{1}' -f ([string]$this.Definition['Path']).TrimEnd('\'), $KeyName) }

    # Değerin yazıldığı yol: alt anahtar ya da (SubKey varsa) onun altındaki anahtar.
    [string] KeyPath([string] $KeyName) {
        $p = $this.ItemPath($KeyName)
        if ($this.Definition.ContainsKey('SubKey')) { $p = '{0}\{1}' -f $p, ([string]$this.Definition['SubKey']) }
        return $p
    }

    [bool] IsMatch([ExecutionContext] $Ctx, [string] $KeyName) {
        if (-not $this.Definition.ContainsKey('Match')) { return $true }
        $mt = $this.Definition['Match']
        $p = $this.ItemPath($KeyName)
        $name = [string]$mt['Name']
        if (-not $Ctx.Registry.ValueExists($p, $name)) { return $false }
        $v = [string]$Ctx.Registry.GetValue($p, $name)
        foreach ($pat in @($mt['Like'])) { if ($v -like [string]$pat) { return $true } }
        return $false
    }

    # Süzgeçlerden (Include, Exclude, Match, SubKey varlığı) geçen alt anahtar adları (salt okunur).
    [string[]] Targets([ExecutionContext] $Ctx) {
        $out = New-Object 'System.Collections.Generic.List[string]'
        foreach ($n in @($Ctx.Registry.GetSubKeyNames([string]$this.Definition['Path']))) {
            if (-not $n -or $this.IsExcluded($n) -or -not $this.IsIncluded($n)) { continue }
            if (-not $this.IsMatch($Ctx, $n)) { continue }
            if ($this.Definition.ContainsKey('SubKey') -and -not $Ctx.Registry.KeyExists($this.KeyPath($n))) { continue }
            $out.Add($n)
        }
        return $out.ToArray()
    }

    # Değeri hedeften farklı olan alt anahtarlar (salt okunur).
    [string[]] Pending([ExecutionContext] $Ctx) {
        $name = [string]$this.Definition['Name']
        $kind = [string]$this.Definition['Kind']
        $want = ConvertTo-FaiRegistryValue -Value $this.Definition['Value'] -Kind $kind
        $out = New-Object 'System.Collections.Generic.List[string]'
        foreach ($k in $this.Targets($Ctx)) {
            $p = $this.KeyPath($k)
            $ok = $Ctx.Registry.ValueExists($p, $name) -and $Ctx.Registry.GetValueKind($p, $name) -eq $kind -and
            (Test-FaiValueEqual -Left $Ctx.Registry.GetValue($p, $name) -Right $want)
            if (-not $ok) { $out.Add($k) }
        }
        return $out.ToArray()
    }

    [bool] Test([ExecutionContext] $Ctx) { return (@($this.Pending($Ctx)).Count -eq 0) }

    [hashtable] Snapshot([ExecutionContext] $Ctx) {
        $name = [string]$this.Definition['Name']
        $entries = New-Object System.Collections.ArrayList
        foreach ($k in $this.Targets($Ctx)) {
            $p = $this.KeyPath($k)
            if ($Ctx.Registry.ValueExists($p, $name)) {
                $vk = $Ctx.Registry.GetValueKind($p, $name)
                $raw = $null
                if ([RegistryAction]::Kinds() -cnotcontains $vk) { $raw = $Ctx.Registry.GetRawValue($p, $name) }
                if ($null -ne $raw) {
                    [void]$entries.Add(@{ Key = $k; Exists = $true; Kind = 'Raw'; RawType = [int]$raw['Type']; Bytes = [int[]]@($raw['Bytes'] | ForEach-Object { [int]$_ }) })
                }
                else { [void]$entries.Add(@{ Key = $k; Exists = $true; Value = $Ctx.Registry.GetValue($p, $name); Kind = $vk }) }
            }
            else { [void]$entries.Add(@{ Key = $k; Exists = $false }) }
        }
        return @{ Keys = $entries.ToArray() }
    }

    [void] Apply([ExecutionContext] $Ctx) {
        $name = [string]$this.Definition['Name']
        $kind = [string]$this.Definition['Kind']
        $value = ConvertTo-FaiRegistryValue -Value $this.Definition['Value'] -Kind $kind
        foreach ($k in $this.Pending($Ctx)) { $Ctx.Registry.SetValue($this.KeyPath($k), $name, $value, $kind) }
    }

    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        $name = [string]$this.Definition['Name']
        foreach ($entry in @($Snapshot['Keys'])) {
            if ($null -eq $entry) { continue }
            $p = $this.KeyPath([string]$entry['Key'])
            if (-not $Ctx.Registry.KeyExists($p)) { continue }
            if ($entry['Exists'] -and [string]$entry['Kind'] -ceq 'Raw') {
                $src = @($entry['Bytes'] | Where-Object { $null -ne $_ })
                $rb = New-Object 'byte[]' $src.Count
                for ($i = 0; $i -lt $src.Count; $i++) { $rb[$i] = [byte][int]$src[$i] }
                $Ctx.Registry.SetRawValue($p, $name, [int]$entry['RawType'], $rb)
            }
            elseif ($entry['Exists']) {
                $kind = [string]$entry['Kind']
                $Ctx.Registry.SetValue($p, $name, (ConvertTo-FaiRegistryValue -Value $entry['Value'] -Kind $kind), $kind)
            }
            elseif ($Ctx.Registry.ValueExists($p, $name)) { $Ctx.Registry.DeleteValue($p, $name) }
        }
    }

    [string] Describe() {
        $v = (@($this.Definition['Value']) | ForEach-Object { [string]$_ }) -join ','
        $sub = ''
        if ($this.Definition.ContainsKey('SubKey')) { $sub = '\' + [string]$this.Definition['SubKey'] }
        $text = 'Kayıt defteri: {0}\*{1}\{2} = {3} ({4})' -f ([string]$this.Definition['Path']).TrimEnd('\'), $sub, $this.Definition['Name'], $v, $this.Definition['Kind']
        if ($this.Definition.ContainsKey('Include')) { $text += ' — yalnız: ' + (@($this.Definition['Include']) -join ', ') }
        if ($this.Definition.ContainsKey('Match')) { $text += (' — {0}: {1}' -f $this.Definition['Match']['Name'], (@($this.Definition['Match']['Like']) -join ' / ')) }
        $pats = $this.Patterns()
        if ($pats.Count -gt 0) { $text += ' — hariç: ' + ($pats -join ', ') }
        return $text
    }

    [string] Preview([ExecutionContext] $Ctx) {
        $pending = @($this.Pending($Ctx))
        $shown = @($pending | Select-Object -First 8)
        $list = $shown -join ', '
        if ($pending.Count -gt $shown.Count) { $list += (', … +{0}' -f ($pending.Count - $shown.Count)) }
        return ('{0} [değişecek {1} alt anahtar: {2}]' -f $this.Describe(), $pending.Count, $list)
    }

    [string] PreviewRevert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        $keys = @($Snapshot['Keys'] | Where-Object { $null -ne $_ })
        $del = @($keys | Where-Object { -not $_['Exists'] }).Count
        $write = $keys.Count - $del
        return ('Kayıt defteri: {0}\*\{1} — {2} anahtar; geri alınca {3} anahtara önceki değer yazılacak, {4} anahtarda değer silinecek' -f ([string]$this.Definition['Path']).TrimEnd('\'), $this.Definition['Name'], $keys.Count, $write, $del)
    }
}
