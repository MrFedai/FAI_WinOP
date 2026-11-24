@{
    Id          = 'power.plan'
    Title       = 'Güç planı: prizde yüksek performans, pilde dengeli'
    Description = 'Aracın kendi güç planını (FAI_WinOP, sabit GUID) Balanced''dan kopyalayıp etkin yapar; var olan bir planın varlığı varsayılmaz (Balanced silinmişse etkin planın kopyası alınır). Prizde (AC): işlemci en düşük / en yüksek durum %100, çekirdek park etme kapalı (en az çekirdek %100), soğutma etkin, USB seçici askıya alma ve PCIe bağlantı durumu güç yönetimi kapalı, disk kapanmaz, kablosuz bağdaştırıcı en yüksek performans, uyku ve hazırda bekletme yok. Pilde (DC): Balanced varsayılanları kalır; uyku (sleepOnBatterySec, varsayılan 900 sn) ve hazırda bekletme (hibernateOnBatterySec, varsayılan 10800 sn) açıkça açık. Dizüstünde hazırda bekletme (powercfg /hibernate on) da açılır. Ekran ve parlaklığa dokunulmaz. Geri alma önceki etkin plana döner ve aracın planını siler.'
    Category    = 'power'
    Risk        = 'Safe'
    Params      = @{ sleepOnBatterySec = 900; hibernateOnBatterySec = 10800 }
    Actions     = @(
        @{ Type = 'PowerScheme'; Guid = '46414900-5769-4e4f-9000-000000000001'; Name = 'FAI_WinOP'; Base = '381b4222-f694-41f0-9685-ff5bb260df2e' }
        # İşlemci (prizde): en düşük / en yüksek durum, çekirdek park etme, soğutma etkin
        @{ Type = 'Power'; Scheme = '46414900-5769-4e4f-9000-000000000001'; Subgroup = 'SUB_PROCESSOR'; Setting = 'PROCTHROTTLEMIN'; AC = 100 }
        @{ Type = 'Power'; Scheme = '46414900-5769-4e4f-9000-000000000001'; Subgroup = 'SUB_PROCESSOR'; Setting = 'PROCTHROTTLEMAX'; AC = 100 }
        @{ Type = 'Power'; Scheme = '46414900-5769-4e4f-9000-000000000001'; Subgroup = 'SUB_PROCESSOR'; Setting = 'CPMINCORES'; AC = 100 }
        @{ Type = 'Power'; Scheme = '46414900-5769-4e4f-9000-000000000001'; Subgroup = 'SUB_PROCESSOR'; Setting = 'SYSCOOLPOL'; AC = 1 }
        # USB seçici askıya alma (prizde kapalı)
        @{ Type = 'Power'; Scheme = '46414900-5769-4e4f-9000-000000000001'; Subgroup = '2a737441-1930-4402-8d77-b2bebba308a3'; Setting = '48e6b7a6-50f5-4782-a5d4-53bb8f07e226'; AC = 0 }
        # PCI Express bağlantı durumu güç yönetimi (prizde kapalı)
        @{ Type = 'Power'; Scheme = '46414900-5769-4e4f-9000-000000000001'; Subgroup = 'SUB_PCIEXPRESS'; Setting = 'ASPM'; AC = 0 }
        # Diski kapatma (prizde hiçbir zaman)
        @{ Type = 'Power'; Scheme = '46414900-5769-4e4f-9000-000000000001'; Subgroup = 'SUB_DISK'; Setting = 'DISKIDLE'; AC = 0 }
        # Kablosuz bağdaştırıcı güç tasarrufu: 0 = en yüksek performans (prizde)
        @{ Type = 'Power'; Scheme = '46414900-5769-4e4f-9000-000000000001'; Subgroup = '19cbb8fa-5279-450e-9fac-8a3d5fedd0c1'; Setting = '12bbebe6-58d6-4636-95bb-3217ef867c1a'; AC = 0 }
        # Uyku / hazırda bekletme: prizde yok, pilde açık
        @{ Type = 'Power'; Scheme = '46414900-5769-4e4f-9000-000000000001'; Subgroup = 'SUB_SLEEP'; Setting = 'STANDBYIDLE'; AC = 0; DC = '{{sleepOnBatterySec}}' }
        @{ Type = 'Power'; Scheme = '46414900-5769-4e4f-9000-000000000001'; Subgroup = 'SUB_SLEEP'; Setting = 'HIBERNATEIDLE'; AC = 0; DC = '{{hibernateOnBatterySec}}' }
        @{ Type = 'Hibernate'; Enabled = $true; When = 'IsLaptop' }
    )
}
