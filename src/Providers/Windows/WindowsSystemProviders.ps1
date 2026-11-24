# Gerçek sistem bilgisi (CIM + kayıt defteri; salt okunur, sonuçlar önbellekte) ve konsol sorusu (Read-Host).

class WindowsSystemInfoProvider : ISystemInfoProvider {
    hidden [object[]] $Gpus = $null
    hidden [string] $EditionCache = ''

    WindowsSystemInfoProvider() { }

    # Dizüstü / taşınabilir kasa türleri (SMBIOS): Portable, Laptop, Notebook, Hand Held, Docking Station, Sub Notebook,
    # Expansion Chassis değil; Convertible, Detachable, Tablet dahil.
    static [int[]] LaptopChassis() { return [int[]]@(8, 9, 10, 11, 12, 14, 30, 31, 32) }

    [bool] IsLaptop() {
        if (@(Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue).Count -gt 0) { return $true }
        foreach ($enc in @(Get-CimInstance -ClassName Win32_SystemEnclosure -ErrorAction SilentlyContinue)) {
            foreach ($c in @($enc.ChassisTypes)) { if ([WindowsSystemInfoProvider]::LaptopChassis() -contains [int]$c) { return $true } }
        }
        return $false
    }

    hidden [bool] HasGpu([string] $Pattern) {
        if ($null -eq $this.Gpus) { $this.Gpus = @(Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue) }
        foreach ($g in $this.Gpus) {
            if (('{0} {1}' -f $g.Name, $g.AdapterCompatibility) -match $Pattern) { return $true }
        }
        return $false
    }

    [bool] HasNvidia() { return $this.HasGpu('NVIDIA') }
    [bool] HasAmdGpu() { return $this.HasGpu('AMD|Advanced Micro Devices|Radeon') }
    [bool] HasIntelGpu() { return $this.HasGpu('Intel') }

    hidden [object] CurrentVersion([string] $Name) {
        $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)
        try {
            $k = $base.OpenSubKey('SOFTWARE\Microsoft\Windows NT\CurrentVersion')
            try { return $k.GetValue($Name) }
            finally { $k.Dispose() }
        }
        finally { $base.Dispose() }
    }

    # EditionID → sade ad: Core | Pro | Enterprise | Education | Server; tanınmayan olduğu gibi.
    [string] GetEdition() {
        if ($this.EditionCache) { return $this.EditionCache }
        $raw = [string]$this.CurrentVersion('EditionID')
        $name = $raw
        if ($raw -match '^Core') { $name = 'Core' }
        elseif ($raw -match '^Professional') { $name = 'Pro' }
        elseif ($raw -match '^Enterprise') { $name = 'Enterprise' }
        elseif ($raw -match '^Education') { $name = 'Education' }
        elseif ($raw -match '^Server') { $name = 'Server' }
        $this.EditionCache = $name
        return $name
    }

    [int] GetBuild() { return [int]$this.CurrentVersion('CurrentBuildNumber') }

    [double] GetRamGB() {
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        return [math]::Round([double]$cs.TotalPhysicalMemory / 1GB, 1)
    }

    [int] GetLogicalProcessorCount() {
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        return [int]$cs.NumberOfLogicalProcessors
    }

    [int] GetCoreCount() {
        $total = 0
        foreach ($cpu in @(Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop)) { $total += [int]$cpu.NumberOfCores }
        return $total
    }
}

# Sistem Geri Yükleme (Enable-ComputerRestore / Checkpoint-Computer, yalnız Windows PowerShell 5.1'de var) ve
# shutdown.exe. Windows varsayılanı 24 saatte bir nokta (SystemRestorePointCreationFrequency, dakika): oluştururken
# geçici olarak 0 yapılır, sonra eski hâline döner.
class WindowsSystemControlProvider : ISystemControlProvider {
    static [string] $RestoreKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'

    WindowsSystemControlProvider() { }

    static [string] SystemDrive() { return ($env:SystemDrive.TrimEnd('\') + '\') }

    [bool] IsRestoreEnabled() {
        # Sistem sürücüsünün birim kimliği SPP\Clients altındaki değerde geçiyorsa koruma açıktır.
        $clients = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SPP\Clients'
        $item = Get-ItemProperty -LiteralPath $clients -ErrorAction SilentlyContinue
        if ($null -eq $item) { return $false }
        $volume = Get-CimInstance -ClassName Win32_Volume -Filter ("DriveLetter='{0}'" -f $env:SystemDrive) -ErrorAction SilentlyContinue
        if ($null -eq $volume) { return $false }
        $id = [string]$volume.DeviceID
        foreach ($p in @($item.PSObject.Properties)) {
            if ($p.Name -like 'PS*') { continue }
            foreach ($v in @($p.Value)) { if ([string]$v -like ('*' + $id + '*')) { return $true } }
        }
        return $false
    }

    [void] EnableRestore() { Enable-ComputerRestore -Drive ([WindowsSystemControlProvider]::SystemDrive()) -ErrorAction Stop }

    [void] CreateRestorePoint([string] $Description) {
        $key = [WindowsSystemControlProvider]::RestoreKey
        $old = $null
        $item = Get-ItemProperty -LiteralPath $key -Name 'SystemRestorePointCreationFrequency' -ErrorAction SilentlyContinue
        if ($null -ne $item) { $old = $item.SystemRestorePointCreationFrequency }
        Set-ItemProperty -LiteralPath $key -Name 'SystemRestorePointCreationFrequency' -Value 0 -Type DWord -Force
        try { Checkpoint-Computer -Description $Description -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop }
        finally {
            if ($null -eq $old) { Remove-ItemProperty -LiteralPath $key -Name 'SystemRestorePointCreationFrequency' -ErrorAction SilentlyContinue }
            else { Set-ItemProperty -LiteralPath $key -Name 'SystemRestorePointCreationFrequency' -Value $old -Type DWord -Force }
        }
    }

    [void] RestartToFirmware([int] $DelaySeconds) {
        $exe = Join-Path $env:SystemRoot 'System32\shutdown.exe'
        $out = & $exe '/r' '/fw' '/t' ([string]$DelaySeconds) 2>&1
        if ($global:LASTEXITCODE -ne 0) { throw ('shutdown /r /fw başarısız ({0}): {1}' -f $global:LASTEXITCODE, ((@($out) -join ' ').Trim())) }
    }
}

class WindowsPromptProvider : IPromptProvider {
    WindowsPromptProvider() { }

    [bool] Confirm([string] $Message) {
        Write-Host ''
        Write-Host ('⚠ ' + $Message) -ForegroundColor Yellow
        $answer = [string](Read-Host 'Uygulansın mı? (E/H)')
        return (@('e', 'evet', 'y', 'yes') -contains $answer.Trim().ToLowerInvariant())
    }

    [bool] ConfirmExact([string] $Message, [string] $Expected) {
        Write-Host ''
        Write-Host ('‼ ' + $Message) -ForegroundColor Red
        $answer = [string](Read-Host ("Onaylamak için '{0}' yazın (başka her yanıt = hayır)" -f $Expected))
        return ($answer.Trim() -ceq $Expected)
    }
}
