@{
    Id          = 'ui.lockscreen-black'
    Title       = 'Kilit ve oturum açma ekranı siyah'
    Description = 'Düz siyah bir görüntü (C:\ProgramData\FAI_WinOP\Black.png, 1920x1080) üretilir ve kilit ekranı görüntüsü olarak ilkeyle (PersonalizationCSP) atanır; Windows Spotlight ve kilit ekranı ipuçları bu görüntüyle devre dışı kalır, kullanıcı Ayarlar''dan değiştiremez. Oturum açma ekranındaki bulanık (akrilik) arka plan kapatılır, böylece giriş ekranı da siyah görünür. Yol sistem sürücüsü C: varsayılarak yazılır (ilke değeri ortam değişkeni açmaz). Etkisi bir sonraki kilitlemede görülür.'
    Category    = 'ui'
    Risk        = 'Safe'
    Actions     = @(
        @{ Type = 'SolidImage'; Path = 'C:\ProgramData\FAI_WinOP\Black.png'; Color = '000000'; Width = 1920; Height = 1080 }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'; Name = 'LockScreenImagePath'; Value = 'C:\ProgramData\FAI_WinOP\Black.png'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'; Name = 'LockScreenImageUrl'; Value = 'C:\ProgramData\FAI_WinOP\Black.png'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'; Name = 'LockScreenImageStatus'; Value = 1; Kind = 'DWord' }
        # Oturum açma ekranında akrilik bulanıklık yok
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'DisableAcrylicBackgroundOnLogon'; Value = 1; Kind = 'DWord' }
    )
}
