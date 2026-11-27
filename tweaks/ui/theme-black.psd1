@{
    Id          = 'ui.theme-black'
    Title       = 'Black theme (dark, transparency off, automatic accent, solid black wallpaper)'
    Description = 'Apps and Windows switch to dark mode and transparency effects are turned off. The accent color is Automatic (from the wallpaper; on solid black, the Windows default) and is not shown on Start / taskbar and window title bars: surfaces stay in dark mode''s own dark gray. The wallpaper is removed and the desktop becomes a solid black color (Personalize > Background: Solid color). Changes are broadcast immediately; some apps turn dark when reopened.'
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
