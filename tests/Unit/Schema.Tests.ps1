#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }
# Şema doğrulayıcı: tweak (.psd1) ve profil (.json). Hatalar '<alan yolu>: <neden>' biçiminde listelenir.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Load-Fakes.ps1')
    $script:TweakValid = Join-Path $script:FaiFixtures 'Tweaks/valid'
    $script:TweakInvalid = Join-Path $script:FaiFixtures 'Tweaks/invalid'
    $script:ProfileDir = Join-Path $script:FaiFixtures 'Profiles'

    # Hata listesinde verilen önekle başlayan bir ileti var mı.
    function Test-HasError([string[]] $Errors, [string] $Prefix) {
        return (@($Errors | Where-Object { $_.StartsWith($Prefix, [System.StringComparison]::Ordinal) }).Count -gt 0)
    }
    function New-TweakData([hashtable] $Override) {
        $d = @{
            Id = 'test.sample'; Title = 'Örnek'; Description = 'Açıklama'; Category = 'test'; Risk = 'Safe'
            Actions = @(@{ Type = 'Registry'; Path = 'HKCU:\Software\T'; Name = 'N'; Value = 1; Kind = 'DWord' })
        }
        foreach ($k in $Override.Keys) {
            if ($null -eq $Override[$k]) { $d.Remove($k) } else { $d[$k] = $Override[$k] }
        }
        return $d
    }
}

Describe 'Tweak şeması — geçerli fixture''lar' {
    It 'valid/ altındaki her .psd1 yüklenir' {
        foreach ($f in Get-ChildItem -LiteralPath $TweakValid -Filter '*.psd1') {
            { Import-FaiTweakFile -Path $f.FullName } | Should -Not -Throw -Because $f.Name
        }
    }

    It 'alanları Tweak nesnesine doğru okur' {
        $t = Import-FaiTweakFile -Path (Join-Path $TweakValid 'params-demo.psd1')
        $t.Id | Should -Be 'fixture.params-demo'
        $t.Risk | Should -Be 'Caution'
        $t.Confirm | Should -Match 'örnektir'
        $t.Actions.Count | Should -Be 1
        # Should -BeOfType betik içi sınıfları çözemez; tür adıyla karşılaştırılır.
        $t.Actions[0].GetType().Name | Should -Be 'RegistryAction'
    }

    It 'varsayılan Params yer tutucuyu tür korunarak açar (DWord = 15 tamsayı)' {
        $t = Import-FaiTweakFile -Path (Join-Path $TweakValid 'params-demo.psd1')
        $t.Actions[0].Definition['Value'] | Should -BeOfType [int]
        $t.Actions[0].Definition['Value'] | Should -Be 15
    }

    It 'koşulları Condition nesnesine çevirir' {
        $t = Import-FaiTweakFile -Path (Join-Path $TweakValid 'service-demo.psd1')
        $t.Conditions.Count | Should -Be 2
        $t.Conditions[0].Describe() | Should -Be 'not: IsLaptop'
        $t.Actions[0].GetType().Name | Should -Be 'ServiceAction'
    }

    It 'Import-FaiTweakCatalog bütün geçerli dosyaları Id → Tweak olarak yükler' {
        $cat = Import-FaiTweakCatalog -Path $TweakValid
        $cat.Count | Should -Be 3
        $cat['fixture.registry-demo'].GetType().Name | Should -Be 'Tweak'
    }
}

