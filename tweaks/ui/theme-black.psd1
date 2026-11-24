@{
    Id          = 'ui.theme-black'
    Title       = 'Siyah tema (koyu, saydamlık kapalı, düz siyah duvar kağıdı)'
    Description = 'Uygulamalar ve Windows koyu kipe geçer, saydamlık efektleri kapanır. Vurgu rengi neredeyse siyah (#191919) yapılır ve Başlat / görev çubuğu ile pencere başlıklarında gösterilir; Ayarlar''daki açma / kapama düğmeleri okunur kalsın diye vurgu paletinin açık tonları gri bırakılır. Duvar kağıdı kaldırılır, masaüstü düz siyah renk olur (Kişiselleştir > Arka plan: Düz renk). Değişiklikler hemen yayınlanır; bazı uygulamalar yeniden açılınca koyulaşır.'
    Category    = 'ui'
    Risk        = 'Safe'
    Refresh     = @('Desktop', 'Settings')
    Actions     = @(
        # Koyu kip (uygulamalar + sistem), saydamlık kapalı, vurgu rengi Başlat / görev çubuğunda
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'AppsUseLightTheme'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'SystemUsesLightTheme'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'EnableTransparency'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'ColorPrevalence'; Value = 1; Kind = 'DWord' }
        # Vurgu paleti: 8 renk x RGBA; 0-2 açık tonlar gri (koyu kipte düğme / bağlantı), 3-7 koyu tonlar siyaha yakın
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'; Name = 'AccentPalette'; Kind = 'Binary'; Value = @(0x80, 0x80, 0x80, 0x00, 0x6B, 0x6B, 0x6B, 0x00, 0x55, 0x55, 0x55, 0x00, 0x19, 0x19, 0x19, 0x00, 0x11, 0x11, 0x11, 0x00, 0x0A, 0x0A, 0x0A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00) }
        # ABGR: 0xFF191919 vurgu, 0xFF111111 Başlat
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'; Name = 'AccentColorMenu'; Value = 4279834905; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'; Name = 'StartColorMenu'; Value = 4279308561; Kind = 'DWord' }
        # Pencere başlıkları ve kenarlıkları (DWM): 0xFF191919 / 0xC4191919
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\DWM'; Name = 'EnableWindowColorization'; Value = 1; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\DWM'; Name = 'AccentColor'; Value = 4279834905; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\DWM'; Name = 'ColorizationColor'; Value = 3289979161; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\DWM'; Name = 'ColorizationAfterglow'; Value = 3289979161; Kind = 'DWord' }
        # Düz siyah masaüstü: duvar kağıdı yok, arka plan türü düz renk (1), renk 0 0 0
        @{ Type = 'Registry'; Path = 'HKCU:\Control Panel\Desktop'; Name = 'WallPaper'; Value = ''; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKCU:\Control Panel\Colors'; Name = 'Background'; Value = '0 0 0'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers'; Name = 'BackgroundType'; Value = 1; Kind = 'DWord' }
    )
}
