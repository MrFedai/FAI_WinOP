@{
    Id          = 'setup.updates-staged'
    Title       = 'Windows Update: önce bekleyenleri kur, sonra duraklat'
    Description = 'Önce bekleyen bütün yazılım güncellemeleri (Windows Update Agent; sürücüler hariç) indirilip kurulur, ilerleme basılır. Kurulum yeniden başlatma isterse çalıştırma burada durur: yeniden başlatıp profili tekrar çalıştırın (CLI ResumeCommand verirse RunOnce ile kendiliğinden sürer); kalan güncellemeler ve duraklatma o çalıştırmada yapılır. Hiç bekleyen kalmayınca güncellemeler pauseDays (varsayılan 365) gün duraklatılır: Ayarlar > Windows Update''in duraklatma değerleri (UX\Settings, başlangıç / bitiş UTC). FlightSettingsMaxPauseDays yazılmaz; 365 günün Ayarlar''da nasıl göründüğü VM''de doğrulanacak. -UpdatesOn / -UpdatesOff ayrıca duraklatmayı kaldırır / yeniden koyar. -Undo duraklatmayı kaldırır; kurulan güncellemeler geri alınmaz. Güvenlik yamaları da duraklatılır; uzun duraklatma Insider yapısının süresini doldurabilir. Onay her çalıştırmada istenir.'
    Category    = 'setup'
    Risk        = 'Caution'
    AlwaysConfirm = $true
    Confirm     = 'Güvenlik yamaları dahil bütün güncellemeler 365 gün duraklatılır; uzun duraklatma Insider yapısının süresini doldurabilir.'
    Params      = @{ pauseDays = 365 }
    Actions     = @(
        @{ Type = 'WindowsUpdate' }
        @{ Type = 'UpdatePause'; Days = '{{pauseDays}}' }
    )
}