Describe 'Tweak şeması — geçersiz fixture''lar (alan yolu + neden)' {
    It 'eksik zorunlu alanları listeler' {
        $e = @(Get-FaiTweakError (Import-PowerShellDataFile (Join-Path $TweakInvalid 'missing-fields.psd1')))
        Test-HasError $e 'Title: required field missing' | Should -BeTrue -Because ($e -join '; ')
        Test-HasError $e 'Description: required field missing' | Should -BeTrue
        Test-HasError $e 'Actions: required field missing' | Should -BeTrue
        $e.Count | Should -Be 3
    }

    It 'eylem hatalarını Actions[i].alan yoluyla verir' {
        $e = @(Get-FaiTweakError (Import-PowerShellDataFile (Join-Path $TweakInvalid 'bad-action.psd1')))
        Test-HasError $e 'Actions[0].Path:' | Should -BeTrue -Because ($e -join '; ')
        Test-HasError $e 'Actions[0].Value: must be a 32-bit integer for DWord' | Should -BeTrue
        Test-HasError $e 'Actions[1].Type: unknown action type ''Teleport''' | Should -BeTrue
        Test-HasError $e 'Actions[2].StartTyp: unknown field' | Should -BeTrue
        Test-HasError $e 'Actions[2].StartType / State: at least one is required' | Should -BeTrue
    }

    It 'bilinmeyen alan, geçersiz Risk, geçersiz koşul ve tanımsız yer tutucuyu yakalar' {
        $e = @(Get-FaiTweakError (Import-PowerShellDataFile (Join-Path $TweakInvalid 'unknown-key-bad-risk.psd1')))
        Test-HasError $e 'Descripton: unknown field' | Should -BeTrue -Because ($e -join '; ')
        Test-HasError $e 'Risk: ''Dangerous'' is invalid' | Should -BeTrue
        Test-HasError $e 'Conditions[0]: unknown condition ''HasQuantumGpu''' | Should -BeTrue
        Test-HasError $e 'Conditions[1]: MinBuild' | Should -BeTrue
        Test-HasError $e 'Actions[0]: placeholder ''{{seviye}}'' is not defined in Params' | Should -BeTrue
    }

    It 'Import-FaiTweakFile geçersiz dosyada dosya yolu + alan yoluyla hata fırlatır' {
        $path = Join-Path $TweakInvalid 'missing-fields.psd1'
        $err = $null
        try { Import-FaiTweakFile -Path $path } catch { $err = $_.Exception.Message }
        $err | Should -Not -BeNullOrEmpty
        $err | Should -Match 'missing-fields\.psd1'
        $err | Should -Match 'Title: required field missing'
    }

    It 'Import-FaiTweakCatalog bütün geçersiz dosyaları tek hatada listeler' {
        $err = $null
        try { Import-FaiTweakCatalog -Path $TweakInvalid } catch { $err = $_.Exception.Message }
        $err | Should -Match 'missing-fields\.psd1'
        $err | Should -Match 'bad-action\.psd1'
        $err | Should -Match 'unknown-key-bad-risk\.psd1'
    }

    It 'aynı Id iki dosyada olursa katalog hata verir' {
        $dir = Join-Path $TestDrive 'dup'
        New-Item -ItemType Directory -Path $dir | Out-Null
        Copy-Item (Join-Path $TweakValid 'registry-demo.psd1') (Join-Path $dir 'a.psd1')
        Copy-Item (Join-Path $TweakValid 'registry-demo.psd1') (Join-Path $dir 'b.psd1')
        { Import-FaiTweakCatalog -Path $dir } | Should -Throw '*in more than one file*'
    }
}

