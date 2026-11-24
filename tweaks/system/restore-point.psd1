@{
    Id          = 'system.restore-point'
    Title       = 'Sistem Geri Yükleme noktası'
    Description = 'Her çalıştırmada ilk adım (First): profildeki uygulamalardan ve öteki tweak''lerden önce bir Sistem Geri Yükleme noktası oluşturur. Sistem sürücüsünde Sistem Koruması kapalıysa açar. Windows''un 24 saatte bir nokta sınırı (SystemRestorePointCreationFrequency) oluşturma sırasında geçici olarak kaldırılır, sonra eski hâline döner. -Undo noktayı silmez; FAI_WinOP''un kendi geri alması ayrıca vardır, bu nokta son çare (rstrui). Not: Sistem Koruması açma / nokta oluşturma gerçek makinede (VM) doğrulanmadı.'
    Category    = 'system'
    Risk        = 'Safe'
    First       = $true
    Params      = @{ description = 'FAI_WinOP' }
    Actions     = @(
        @{ Type = 'RestorePoint'; Description = '{{description}}' }
    )
}
