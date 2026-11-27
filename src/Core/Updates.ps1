# Windows Update duraklatma yardımcıları (setup.updates-staged, -UpdatesOn / -UpdatesOff).
#
# Duraklatma Ayarlar > Windows Update'in yazdığı değerlerle yapılır (HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings):
# başlangıç = şimdi, bitiş = şimdi + gün; zaman UTC 'yyyy-MM-ddTHH:mm:ssZ'. Zaman tek kaynaktan gelir ([FaiClock]):
# testler Fixed ile sabitler.

class FaiClock {
    # $null değilse UtcNow bunu döndürür (yalnız testler).
    static [object] $Fixed = $null

    static [datetime] UtcNow() {
        if ($null -ne [FaiClock]::Fixed) { return ([datetime][FaiClock]::Fixed).ToUniversalTime() }
        return [datetime]::UtcNow
    }

    static [string] Format([datetime] $Utc) {
        return $Utc.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ', [System.Globalization.CultureInfo]::InvariantCulture)
    }

    # Biçim tanınmazsa $null.
    static [object] Parse([string] $Text) {
        $styles = [System.Globalization.DateTimeStyles]::AdjustToUniversal -bor [System.Globalization.DateTimeStyles]::AssumeUniversal
        $out = [datetime]::MinValue
        if ([datetime]::TryParse($Text, [System.Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$out)) { return $out }
        return $null
    }
}

function Get-FaiUpdatePauseKey { return 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' }

function Get-FaiUpdatePauseName {
    <# .SYNOPSIS  Duraklatma değerleri: ad → 'Start' | 'End' (başlangıç = şimdi, bitiş = şimdi + gün). #>
    return [ordered]@{
        PauseUpdatesStartTime        = 'Start'
        PauseUpdatesExpiryTime       = 'End'
        PauseFeatureUpdatesStartTime = 'Start'
        PauseFeatureUpdatesEndTime   = 'End'
        PauseQualityUpdatesStartTime = 'Start'
        PauseQualityUpdatesEndTime   = 'End'
    }
}

function ConvertTo-FaiUpdatesSwitchTweak {
    <#
    .SYNOPSIS
        -UpdatesOn / -UpdatesOff için kod içinde üretilen tweak: 'updates.on' (duraklatma kalkar, güncellemeler sürer) ya
        da 'updates.off' (Days gün duraklatılır). Motor üzerinden çalışır: yedek oturumu, rapor ve -Undo aynı.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'On')] [switch] $On,
        [Parameter(Mandatory = $true, ParameterSetName = 'Off')] [switch] $Off,
        [Parameter(ParameterSetName = 'Off')] [int] $Days = 365
    )

    if ($On.IsPresent -and -not $Off.IsPresent) {
        $data = @{
            Id = 'updates.on'; Title = 'Windows Update: resume'; Category = 'updates'; Risk = 'Safe'
            Description = 'Removes the Settings > Windows Update pause values; updates resume (-UpdatesOn).'
            Actions = @(@{ Type = 'UpdatePause'; Ensure = 'Absent' })
        }
    }
    else {
        $data = @{
            Id = 'updates.off'; Title = ('Windows Update: pause for {0} days' -f $Days); Category = 'updates'; Risk = 'Safe'
            Description = 'Pauses Settings > Windows Update (-UpdatesOff); pending updates are not installed.'
            Actions = @(@{ Type = 'UpdatePause'; Days = $Days })
        }
    }
    return [Tweak]::FromHashtable($data, $data['Id'])
}
