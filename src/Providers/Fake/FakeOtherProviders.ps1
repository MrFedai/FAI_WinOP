# Kalan sahte sağlayıcılar: görev, Appx, paket, sistem bilgisi, soru. Yazma çağrıları sayılır.

class FakeTaskProvider : ITaskProvider {
    # küçük harf görev yolu → durum (Enabled | Disabled)
    [hashtable] $Tasks = @{}
    [int] $WriteCount = 0
    [System.Collections.ArrayList] $WriteLog = (New-Object System.Collections.ArrayList)

    FakeTaskProvider() { }

    [void] Seed([string] $TaskPath, [string] $State) { $this.Tasks[$TaskPath.ToLowerInvariant()] = $State }

    # Görev yoksa boş metin.
    [string] GetTaskState([string] $TaskPath) {
        $k = $TaskPath.ToLowerInvariant()
        if (-not $this.Tasks.ContainsKey($k)) { return '' }
        return [string]$this.Tasks[$k]
    }

    [void] SetTaskEnabled([string] $TaskPath, [bool] $Enabled) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("SetTaskEnabled $TaskPath $Enabled")
        $state = 'Disabled'
        if ($Enabled) { $state = 'Enabled' }
        $this.Tasks[$TaskPath.ToLowerInvariant()] = $state
    }

    # küçük harf görev yolu → @{ Execute; Arguments; Description } (yalnız kayıtlı ya da komutu tohumlanmış görevler)
    [hashtable] $Commands = @{}

    [hashtable] GetTaskAction([string] $TaskPath) {
        $k = $TaskPath.ToLowerInvariant()
        if (-not $this.Tasks.ContainsKey($k)) { return $null }
        if (-not $this.Commands.ContainsKey($k)) { return @{ Execute = ''; Arguments = '' } }
        return @{ Execute = [string]$this.Commands[$k]['Execute']; Arguments = [string]$this.Commands[$k]['Arguments'] }
    }

    [void] RegisterStartupTask([string] $TaskPath, [string] $Execute, [string] $Arguments, [string] $Description) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("RegisterStartupTask $TaskPath")
        $k = $TaskPath.ToLowerInvariant()
        $this.Tasks[$k] = 'Enabled'
        $this.Commands[$k] = @{ Execute = $Execute; Arguments = $Arguments; Description = $Description }
    }

    [void] UnregisterTask([string] $TaskPath) {
        $k = $TaskPath.ToLowerInvariant()
        if (-not $this.Tasks.ContainsKey($k)) { return }
        $this.WriteCount++
        [void]$this.WriteLog.Add("UnregisterTask $TaskPath")
        $this.Tasks.Remove($k)
        $this.Commands.Remove($k)
    }
}

class FakeAppxProvider : IAppxProvider {
    [System.Collections.ArrayList] $Installed = (New-Object System.Collections.ArrayList)
    [System.Collections.ArrayList] $Provisioned = (New-Object System.Collections.ArrayList)
    [int] $WriteCount = 0
    [System.Collections.ArrayList] $WriteLog = (New-Object System.Collections.ArrayList)

    FakeAppxProvider() { }

    [void] Seed([string[]] $InstalledNames, [string[]] $ProvisionedNames) {
        foreach ($n in $InstalledNames) { [void]$this.Installed.Add($n) }
        foreach ($n in $ProvisionedNames) { [void]$this.Provisioned.Add($n) }
    }

    [string[]] GetInstalled() { return [string[]]$this.Installed.ToArray() }

    [string[]] GetProvisioned() { return [string[]]$this.Provisioned.ToArray() }

    [void] RemoveInstalled([string] $Name) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("RemoveInstalled $Name")
        $this.Installed.Remove($Name)
    }

    [void] RemoveProvisioned([string] $Name) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("RemoveProvisioned $Name")
        $this.Provisioned.Remove($Name)
    }

    # Gerçek sağlayıcı gibi: yalnız provisioned kopyası duran paket geri kaydedilebilir.
    [void] RestoreInstalled([string] $Name) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("RestoreInstalled $Name")
        if (-not $this.Provisioned.Contains($Name)) { throw "Paketin makinede kopyası yok: $Name" }
        if (-not $this.Installed.Contains($Name)) { [void]$this.Installed.Add($Name) }
    }
}

class FakePackageProvider : IPackageProvider {
    # 'kaynak:kimlik' (küçük harf) kümesi
    [hashtable] $Packages = @{}
    [int] $WriteCount = 0
    [System.Collections.ArrayList] $WriteLog = (New-Object System.Collections.ArrayList)