Describe 'Tweak şeması — tek tek kurallar' {
    It 'kök hashtable değilse hata verir' {
        @(Get-FaiTweakError 'metin')[0] | Should -Match '^\(root\):'
        @(Get-FaiTweakError $null)[0] | Should -Match '^\(root\):'
    }

    It 'geçerli en küçük tweak hatasızdır' {
        @(Get-FaiTweakError (New-TweakData @{})).Count | Should -Be 0
    }

    It 'Id biçimini denetler' {
        foreach ($bad in 'Sound.Volume', 'sound', 'sound.', 'sound.a b', 'sound.-x') {
            $e = @(Get-FaiTweakError (New-TweakData @{ Id = $bad }))
            Test-HasError $e 'Id:' | Should -BeTrue -Because "'$bad' geçersiz olmalı"
        }
        foreach ($ok in 'sound.volume', 'setup.mmagent-off', 'a1.b2-c3') {
            @(Get-FaiTweakError (New-TweakData @{ Id = $ok })).Count | Should -Be 0 -Because "'$ok' geçerli olmalı"
        }
    }

    It 'Risk yalnız Safe / Caution / Risk kabul eder (harf duyarlı)' {
        foreach ($ok in 'Safe', 'Caution', 'Risk') { @(Get-FaiTweakError (New-TweakData @{ Risk = $ok })).Count | Should -Be 0 }
        Test-HasError @(Get-FaiTweakError (New-TweakData @{ Risk = 'safe' })) 'Risk:' | Should -BeTrue
    }

    It 'Actions dizi, boş olmayan ve hashtable elemanlı olmalı' {
        Test-HasError @(Get-FaiTweakError (New-TweakData @{ Actions = @() })) 'Actions: at least one action' | Should -BeTrue
        Test-HasError @(Get-FaiTweakError (New-TweakData @{ Actions = @{ Type = 'Registry' } })) 'Actions: must be an array' | Should -BeTrue
        Test-HasError @(Get-FaiTweakError (New-TweakData @{ Actions = @('x') })) 'Actions[0]: action must be a hashtable' | Should -BeTrue
        Test-HasError @(Get-FaiTweakError (New-TweakData @{ Actions = @(@{ Name = 'x' }) })) 'Actions[0].Type: required field missing' | Should -BeTrue
    }

    It 'Registry eylemi: Path, Kind, Value türü ve Ensure kurallarını denetler' {
        $act = { param($h) @(Get-FaiTweakError (New-TweakData @{ Actions = @($h) })) }
        Test-HasError (& $act @{ Type = 'Registry'; Path = 'X:\a'; Name = 'n'; Value = 1; Kind = 'DWord' }) 'Actions[0].Path:' | Should -BeTrue
        Test-HasError (& $act @{ Type = 'Registry'; Path = 'HKCU:\a'; Name = 'n'; Value = 1; Kind = 'Bogus' }) 'Actions[0].Kind:' | Should -BeTrue
        Test-HasError (& $act @{ Type = 'Registry'; Path = 'HKCU:\a'; Name = 'n'; Kind = 'DWord' }) 'Actions[0].Value: required' | Should -BeTrue
        Test-HasError (& $act @{ Type = 'Registry'; Path = 'HKCU:\a'; Name = 'n'; Value = 'x'; Kind = 'DWord' }) 'Actions[0].Value:' | Should -BeTrue
        Test-HasError (& $act @{ Type = 'Registry'; Path = 'HKCU:\a'; Name = 'n'; Value = 1; Kind = 'String' }) 'Actions[0].Value:' | Should -BeTrue
        Test-HasError (& $act @{ Type = 'Registry'; Path = 'HKCU:\a'; Name = 'n'; Value = @(1, 2); Kind = 'MultiString' }) 'Actions[0].Value:' | Should -BeTrue
        Test-HasError (& $act @{ Type = 'Registry'; Path = 'HKCU:\a'; Name = 'n'; Value = @(1, 300); Kind = 'Binary' }) 'Actions[0].Value:' | Should -BeTrue
        Test-HasError (& $act @{ Type = 'Registry'; Path = 'HKCU:\a'; Name = 'n'; Ensure = 'Absent'; Value = 1 }) 'Actions[0].Value: not allowed when Ensure=Absent' | Should -BeTrue
        Test-HasError (& $act @{ Type = 'Registry'; Path = 'HKCU:\a'; Name = 'n'; Ensure = 'Maybe' }) 'Actions[0].Ensure:' | Should -BeTrue
        (& $act @{ Type = 'Registry'; Path = 'HKLM:\a\b'; Name = ''; Value = @('a'); Kind = 'MultiString' }).Count | Should -Be 0
        (& $act @{ Type = 'Registry'; Path = 'HKCU:\a'; Name = 'n'; Ensure = 'Absent' }).Count | Should -Be 0
    }

    It 'Service eylemi: StartType / State değerlerini denetler' {
        $act = { param($h) @(Get-FaiTweakError (New-TweakData @{ Actions = @($h) })) }
        Test-HasError (& $act @{ Type = 'Service'; Name = 'S'; StartType = 'Never' }) 'Actions[0].StartType:' | Should -BeTrue
        Test-HasError (& $act @{ Type = 'Service'; Name = 'S'; State = 'Paused' }) 'Actions[0].State:' | Should -BeTrue
        Test-HasError (& $act @{ Type = 'Service'; StartType = 'Manual' }) 'Actions[0].Name: required' | Should -BeTrue
        (& $act @{ Type = 'Service'; Name = 'S'; StartType = 'Manual' }).Count | Should -Be 0
    }

    It 'Conditions: geçerli biçimleri kabul, geçersizleri red eder' {
        $ok = @('IsLaptop', 'HasNvidia', @{ Not = 'HasAmdGpu' }, @{ Edition = 'Pro' }, @{ Edition = @('Pro', 'Enterprise') }, @{ MinBuild = 22621 }, @{ MinRamGB = 16 })
        @(Get-FaiTweakError (New-TweakData @{ Conditions = $ok })).Count | Should -Be 0
        $bad = @(@{ Not = 'MinBuild' }, @{ MinBuild = -1 }, @{ Edition = '' }, @{ A = 1; B = 2 }, 5)
        $e = @(Get-FaiTweakError (New-TweakData @{ Conditions = $bad }))
        for ($i = 0; $i -lt $bad.Count; $i++) { Test-HasError $e "Conditions[$i]:" | Should -BeTrue -Because "Conditions[$i] geçersiz olmalı" }
    }

    It 'Params adı geçerli olmalı; yer tutucu Params''ta tanımlıysa hata yok' {
        Test-HasError @(Get-FaiTweakError (New-TweakData @{ Params = @{ '1x' = 1 } })) 'Params.1x:' | Should -BeTrue
        $a = @(@{ Type = 'Registry'; Path = 'HKCU:\a'; Name = 'n'; Value = '{{lvl}}'; Kind = 'DWord' })
        @(Get-FaiTweakError (New-TweakData @{ Params = @{ lvl = 3 }; Actions = $a })).Count | Should -Be 0
    }

    It 'Tweak.WithParams: tanımsız parametreyi ve tür uyuşmazlığını reddeder' {
        $t = Import-FaiTweakFile -Path (Join-Path $TweakValid 'params-demo.psd1')
        { $t.WithParams(@{ nope = 1 }) } | Should -Throw '*undefined parameter*'
        { $t.WithParams(@{ level = 'yüksek' }) } | Should -Throw '*DWord*'
        $t2 = $t.WithParams(@{ level = 30 })
        $t2.Actions[0].Definition['Value'] | Should -Be 30
        $t.Actions[0].Definition['Value'] | Should -Be 15 -Because 'asıl tweak değişmemeli'
    }
}

