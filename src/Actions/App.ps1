# AppAction: uygulamayı kurar (winget / msstore) ve kurulum sonrası düzeni uygular. Yalnız $Ctx sağlayıcılarıyla.
# Elle yazılmaz: apps/catalog.json → ConvertTo-FaiAppTweak üretir (src/Core/AppCatalog.ps1).
#
#   @{ Type='App'; Id='Spotify.Spotify'; Source='winget'
#      DisableStartup    = @('Spotify', 'Ollama.lnk')   # Run değeri ya da Başlangıç klasörü (.lnk) adları, -like kalıbı
#      DisableTasks      = @('\Vendor\Launcher')        # oturum açılışında uygulamayı başlatan zamanlanmış görevler
#      RemoveShortcuts   = @('Spotify.lnk')             # masaüstü kısayol adları (kullanıcı + ortak masaüstü)
#      CleanNewShortcuts = $true                        # kurulum sırasında masaüstüne eklenen her .lnk silinir
#      FlattenFolders    = @('Spotify')               # Başlat > Programlar altındaki klasör adları
#      UninstallPath     = '%ProgramFiles(x86)%\Steam\uninstall.exe'; UninstallArgs = '/S' }   # geri almada winget yerine
#
# UninstallPath: kaldırma kaydında sessiz komut olmayan kurucular için (winget onları argümansız başlatır, kaldırıcı
# görünmez onay penceresinde bekler: Steam). Geri alma bu komutu çalıştırır ve paket listeden düşene kadar bekler.
# Otomatik başlatma: Run değeri SİLİNMEZ. Görev Yöneticisi'nin "Devre dışı bırak"ı gibi StartupApproved altına kapalı
# işareti yazılır: uygulama Run değerini yeniden yazsa da kapalı kalır, kullanıcı Görev Yöneticisi'nden geri açabilir.
# Jokersiz adlar Run değeri henüz yokken de HKCU'da önceden kapatılır (ilk açılışta yazan Spotify / Discord gibi).
# Düzleştirme: klasördeki kısayollar Programlar köküne taşınır (kökte aynı ad varsa yalnız silinir), kaldırma
# kısayolları ve diğer dosyalar (.url) silinir, boş klasör silinir.
#
# Geri alma: Snapshot kurulum durumunu ve masaüstündeki .lnk listesini tutar. Apply her dosyaya / değere / göreve
# dokunmadan önce eski hâlini snapshot'ın günlüğüne (Journal) ekler; motor Apply'dan sonra oturumu yeniden kaydeder.
# Revert günlüğü ters sırada geri yazar, uygulama bu çalıştırmada kurulduysa kaldırır (kurucunun bıraktığı ve bizim
# sildiğimiz kısayollar geri yazılmaz; kaldırıcı zaten siler).