    FakePackageProvider() { }

    static [string] Key([string] $PackageId, [string] $Source) { return ('{0}:{1}' -f $Source, $PackageId).ToLowerInvariant() }

    [void] Seed([string] $PackageId, [string] $Source) { $this.Packages[[FakePackageProvider]::Key($PackageId, $Source)] = $true }

    [bool] IsInstalled([string] $PackageId, [string] $Source) { return $this.Packages.ContainsKey([FakePackageProvider]::Key($PackageId, $Source)) }

    # 'kaynak:kimlik' → kurulumda / kaldırmada çağrılan betik bloğu (kurucunun kısayol / Run değeri bırakmasını,
    # kaldırıcının onları silmesini taklit eder).
    [hashtable] $OnInstall = @{}
    [hashtable] $OnUninstall = @{}

    [void] Install([string] $PackageId, [string] $Source) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("Install $Source $PackageId")
        $key = [FakePackageProvider]::Key($PackageId, $Source)
        $this.Packages[$key] = $true
        if ($this.OnInstall.ContainsKey($key)) { [void](& $this.OnInstall[$key]) }
    }

    [void] Uninstall([string] $PackageId, [string] $Source) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("Uninstall $Source $PackageId")
        $key = [FakePackageProvider]::Key($PackageId, $Source)
        $this.Packages.Remove($key)
        if ($this.OnUninstall.ContainsKey($key)) { [void](& $this.OnUninstall[$key]) }
    }

    [void] RunUninstaller([string] $PackageId, [string] $Source, [string] $FilePath, [string] $Arguments) {
        [void]$this.WriteLog.Add("RunUninstaller $Source $PackageId $FilePath $Arguments")
        $this.Uninstall($PackageId, $Source)
    }
}

# Salt okunur; alanlar testte doğrudan ayarlanır.
class FakeSystemInfoProvider : ISystemInfoProvider {
    [bool] $Laptop = $false
    [bool] $Nvidia = $false
    [bool] $Amd = $false
    [bool] $Intel = $false
    [string] $Edition = 'Pro'
    [int] $Build = 26100
    [double] $RamGB = 32

    FakeSystemInfoProvider() { }

    [bool] IsLaptop() { return $this.Laptop }
    [bool] HasNvidia() { return $this.Nvidia }
    [bool] HasAmdGpu() { return $this.Amd }
    [bool] HasIntelGpu() { return $this.Intel }
    [string] GetEdition() { return $this.Edition }
    [int] GetBuild() { return $this.Build }
    [double] GetRamGB() { return $this.RamGB }
}

# Önceden verilmiş yanıt listesiyle çalışır. Liste biterse güvenli varsayılan: reddet.
# Confirm: 'E' / 'Evet' / 'Y' / 'Yes' → evet. ConfirmExact: yanıt Expected ile birebir (büyük/küçük harf duyarlı) eşit olmalı.
class FakePromptProvider : IPromptProvider {
    [System.Collections.Queue] $Answers = (New-Object System.Collections.Queue)
    # Sorulan her soru: @{ Kind; Message; Answer }
    [System.Collections.ArrayList] $Asked = (New-Object System.Collections.ArrayList)

    FakePromptProvider() { }

    [void] Enqueue([string[]] $Replies) {
        foreach ($r in $Replies) { $this.Answers.Enqueue($r) }
    }

    hidden [string] Next() {
        if ($this.Answers.Count -eq 0) { return '' }
        return [string]$this.Answers.Dequeue()
    }

    [bool] Confirm([string] $Message) {
        $answer = $this.Next()
        [void]$this.Asked.Add(@{ Kind = 'Confirm'; Message = $Message; Answer = $answer })
        return (@('e', 'evet', 'y', 'yes') -contains $answer.Trim().ToLowerInvariant())
    }

    [bool] ConfirmExact([string] $Message, [string] $Expected) {
        $answer = $this.Next()
        [void]$this.Asked.Add(@{ Kind = 'ConfirmExact'; Message = $Message; Answer = $answer })
        return ($answer.Trim() -ceq $Expected)
    }
}

# Açılan URI'leri kaydeder.
class FakeShellProvider : IShellProvider {
    [int] $WriteCount = 0
    [System.Collections.ArrayList] $Opened = (New-Object System.Collections.ArrayList)
    # Doluysa OpenUri çağrıldığında çalışır (kullanıcının Ayarlar'da yaptığını taklit eder).
    [scriptblock] $OnOpen = $null

