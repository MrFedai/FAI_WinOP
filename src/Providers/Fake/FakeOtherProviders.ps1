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
