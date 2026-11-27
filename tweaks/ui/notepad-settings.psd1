@{
    Id          = 'ui.notepad-settings'
    Title       = 'Notepad settings'
    Description = 'Notepad (Store version) is configured through its own settings file (settings.dat): files open in a new window (instead of a tab), the previous session is not restored at startup (unsaved tabs are not remembered), and rewriting with Copilot (AI) is off. Notepad is closed if it is open. The settings file is created the first time the app opens: if Notepad has never been opened, the tweak shows as "already set" and is applied on the next run. Value names and meanings depend on the Notepad version; to be verified on a real machine (Phase 9).'
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
