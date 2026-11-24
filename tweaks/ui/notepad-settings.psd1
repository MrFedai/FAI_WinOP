@{
    Id          = 'ui.notepad-settings'
    Title       = 'Not Defteri ayarları'
    Description = 'Not Defteri (Store sürümü) kendi ayar dosyasından (settings.dat) ayarlanır: dosyalar yeni pencerede açılır (sekme yerine), açılışta önceki oturum geri yüklenmez (kaydedilmemiş sekmeler hatırlanmaz), Copilot ile yeniden yazma (AI) kapalı. Not Defteri açıksa kapatılır. Ayar dosyası uygulama ilk açılışında oluşur: Not Defteri hiç açılmadıysa tweak "zaten uygun" görünür ve bir sonraki çalıştırmada uygulanır. Değer adları ve anlamları Not Defteri sürümüne bağlıdır; gerçek makinede doğrulanacak (Faz 9).'
    Category    = 'ui'
    Risk        = 'Safe'
    Params      = @{ openInNewWindow = 1; restoreSession = $false; aiRewrite = $false }
    Actions     = @(
        # OpenFile: 0 = yeni sekmede, 1 = yeni pencerede
        @{ Type = 'AppSetting'; Package = 'Microsoft.WindowsNotepad_8wekyb3d8bbwe'; Name = 'OpenFile'; Kind = 'Int32'; Value = '{{openInNewWindow}}' }
        # GhostFile: önceki oturumu (kaydedilmemiş içerik) sürdür
        @{ Type = 'AppSetting'; Package = 'Microsoft.WindowsNotepad_8wekyb3d8bbwe'; Name = 'GhostFile'; Kind = 'Bool'; Value = '{{restoreSession}}' }
        # RewriteEnabled: Copilot ile yeniden yaz
        @{ Type = 'AppSetting'; Package = 'Microsoft.WindowsNotepad_8wekyb3d8bbwe'; Name = 'RewriteEnabled'; Kind = 'Bool'; Value = '{{aiRewrite}}' }
    )
}