    FakeShellProvider() { }

    [void] OpenUri([string] $Uri) {
        $this.WriteCount++
        [void]$this.Opened.Add($Uri)
        if ($null -ne $this.OnOpen) { [void](& $this.OnOpen $Uri) }
    }
}

# Edge / WebView2: sürüm metinleri; kaldırma ve kurma yalnız sürümü değiştirir.
class FakeEdgeProvider : IEdgeProvider {
    [string] $EdgeVersion = ''
    [string] $WebView2Version = ''
    # $true: UninstallEdge hiçbir şey yapmaz (kaldırıcının başarısız olmasını taklit eder).
    [bool] $UninstallFails = $false
    [int] $WriteCount = 0
    [System.Collections.ArrayList] $WriteLog = (New-Object System.Collections.ArrayList)

    FakeEdgeProvider() { }

    [string] GetEdgeVersion() { return $this.EdgeVersion }
    [string] GetWebView2Version() { return $this.WebView2Version }

    [void] UninstallEdge() {
        $this.WriteCount++
        [void]$this.WriteLog.Add('UninstallEdge')
        if (-not $this.UninstallFails) { $this.EdgeVersion = '' }
    }

    [void] InstallEdge() {
        $this.WriteCount++
        [void]$this.WriteLog.Add('InstallEdge')
        $this.EdgeVersion = '999.0.0.0'
    }
}

# Kabuk yenilemelerini kaydeder. OnRefresh doluysa Refresh çağrısında çalışır (ör. Gezgin'in yeniden başlarken
# sabitleme düzenini uygulamasını taklit eder): & $OnRefresh <Kind>.
class FakeDesktopProvider : IDesktopProvider {
    [bool] $ShellRunning = $true
    [int] $WriteCount = 0
    [int] $WaitCount = 0
    [System.Collections.ArrayList] $Refreshed = (New-Object System.Collections.ArrayList)
    [scriptblock] $OnRefresh = $null

    FakeDesktopProvider() { }

    [bool] IsShellRunning() { return $this.ShellRunning }

    [void] Refresh([string] $Kind) {
        $this.WriteCount++
        [void]$this.Refreshed.Add($Kind)
        if ($null -ne $this.OnRefresh) { [void](& $this.OnRefresh $Kind) }
    }

    [void] Wait([int] $Milliseconds) { $this.WaitCount++ }
}

# Paket ayarları: paket → (küçük harf ad → @{ Name; Type; Data }).
class FakeAppSettingsProvider : IAppSettingsProvider {
    [hashtable] $Packages = @{}
    [int] $WriteCount = 0
    [System.Collections.ArrayList] $WriteLog = (New-Object System.Collections.ArrayList)

    FakeAppSettingsProvider() { }

    [void] SeedPackage([string] $Package) {
        if (-not $this.Packages.ContainsKey($Package.ToLowerInvariant())) { $this.Packages[$Package.ToLowerInvariant()] = @{} }
    }

    [void] Seed([string] $Package, [string] $Name, [int] $Type, [byte[]] $Data) {
        $this.SeedPackage($Package)
        $this.Packages[$Package.ToLowerInvariant()][$Name.ToLowerInvariant()] = @{ Name = $Name; Type = $Type; Data = $Data }
    }

    [bool] HasSettings([string] $Package) { return $this.Packages.ContainsKey($Package.ToLowerInvariant()) }

    [hashtable] GetValue([string] $Package, [string] $Name) {
        if (-not $this.HasSettings($Package)) { return $null }
        $v = $this.Packages[$Package.ToLowerInvariant()][$Name.ToLowerInvariant()]
        if ($null -eq $v) { return $null }
        return @{ Type = [int]$v['Type']; Data = [byte[]]$v['Data'] }
    }

    [void] SetValue([string] $Package, [string] $Name, [int] $Type, [byte[]] $Data) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("SetValue $Package $Name")
        if (-not $this.HasSettings($Package)) { throw "Paket ayar dosyası yok: $Package" }
        $this.Packages[$Package.ToLowerInvariant()][$Name.ToLowerInvariant()] = @{ Name = $Name; Type = $Type; Data = $Data }
    }

    [void] DeleteValue([string] $Package, [string] $Name) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("DeleteValue $Package $Name")
        if ($this.HasSettings($Package)) { $this.Packages[$Package.ToLowerInvariant()].Remove($Name.ToLowerInvariant()) }
    }
}
