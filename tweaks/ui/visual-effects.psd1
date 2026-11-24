@{
    Id          = 'ui.visual-effects'
    Title       = 'Görsel efektleri azalt (yazı yumuşatma açık)'
    Description = 'Sistem > Gelişmiş sistem ayarları > Performans seçenekleri "Özel" yapılır: menü / araç ipucu solma ve kayma animasyonları, açılır kutu ve liste kaydırma animasyonları, fare işaretçisi ve pencere gölgeleri, simge etiketi gölgeleri, yarı saydam seçim dikdörtgeni, pencere küçültme / büyütme ve görev çubuğu animasyonları kapanır. Ekran yazı tiplerinin kenarlarını yumuşatma (ClearType) ve küçük resim önizlemeleri açık kalır; pencere sürüklenirken içerik gösterilmeye devam eder. UserPreferencesMask ikili (REG_BINARY) değerdir; değişiklikler oturum kapatılıp açılınca tam etkili olur.'
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
