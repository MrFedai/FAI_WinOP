# Tek seferlik sistem eylemleri: her çalıştırmada yeniden yapılırlar (Test her zaman $false) ve geri alınmazlar.
#
#   @{ Type='RestorePoint'; Description='FAI_WinOP' }                     # Sistem Geri Yükleme noktası ($Ctx.SystemControl)
#   @{ Type='Reboot'; Firmware=$true; Delay=10 }                          # UEFI ayarlarına yeniden başlat (araç tweak'i)
#   @{ Type='OpenSettings'; Uri='ms-settings:activation'; Message='...' } # yalnız kullanıcının yapabildiği adım ($Ctx.Shell)

class RestorePointAction : ActionBase {
    RestorePointAction([hashtable] $Definition) : base($Definition) { }

    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        foreach ($m in (Get-FaiUnknownKeyError $Def @('Type', 'Description'))) { $e.Add($m) }
        if (-not $Def.Contains('Description')) { $e.Add('Description: zorunlu alan eksik') }
        elseif (Test-FaiHasPlaceholder $Def['Description']) { }
        elseif ($Def['Description'] -isnot [string] -or [string]::IsNullOrWhiteSpace($Def['Description']) -or $Def['Description'].Length -gt 64) {
            $e.Add('Description: boş olmayan, en çok 64 karakterlik metin olmalı')
        }
        return $e.ToArray()
    }

    # Her çalıştırmada yeni nokta: hedef durum diye bir şey yok.
    [bool] Test([ExecutionContext] $Ctx) { return $false }

    [hashtable] Snapshot([ExecutionContext] $Ctx) { return @{} }

    [void] Apply([ExecutionContext] $Ctx) {
        if (-not $Ctx.SystemControl.IsRestoreEnabled()) {
            $Ctx.Logger.Info('Sistem Koruması kapalıydı: sistem sürücüsünde açılıyor')
            $Ctx.SystemControl.EnableRestore()
        }
        $Ctx.SystemControl.CreateRestorePoint([string]$this.Definition['Description'])
    }

    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        $Ctx.Logger.Info(("Geri yükleme noktası ('{0}') silinmez; gerekirse 'rstrui' ile ona dönülebilir." -f $this.Definition['Description']))
    }

    [string] Describe() { return ("Sistem Geri Yükleme noktası: '{0}'" -f $this.Definition['Description']) }

    [string] Preview([ExecutionContext] $Ctx) {
        $state = 'kapalı, açılacak'
        if ($Ctx.SystemControl.IsRestoreEnabled()) { $state = 'açık' }
        return ('{0} [Sistem Koruması: {1}]' -f $this.Describe(), $state)
    }
}

class RebootAction : ActionBase {
    RebootAction([hashtable] $Definition) : base($Definition) { }

    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        foreach ($m in (Get-FaiUnknownKeyError $Def @('Type', 'Firmware', 'Delay'))) { $e.Add($m) }
        # Şimdilik yalnız ürün yazılımına (BIOS / UEFI) yeniden başlatma.
        if (-not $Def.Contains('Firmware')) { $e.Add('Firmware: zorunlu alan eksik') }
        elseif ($Def['Firmware'] -isnot [bool] -or -not $Def['Firmware']) { $e.Add('Firmware: $true olmalı (yalnız UEFI ayarlarına yeniden başlatma desteklenir)') }
        if ($Def.Contains('Delay') -and -not (Test-FaiHasPlaceholder $Def['Delay'])) {
            $v = $Def['Delay']
            if (-not (Test-FaiIsInteger $v) -or $v -lt 0 -or $v -gt 600) { $e.Add('Delay: 0 ile 600 arası tamsayı (saniye) olmalı') }
        }
        return $e.ToArray()
    }

    [int] Delay() {
        if ($this.Definition.ContainsKey('Delay')) { return [int]$this.Definition['Delay'] }
        return 10
    }

    [bool] Test([ExecutionContext] $Ctx) { return $false }

    [hashtable] Snapshot([ExecutionContext] $Ctx) { return @{} }

    [void] Apply([ExecutionContext] $Ctx) {
        $Ctx.Logger.Warn(('{0} sn sonra UEFI (BIOS) ayarlarına yeniden başlatılıyor; vazgeçmek için: shutdown /a' -f $this.Delay()))
        $Ctx.SystemControl.RestartToFirmware($this.Delay())
    }

    # Yeniden başlatma geri alınamaz.
    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) { }

    [string] Describe() { return ('{0} sn sonra UEFI (BIOS) ayarlarına yeniden başlat' -f $this.Delay()) }
}

class OpenSettingsAction : ActionBase {
    OpenSettingsAction([hashtable] $Definition) : base($Definition) { }

    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        foreach ($m in (Get-FaiUnknownKeyError $Def @('Type', 'Uri', 'Message'))) { $e.Add($m) }
        if (-not $Def.Contains('Uri')) { $e.Add('Uri: zorunlu alan eksik') }
        elseif ($Def['Uri'] -isnot [string] -or $Def['Uri'] -notmatch '^ms-settings:[A-Za-z0-9\-_?=&%.]*$') { $e.Add('Uri: ms-settings: sayfası olmalı') }
        if (-not $Def.Contains('Message')) { $e.Add('Message: zorunlu alan eksik') }
        elseif ($Def['Message'] -isnot [string] -or [string]::IsNullOrWhiteSpace($Def['Message'])) { $e.Add('Message: boş olmayan metin olmalı') }
        return $e.ToArray()
    }

    # Sonucu programla denetlenemeyen kullanıcı adımı: tweak koşulu (ör. Edition=Core) sağlandıkça her çalıştırmada açılır.
    [bool] Test([ExecutionContext] $Ctx) { return $false }

    [hashtable] Snapshot([ExecutionContext] $Ctx) { return @{} }

    [void] Apply([ExecutionContext] $Ctx) {
        $msg = [string]$this.Definition['Message']
        if ($Ctx.Unattended) { throw "Etkileşim gerekir, etkileşimsiz kipte yapılamaz. $msg" }
        $Ctx.Shell.OpenUri([string]$this.Definition['Uri'])
        $Ctx.Logger.Info($msg)
    }

    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) { }

    [string] Describe() { return ("Ayarlar açılır ({0}): {1}" -f $this.Definition['Uri'], $this.Definition['Message']) }
}
