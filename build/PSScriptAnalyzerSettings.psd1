# FAI_WinOP — PSScriptAnalyzer ayarları
# Hedef: Windows PowerShell 5.1 (geliştirme Ubuntu'da pwsh 7 ile yapılır; 7'ye özgü sözdizimi / komut yakalanmalı).
#
# 5.1 uyumluluk kuralları:
#   PSUseCompatibleSyntax   : ??, ?., ternary, && / || gibi 7'ye özgü sözdizimi (hedef 5.1)
#   PSUseCompatibleCmdlets  : cmdlet adları, hedef 'desktop-5.1.14393.206-windows'
#   PSUseCompatibleCommands : cmdlet + parametre (ör. ConvertFrom-Json -AsHashtable), hedef Windows 5.1 profili
#   PSUseCompatibleTypes    : .NET tipleri / üyeleri, aynı profil
# PSUseCompatibleCommands / Types 'desktop-5.1.14393.206-windows' adını tanımaz (o ad yalnız PSUseCompatibleCmdlets'in);
# onlar için PSScriptAnalyzer'ın gömülü Windows 10 1809 / PowerShell 5.1 profili kullanılır.
@{
    Severity     = @('Error', 'Warning')

    ExcludeRules = @(
        # Konsol aracı: renkli çıktı Write-Host ile verilir.
        'PSAvoidUsingWriteHost',
        # New-FaiAction gibi iç fabrikalar sistem durumunu değiştirmez; -WhatIf / -Confirm anlamsız.
        'PSUseShouldProcessForStateChangingFunctions'
    )

    Rules        = @{
        PSUseCompatibleSyntax   = @{
            Enable         = $true
            TargetVersions = @('5.1')
        }
        PSUseCompatibleCmdlets  = @{
            Compatibility = @('desktop-5.1.14393.206-windows')
        }
        PSUseCompatibleCommands = @{
            Enable         = $true
            TargetProfiles = @('win-8_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework')
        }
        PSUseCompatibleTypes    = @{
            Enable         = $true
            TargetProfiles = @('win-8_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework')
        }
    }
}
