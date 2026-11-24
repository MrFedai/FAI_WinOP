@{
    Id          = 'ui.account-pictures-black'
    Title       = 'Varsayılan hesap resimleri siyah'
    Description = 'Windows''un varsayılan kullanıcı ve konuk resimleri (%ProgramData%\Microsoft\User Account Pictures içindeki .png / .bmp dosyaları) aynı boyutta düz siyah görüntüyle değiştirilir; hesabına kendi resmini koymamış kullanıcılar Başlat''ta, giriş ekranında ve Ayarlar''da siyah daire görür. Alt klasörler (kullanıcıların kendi resimleri) ve kullanıcının seçtiği resim değişmez. Özgün dosyalar yedeklenir, geri alma birebir geri yazar. Etkisi oturum yeniden açılınca görülür.'
    Category    = 'ui'
    Risk        = 'Safe'
    Actions     = @(
        @{ Type = 'SolidImage'; Directory = '%ProgramData%\Microsoft\User Account Pictures'; Filter = @('*.png', '*.bmp'); Color = '000000' }
    )
}