Describe 'Profil şeması' {
    It 'minimal.json ve smoke.json geçerlidir ve Profile nesnesine okunur' {
        $min = Import-FaiProfileFile -Path (Join-Path $ProfileDir 'minimal.json')
        $min.Name | Should -Be 'min'
        $min.Tweaks.Count | Should -Be 1
        $min.Tweaks[0]['Id'] | Should -Be 'fixture.registry-demo'

        $p = Import-FaiProfileFile -Path (Join-Path $ProfileDir 'smoke.json')
        $p.Name | Should -Be 'fixture-smoke'
        $p.Tweaks.Count | Should -Be 3
        $p.Tweaks[2]['Id'] | Should -Be 'fixture.params-demo'
        $p.Tweaks[2]['Params']['level'] | Should -Be 30
        $p.IsAutoConfirmed('fixture.params-demo') | Should -BeTrue
        $p.IsAutoConfirmed('fixture.registry-demo') | Should -BeFalse
    }

    It 'boş dizi ve tek elemanlı dizi alanları dizi kalır (5.1 tuzağı)' {
        $p = Import-FaiProfileFile -Path (Join-Path $ProfileDir 'minimal.json')
        , $p.Tweaks | Should -BeOfType [System.Array]
        $p.Tweaks.Count | Should -Be 1
        $p.AutoConfirm.Count | Should -Be 0
        $p.Apps.Count | Should -Be 0
    }

    It 'invalid-many.json: her hata alan yoluyla listelenir' {
        $data = Read-JsonFile (Join-Path $ProfileDir 'invalid-many.json')
        $e = @(Get-FaiProfileError $data)
        Test-HasError $e 'nam: unknown field' | Should -BeTrue -Because ($e -join '; ')
        Test-HasError $e 'name: required field missing' | Should -BeTrue
        Test-HasError $e 'tweaks[1]: ''fixture.registry-demo'' is listed more than once' | Should -BeTrue
        Test-HasError $e 'tweaks[2]: ''Büyük Harf'' is not a valid tweak ID' | Should -BeTrue
        Test-HasError $e 'tweaks[3].id: must be a string' | Should -BeTrue
        Test-HasError $e 'tweaks[4].extra: unknown field' | Should -BeTrue
        Test-HasError $e 'tweaks[4].params: must be an object' | Should -BeTrue
        Test-HasError $e 'tweaks[5]:' | Should -BeTrue
        Test-HasError $e 'autoConfirm[0]: ''fixture.service-demo'' is not in the tweaks list' | Should -BeTrue
        Test-HasError $e 'autoConfirm[1]: must be a string' | Should -BeTrue
        Test-HasError $e 'apps: must be an array' | Should -BeTrue
        Test-HasError $e 'layout: must be an object' | Should -BeTrue
    }

    It 'Import-FaiProfileFile geçersiz dosyada dosya yolu + alan yoluyla hata fırlatır' {
        $err = $null
        try { Import-FaiProfileFile -Path (Join-Path $ProfileDir 'invalid-many.json') } catch { $err = $_.Exception.Message }
        $err | Should -Match 'invalid-many\.json'
        $err | Should -Match 'name: required field missing'
    }

    It 'kök nesne değilse (dizi) hata verir' {
        $e = @(Get-FaiProfileError (ConvertFrom-JsonText '[1]'))
        $e[0] | Should -Match '^\(root\):'
    }

    It 'eskimiş exceptions alanı kabul edilir ve yok sayılır (geriye uyum)' {
        @(Get-FaiProfileError @{ name = 'x'; tweaks = @(); exceptions = @{ a = 1 } }).Count | Should -Be 0
        @(Get-FaiProfileError @{ name = 'x'; tweaks = @(); exceptions = 'her şey' }).Count | Should -Be 0
        $p = [Profile]::FromHashtable(@{ name = 'x'; tweaks = @(); exceptions = @{ a = 1 } }, 'test')
        $p.PSObject.Properties.Name | Should -Not -Contain 'Exceptions'
    }

    It 'tweaks eksik / dizi değil ise hata verir' {
        Test-HasError @(Get-FaiProfileError @{ name = 'x' }) 'tweaks: required field missing' | Should -BeTrue
        Test-HasError @(Get-FaiProfileError @{ name = 'x'; tweaks = 'a.b' }) 'tweaks: must be an array' | Should -BeTrue
    }

    It 'boş tweaks dizisi geçerli bir profildir' {
        @(Get-FaiProfileError (ConvertFrom-JsonText '{"name":"bos","tweaks":[]}')).Count | Should -Be 0
    }

    It 'profiles/_schema.json geçerli JSON ve alan adları doğrulayıcıyla birebir aynı' {
        $schema = Read-JsonFile (Join-Path $script:FaiRepoRoot 'profiles/_schema.json')
        $names = @($schema['properties'].Keys | Sort-Object)
        # 'exceptions' eskimiş: doğrulayıcı kabul eder ama şemada belgelenmez
        $expected = @(Get-FaiProfileKey | Where-Object { $_ -ne 'exceptions' } | Sort-Object)
        ($names -join ',') | Should -Be ($expected -join ',')
        ($schema['required'] | Sort-Object) -join ',' | Should -Be 'name,tweaks'
        $schema['additionalProperties'] | Should -BeFalse
    }
}
