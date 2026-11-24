@{
    Id          = 'sound.startup-sound-off'
    Title       = 'Açılış sesini kapat'
    Description = 'Windows oturum açma (başlangıç) sesini kapatır. Ayarlar > Kişiselleştirme > Temalar > Sesler > "Windows Başlangıç sesini çal" kutusunun karşılığı; iki değer birlikte yazılır, biri yalnız bazı sürümlerde okunur.'
    Category    = 'sound'
    Risk        = 'Safe'
    Actions     = @(
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\BootAnimation'; Name = 'DisableStartupSound'; Value = 1; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\EditionOverrides'; Name = 'UserSetting_DisableStartupSound'; Value = 1; Kind = 'DWord' }
    )
}
