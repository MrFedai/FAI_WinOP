@{
    Id          = 'power.plan'
    Title       = 'Power plan: high performance on AC, balanced on battery'
    Description = 'Copies the tool''s own power plan (FAI_WinOP, fixed GUID) from Balanced and makes it active; the existence of any plan is not assumed (if Balanced was deleted, a copy of the active plan is used). On AC: processor minimum / maximum state 100%, core parking off (minimum cores 100%), cooling active, USB selective suspend and PCIe link state power management off, disk never turns off, wireless adapter at maximum performance, no sleep or hibernate. On battery (DC): Balanced defaults stay; sleep (sleepOnBatterySec, default 900 s) and hibernate (hibernateOnBatterySec, default 10800 s) are explicitly on. On a laptop, hibernate (powercfg /hibernate on) is also enabled. Display and brightness are not touched. Revert returns to the previous active plan and deletes the tool''s plan.'
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