class AppAction : ActionBase {
    static [long] $MaxBackupBytes = 1MB
    static [byte[]] $DisabledMark = [byte[]]@(3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    static [string] $ApprovedBase = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'

    # Snapshot ile Apply arasında günlüğün tutulduğu snapshot (aynı nesne oturuma yazılır).
    hidden [hashtable] $Pending = $null

    AppAction([hashtable] $Definition) : base($Definition) { }

    static [string[]] ListFields() { return [string[]]@('DisableStartup', 'DisableTasks', 'RemoveShortcuts', 'FlattenFolders') }

    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        foreach ($m in (Get-FaiUnknownKeyError $Def (@('Type', 'Id', 'Source', 'CleanNewShortcuts', 'UninstallPath', 'UninstallArgs') + [AppAction]::ListFields()))) { $e.Add($m) }
        if (-not $Def.Contains('Id')) { $e.Add('Id: zorunlu alan eksik') }
        elseif ($Def['Id'] -isnot [string] -or $Def['Id'] -notmatch '^[A-Za-z0-9][A-Za-z0-9.\-_+]*$') {
            $e.Add('Id: paket kimliği olmalı (harf, rakam, . - _ +; boşluk yok)')
        }
        if ($Def.Contains('Source') -and ($Def['Source'] -isnot [string] -or @('winget', 'msstore') -cnotcontains $Def['Source'])) {
            $e.Add('Source: winget ya da msstore olmalı')
        }
        if ($Def.Contains('UninstallPath') -and -not (Test-FaiWindowsPath $Def['UninstallPath'])) { $e.Add('UninstallPath: mutlak yol olmalı (C:\..., %DEĞİŞKEN%\...)') }
        if ($Def.Contains('UninstallArgs')) {
            if ($Def['UninstallArgs'] -isnot [string]) { $e.Add('UninstallArgs: metin olmalı') }
            if (-not $Def.Contains('UninstallPath')) { $e.Add('UninstallArgs: UninstallPath olmadan verilmez') }
        }
        if ($Def.Contains('CleanNewShortcuts') -and $Def['CleanNewShortcuts'] -isnot [bool]) { $e.Add('CleanNewShortcuts: $true ya da $false olmalı') }
        foreach ($f in [AppAction]::ListFields()) {
            if (-not $Def.Contains($f)) { continue }
            $i = 0
            foreach ($item in @($Def[$f])) {
                $at = "${f}[$i]"
                $i++
                if ($item -isnot [string] -or [string]::IsNullOrWhiteSpace($item)) { $e.Add("${at}: boş olmayan metin olmalı"); continue }
                switch ($f) {
                    'DisableStartup' { if ($item.Contains('\')) { $e.Add("${at}: ad olmalı, yol değil ('\' yok)") } }
                    'DisableTasks' { if (-not $item.StartsWith('\')) { $e.Add("${at}: görev yolu '\' ile başlamalı") } }
                    'RemoveShortcuts' {
                        if ($item -notlike '*.lnk' -or $item -match '[\\/*?\[\]]') { $e.Add("${at}: joker ve yol içermeyen .lnk dosya adı olmalı") }
                    }
                    'FlattenFolders' {
                        if ($item -match '[\\/*?\[\]]' -or $item.Trim('.') -eq '') { $e.Add("${at}: joker ve yol içermeyen klasör adı olmalı") }
                    }
                }
            }
        }
        return $e.ToArray()
    }

    # --- tanımdan okunanlar ----------------------------------------------------------------------------------------
    [string] PackageId() { return [string]$this.Definition['Id'] }

    [string] SourceName() {
        if ($this.Definition.ContainsKey('Source')) { return [string]$this.Definition['Source'] }
        return 'winget'
    }

    [string[]] List([string] $Key) {
        if (-not $this.Definition.ContainsKey($Key)) { return [string[]]@() }
        return [string[]]@(@($this.Definition[$Key]) | Where-Object { $_ })
    }

    [bool] CleanNew() { return ($this.Definition.ContainsKey('CleanNewShortcuts') -and [bool]$this.Definition['CleanNewShortcuts']) }

    # --- yardımcılar (yollar Windows biçiminde; Join-Path Linux'ta '/' kullanır) ----------------------------------
    static [string] JoinPath([string] $Dir, [string] $Leaf) { return ($Dir.TrimEnd('\') + '\' + $Leaf) }

    static [string] Leaf([string] $Path) { return $Path.Substring($Path.LastIndexOf('\') + 1) }

    static [bool] MatchesAny([string] $Name, [string[]] $Patterns) {
        foreach ($p in $Patterns) { if ($Name -like $p) { return $true } }
        return $false
    }

    static [bool] HasWildcard([string] $Pattern) { return ($Pattern -match '[*?\[]') }

    # Düzleştirmede köke taşınacak mı (kaldırma kısayolu ve .lnk olmayanlar silinir).
    static [bool] KeepOnFlatten([string] $Leaf) {
        return ($Leaf -like '*.lnk' -and $Leaf -notmatch 'uninstall|kaldır')
    }

    # Run kaynakları ve StartupApproved karşılıkları.
    static [hashtable[]] RunSources() {
        $a = [AppAction]::ApprovedBase
        return [hashtable[]]@(
            @{ Run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Approved = "HKCU:\$a\Run" },
            @{ Run = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; Approved = "HKLM:\$a\Run" },
            @{ Run = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Approved = "HKLM:\$a\Run32" }
        )
    }

    static [hashtable[]] StartupFolders() {
        $a = [AppAction]::ApprovedBase
        return [hashtable[]]@(
            @{ Folder = 'Startup'; Approved = "HKCU:\$a\StartupFolder" },
            @{ Folder = 'CommonStartup'; Approved = "HKLM:\$a\StartupFolder" }
        )
    }

    hidden [void] AddTarget([System.Collections.Generic.List[hashtable]] $List, [hashtable] $Seen, [string] $Path, [string] $Name, [string] $Label) {
        $key = ('{0}|{1}' -f $Path, $Name).ToLowerInvariant()
        if ($Seen.ContainsKey($key)) { return }
        $Seen[$key] = $true
        $List.Add(@{ Path = $Path; Name = $Name; Label = $Label })
    }

    # Kapatılacak başlangıç öğeleri: @{ Path (StartupApproved anahtarı); Name; Label }.
    [hashtable[]] StartupTargets([ExecutionContext] $Ctx) {
        $patterns = $this.List('DisableStartup')
        $list = New-Object 'System.Collections.Generic.List[hashtable]'
        if ($patterns.Count -eq 0) { return $list.ToArray() }
        $seen = @{}
        $regPatterns = [string[]]@($patterns | Where-Object { $_ -notlike '*.lnk' })
        $lnkPatterns = [string[]]@($patterns | Where-Object { $_ -like '*.lnk' })
        foreach ($src in [AppAction]::RunSources()) {
            foreach ($name in $Ctx.Registry.GetValueNames([string]$src['Run'])) {
                if ([AppAction]::MatchesAny($name, $regPatterns)) { $this.AddTarget($list, $seen, [string]$src['Approved'], $name, "Run '$name'") }
            }
        }
        foreach ($sf in [AppAction]::StartupFolders()) {
            $dir = $Ctx.Files.GetKnownFolder([string]$sf['Folder'])
            if (-not $dir) { continue }
            foreach ($file in $Ctx.Files.ListFiles($dir)) {
                $leaf = [AppAction]::Leaf($file)
                if ([AppAction]::MatchesAny($leaf, $lnkPatterns)) { $this.AddTarget($list, $seen, [string]$sf['Approved'], $leaf, "Başlangıç klasörü '$leaf'") }
            }
        }
        # Önceden kapatma (yalnız jokersiz adlar, HKCU).
        $runApproved = [string]([AppAction]::RunSources()[0]['Approved'])
        $folderApproved = [string]([AppAction]::StartupFolders()[0]['Approved'])
        foreach ($p in $patterns) {
            if ([AppAction]::HasWildcard($p)) { continue }
            if ($p -like '*.lnk') { $this.AddTarget($list, $seen, $folderApproved, $p, "Başlangıç klasörü '$p'") }
            else { $this.AddTarget($list, $seen, $runApproved, $p, "Run '$p'") }
        }
        return $list.ToArray()
    }

    [bool] IsDisabled([ExecutionContext] $Ctx, [string] $Path, [string] $Name) {
        if ($Ctx.Registry.GetValueKind($Path, $Name) -ne 'Binary') { return $false }
        $bytes = [byte[]]@($Ctx.Registry.GetValue($Path, $Name))
        return ($bytes.Length -gt 0 -and ($bytes[0] -band 1) -eq 1)
    }

    [string[]] EnabledTasks([ExecutionContext] $Ctx) {
        return [string[]]@($this.List('DisableTasks') | Where-Object { $Ctx.Tasks.GetTaskState($_) -eq 'Enabled' })
    }

    [string[]] DesktopDirs([ExecutionContext] $Ctx) {
        return [string[]]@(@('DesktopDirectory', 'CommonDesktopDirectory') | ForEach-Object { $Ctx.Files.GetKnownFolder($_) } | Where-Object { $_ })
    }

    # Masaüstündeki bütün .lnk dosyaları.
    [string[]] DesktopLinks([ExecutionContext] $Ctx) {
        $list = New-Object 'System.Collections.Generic.List[string]'
        foreach ($dir in $this.DesktopDirs($Ctx)) {
            foreach ($f in $Ctx.Files.ListFiles($dir)) { if ($f -like '*.lnk') { $list.Add($f) } }
        }
        return $list.ToArray()
    }

    # Var olan, adı RemoveShortcuts'ta geçen masaüstü kısayolları.
    [string[]] KnownShortcuts([ExecutionContext] $Ctx) {
        $list = New-Object 'System.Collections.Generic.List[string]'
        foreach ($dir in $this.DesktopDirs($Ctx)) {
            foreach ($name in $this.List('RemoveShortcuts')) {
                $path = [AppAction]::JoinPath($dir, $name)
                if ($Ctx.Files.FileExists($path)) { $list.Add($path) }
            }
        }
        return $list.ToArray()
    }

    # Düzleştirilecek klasörler: @{ Root; Dir; Files }.
    [hashtable[]] FlattenTargets([ExecutionContext] $Ctx) {
        $list = New-Object 'System.Collections.Generic.List[hashtable]'
        foreach ($rootName in @('Programs', 'CommonPrograms')) {
            $root = $Ctx.Files.GetKnownFolder($rootName)
            if (-not $root) { continue }
            foreach ($folder in $this.List('FlattenFolders')) {
                $dir = [AppAction]::JoinPath($root, $folder)
                $files = $Ctx.Files.ListFiles($dir)
                if ($files.Count -gt 0) { $list.Add(@{ Root = $root; Dir = $dir; Files = $files }) }
            }
        }
        return $list.ToArray()
    }

    # --- günlük ----------------------------------------------------------------------------------------------------
    hidden [void] JournalValue([System.Collections.ArrayList] $Journal, [ExecutionContext] $Ctx, [string] $Path, [string] $Name) {
        $entry = @{ Kind = 'Value'; Path = $Path; Name = $Name; Existed = $false; ValueKind = ''; Data = $null }
        $kind = $Ctx.Registry.GetValueKind($Path, $Name)
        if ($kind) {
            $entry['Existed'] = $true
            $entry['ValueKind'] = $kind
            $value = $Ctx.Registry.GetValue($Path, $Name)
            if ($kind -eq 'Binary') { $entry['Data'] = [Convert]::ToBase64String([byte[]]@($value)) }
            else { $entry['Data'] = $value }
        }
        [void]$Journal.Add($entry)
    }

    hidden [void] JournalFile([System.Collections.ArrayList] $Journal, [ExecutionContext] $Ctx, [string] $Path, [bool] $AfterInstall) {
        $entry = @{ Kind = 'File'; Path = $Path; Existed = $false; Data = $null; AfterInstall = $AfterInstall }
        $size = $Ctx.Files.GetSize($Path)
        if ($size -ge 0) {
            if ($size -gt [AppAction]::MaxBackupBytes) { throw ("Dosya yedeklenemeyecek kadar büyük ({0} bayt): {1}" -f $size, $Path) }
            $entry['Existed'] = $true
            $entry['Data'] = [Convert]::ToBase64String($Ctx.Files.ReadBytes($Path))
        }
        [void]$Journal.Add($entry)
    }

    # --- ActionBase ------------------------------------------------------------------------------------------------
    [bool] IsInstalled([ExecutionContext] $Ctx) { return $Ctx.Packages.IsInstalled($this.PackageId(), $this.SourceName()) }

    [bool] Test([ExecutionContext] $Ctx) {
        if (-not $this.IsInstalled($Ctx)) { return $false }
        foreach ($t in $this.StartupTargets($Ctx)) { if (-not $this.IsDisabled($Ctx, [string]$t['Path'], [string]$t['Name'])) { return $false } }
        if ($this.EnabledTasks($Ctx).Count -gt 0) { return $false }
        if ($this.KnownShortcuts($Ctx).Count -gt 0) { return $false }
        if ($this.FlattenTargets($Ctx).Count -gt 0) { return $false }
        return $true
    }

    [hashtable] Snapshot([ExecutionContext] $Ctx) {
        $snap = @{
            Installed = $this.IsInstalled($Ctx)
            Desktop   = $this.DesktopLinks($Ctx)
            Journal   = (New-Object System.Collections.ArrayList)
        }
        $this.Pending = $snap
        return $snap
    }

    [void] Apply([ExecutionContext] $Ctx) {
        $snap = $this.Pending
        if ($null -eq $snap) { $snap = $this.Snapshot($Ctx) }
        $this.Pending = $null
        $journal = [System.Collections.ArrayList]$snap['Journal']

        $installedNow = $false
        if (-not $this.IsInstalled($Ctx)) {
            $Ctx.Packages.Install($this.PackageId(), $this.SourceName())
            $installedNow = $true
        }

        foreach ($t in $this.StartupTargets($Ctx)) {
            $path = [string]$t['Path']
            $name = [string]$t['Name']
            if ($this.IsDisabled($Ctx, $path, $name)) { continue }
            $this.JournalValue($journal, $Ctx, $path, $name)
            $Ctx.Registry.SetValue($path, $name, [AppAction]::DisabledMark, 'Binary')
        }

        foreach ($task in $this.EnabledTasks($Ctx)) {
            [void]$journal.Add(@{ Kind = 'Task'; Path = $task; State = 'Enabled' })
            $Ctx.Tasks.SetTaskEnabled($task, $false)
        }

        $remove = New-Object 'System.Collections.Generic.List[string]'
        foreach ($f in $this.KnownShortcuts($Ctx)) { $remove.Add($f) }
        if ($installedNow -and $this.CleanNew()) {
            $before = @{}
            foreach ($f in @($snap['Desktop'])) { if ($f) { $before[([string]$f).ToLowerInvariant()] = $true } }
            foreach ($f in $this.DesktopLinks($Ctx)) {
                if (-not $before.ContainsKey($f.ToLowerInvariant()) -and -not ($remove -contains $f)) { $remove.Add($f) }
            }
        }
        foreach ($f in $remove) {
            $this.JournalFile($journal, $Ctx, $f, $installedNow)
            $Ctx.Files.DeleteFile($f)
        }

        foreach ($target in $this.FlattenTargets($Ctx)) {
            foreach ($f in @($target['Files'])) {
                $leaf = [AppAction]::Leaf([string]$f)
                if ([AppAction]::KeepOnFlatten($leaf)) {
                    $dest = [AppAction]::JoinPath([string]$target['Root'], $leaf)
                    if (-not $Ctx.Files.FileExists($dest)) {
                        $this.JournalFile($journal, $Ctx, $dest, $installedNow)
                        $Ctx.Files.WriteBytes($dest, $Ctx.Files.ReadBytes([string]$f))
                    }
                }
                $this.JournalFile($journal, $Ctx, [string]$f, $installedNow)
                $Ctx.Files.DeleteFile([string]$f)
            }
            $Ctx.Files.DeleteEmptyDirectory([string]$target['Dir'])
        }
    }

    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        $was = [bool]$Snapshot['Installed']
        $journal = @($Snapshot['Journal'] | Where-Object { $null -ne $_ })
        for ($i = $journal.Count - 1; $i -ge 0; $i--) {
            $e = $journal[$i]
            switch ([string]$e['Kind']) {
                'Value' {
                    if ([bool]$e['Existed']) {
                        $kind = [string]$e['ValueKind']
                        $value = $e['Data']
                        if ($kind -eq 'Binary') { $value = [Convert]::FromBase64String([string]$e['Data']) }
                        $Ctx.Registry.SetValue([string]$e['Path'], [string]$e['Name'], (ConvertTo-FaiRegistryValue -Value $value -Kind $kind), $kind)
                    }
                    else { $Ctx.Registry.DeleteValue([string]$e['Path'], [string]$e['Name']) }
                }
                'Task' {
                    if ($Ctx.Tasks.GetTaskState([string]$e['Path'])) { $Ctx.Tasks.SetTaskEnabled([string]$e['Path'], ([string]$e['State'] -eq 'Enabled')) }
                }
                'File' {
                    if (-not [bool]$e['Existed']) { $Ctx.Files.DeleteFile([string]$e['Path']) }
                    elseif ($was -or -not [bool]$e['AfterInstall']) {
                        $Ctx.Files.WriteBytes([string]$e['Path'], [Convert]::FromBase64String([string]$e['Data']))
                    }
                }
            }
        }
        if (-not $was -and $this.IsInstalled($Ctx)) {
            if ($this.Definition.ContainsKey('UninstallPath')) {
                $args2 = ''
                if ($this.Definition.ContainsKey('UninstallArgs')) { $args2 = [string]$this.Definition['UninstallArgs'] }
                $Ctx.Packages.RunUninstaller($this.PackageId(), $this.SourceName(), (Expand-FaiPath ([string]$this.Definition['UninstallPath'])), $args2)
            }
            else { $Ctx.Packages.Uninstall($this.PackageId(), $this.SourceName()) }
        }
    }

    [string] Describe() {
        $parts = New-Object 'System.Collections.Generic.List[string]'
        $parts.Add(('Uygulama ({0}): {1} kurulu' -f $this.SourceName(), $this.PackageId()))
        $startup = @($this.List('DisableStartup')) + @($this.List('DisableTasks'))
        if ($startup.Count -gt 0) { $parts.Add('otomatik başlatma kapalı (' + ($startup -join ', ') + ')') }
        if ($this.List('RemoveShortcuts').Count -gt 0 -or $this.CleanNew()) { $parts.Add('masaüstü kısayolu yok') }
        if ($this.List('FlattenFolders').Count -gt 0) { $parts.Add('Başlat klasörü düzleştirilir (' + ($this.List('FlattenFolders') -join ', ') + ')') }
        return ($parts -join '; ')
    }

    [string] Preview([ExecutionContext] $Ctx) {
        if (-not $this.IsInstalled($Ctx)) { return ('{0} [şu an: kurulu değil → kurulur, ardından düzen uygulanır]' -f $this.Describe()) }
        $todo = New-Object 'System.Collections.Generic.List[string]'
        foreach ($t in $this.StartupTargets($Ctx)) {
            if (-not $this.IsDisabled($Ctx, [string]$t['Path'], [string]$t['Name'])) { $todo.Add('başlangıçta kapatılır: ' + $t['Label']) }
        }
        foreach ($task in $this.EnabledTasks($Ctx)) { $todo.Add('görev kapatılır: ' + $task) }
        foreach ($f in $this.KnownShortcuts($Ctx)) { $todo.Add('silinir: ' + $f) }
        foreach ($target in $this.FlattenTargets($Ctx)) { $todo.Add(('düzleştirilir: {0} ({1} dosya)' -f $target['Dir'], @($target['Files']).Count)) }
        return ('Uygulama ({0}): {1} [şu an: kurulu] → {2}' -f $this.SourceName(), $this.PackageId(), ($todo -join '; '))
    }
}
