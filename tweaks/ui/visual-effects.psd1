@{
    Id          = 'ui.visual-effects'
    Title       = 'Reduce visual effects (font smoothing on)'
    Description = 'System > Advanced system settings > Performance Options is set to "Custom": menu / tooltip fade and slide animations, combo box and list box scrolling animations, mouse pointer and window shadows, icon label shadows, translucent selection rectangle, window minimize / maximize animations and taskbar animations are turned off. Smoothing the edges of screen fonts (ClearType) and thumbnail previews stay on; window contents keep showing while dragging. UserPreferencesMask is a binary (REG_BINARY) value; changes take full effect after signing out and back in.'
    Category    = 'ui'
    Risk        = 'Safe'
    Actions     = @(
        # Performans seçenekleri: Özel
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'; Name = 'VisualFXSetting'; Value = 3; Kind = 'DWord' }
        # Solma / kayma / gölge bitleri kapalı ("en iyi performans" maskesi)
        @{ Type = 'Registry'; Path = 'HKCU:\Control Panel\Desktop'; Name = 'UserPreferencesMask'; Value = @(0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00); Kind = 'Binary' }
        # Pencere küçültme / büyütme animasyonu
        @{ Type = 'Registry'; Path = 'HKCU:\Control Panel\Desktop\WindowMetrics'; Name = 'MinAnimate'; Value = '0'; Kind = 'String' }
        # Görev çubuğu animasyonları
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'TaskbarAnimations'; Value = 0; Kind = 'DWord' }
        # Yarı saydam seçim dikdörtgeni ve masaüstü simge etiketi gölgesi
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ListviewAlphaSelect'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ListviewShadow'; Value = 0; Kind = 'DWord' }
        # Açık kalanlar: yazı yumuşatma ve küçük resimler
        @{ Type = 'Registry'; Path = 'HKCU:\Control Panel\Desktop'; Name = 'FontSmoothing'; Value = '2'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'IconsOnly'; Value = 0; Kind = 'DWord' }
    )
}
