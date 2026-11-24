@{
    Id          = 'refresh.reboot-to-bios'
    Title       = 'UEFI (BIOS) ayarlarına yeniden başlat'
    Description = 'Araç: bilgisayarı birkaç saniye sonra doğrudan UEFI ürün yazılımı ayarlarına yeniden başlatır (shutdown /r /fw). Profille otomatik çalışmaz; yalnız menüden ya da -Only ile, onayla. Açık belgeleri kaydedin. Vazgeçmek için süre dolmadan: shutdown /a. Eski (Legacy BIOS) kurulumlarda desteklenmez.'
    Category    = 'refresh'
    Risk        = 'Caution'
    Tool        = $true
    Confirm     = 'Bilgisayar birkaç saniye içinde yeniden başlayacak; kaydedilmemiş işler kaybolur.'
    Params      = @{ delay = 10 }
    Actions     = @(
        @{ Type = 'Reboot'; Firmware = $true; Delay = '{{delay}}' }
    )
}
