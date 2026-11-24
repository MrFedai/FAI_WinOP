@{
    Id          = 'setup.mmagent-off'
    Title       = 'Bellek sıkıştırma ve ön getirmeyi kapat'
    Description = 'Bellek yöneticisinde (MMAgent) bellek sıkıştırma, uygulama başlatma ön getirmesi (prefetch) ve uygulama ön yüklemesi (PreLaunch) kapatılır; ayrıca PrefetchParameters\EnablePrefetcher=0. Bol RAM''li (en az 16 GB) makine içindir: sıkıştırma için harcanan işlemci zamanı ve arka plan disk okumaları kalkar. Sayfa birleştirme ve OperationAPI''ye dokunulmaz. Bellek sıkıştırma yeniden başlatınca etkinleşir. Get-MMAgent SysMain servisinin çalışmasını ister.'
    Category    = 'setup'
    Risk        = 'Safe'
    Conditions  = @(@{ MinRamGB = 16 })
    Actions     = @(
        @{ Type = 'MMAgent'; Feature = 'MemoryCompression'; Enabled = $false }
        @{ Type = 'MMAgent'; Feature = 'ApplicationLaunchPrefetching'; Enabled = $false }
        @{ Type = 'MMAgent'; Feature = 'ApplicationPreLaunch'; Enabled = $false }
        @{ Type = 'Registry'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters'; Name = 'EnablePrefetcher'; Value = 0; Kind = 'DWord' }
    )
}
