@{
    Id          = 'ui.theme-black'
    Title       = 'Siyah tema (koyu, saydamlık kapalı, otomatik vurgu, düz siyah duvar kağıdı)'
    Description = 'Uygulamalar ve Windows koyu kipe geçer, saydamlık efektleri kapanır. Vurgu rengi Otomatik (duvar kağıdından; düz siyahta Windows varsayılanı) ve Başlat / görev çubuğu ile pencere başlıklarında gösterilmez: yüzeyler koyu kipin kendi koyu grisinde kalır. Duvar kağıdı kaldırılır, masaüstü düz siyah renk olur (Kişiselleştir > Arka plan: Düz renk). Değişiklikler hemen yayınlanır; bazı uygulamalar yeniden açılınca koyulaşır.'
    Category    = 'ui'
    Risk        = 'Safe'
    Refresh     = @('Desktop', 'Settings')
    Actions     = @(
        # Koyu kip (uygulamalar + sistem), saydamlık kapalı
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'AppsUseLightTheme'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'SystemUsesLightTheme'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'EnableTransparency'; Value = 0; Kind = 'DWord' }
        # Vurgu rengi: Otomatik; Başlat / görev çubuğunda ve pencere başlıklarında / kenarlıklarında gösterilmez
        @{ Type = 'Registry'; Path = 'HKCU:\Control Panel\Desktop'; Name = 'AutoColorization'; Value = 1; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'ColorPrevalence'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\DWM'; Name = 'ColorPrevalence'; Value = 0; Kind = 'DWord' }
        # Düz siyah masaüstü: duvar kağıdı yok, arka plan türü düz renk (1), renk 0 0 0
        @{ Type = 'Registry'; Path = 'HKCU:\Control Panel\Desktop'; Name = 'WallPaper'; Value = ''; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKCU:\Control Panel\Colors'; Name = 'Background'; Value = '0 0 0'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers'; Name = 'BackgroundType'; Value = 1; Kind = 'DWord' }
    )
}
