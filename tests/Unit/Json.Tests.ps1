#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }
# ConvertTo-Hashtable / ConvertFrom-JsonText: 5.1'de ConvertFrom-Json -AsHashtable yok. Tuzaklar: tek elemanlı ve boş dizi
# açılmamalı, null, sayı / bool türleri korunmalı.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Load-Fakes.ps1')
}

Describe 'ConvertTo-Hashtable' {
    It 'iç içe PSCustomObject ağacını hashtable yapar' {
        $o = '{"a":{"b":{"c":1}},"d":"x"}' | ConvertFrom-Json
        $h = ConvertTo-Hashtable $o
        $h | Should -BeOfType [hashtable]
        $h['a'] | Should -BeOfType [hashtable]
        $h['a']['b'] | Should -BeOfType [hashtable]
        $h['a']['b']['c'] | Should -Be 1
        $h['d'] | Should -Be 'x'
    }

    It 'tek elemanlı diziyi dizi olarak korur (5.1 tuzağı: tek eleman açılmaz)' {
        $h = ConvertTo-Hashtable ('{"one":[7]}' | ConvertFrom-Json)
        , $h['one'] | Should -BeOfType [System.Array]
        $h['one'].Count | Should -Be 1
        $h['one'][0] | Should -Be 7
    }

    It 'boş diziyi dizi olarak korur, $null yapmaz (5.1 tuzağı: boş dizi kaybolur)' {
        $h = ConvertTo-Hashtable ('{"none":[]}' | ConvertFrom-Json)
        $h.ContainsKey('none') | Should -BeTrue
        $null -eq $h['none'] | Should -BeFalse
        , $h['none'] | Should -BeOfType [System.Array]
        $h['none'].Count | Should -Be 0
    }

    It 'nesne dizisinde her elemanı hashtable yapar, tek elemanlı nesne dizisi dizi kalır' {
        $h = ConvertTo-Hashtable ('{"list":[{"x":1}]}' | ConvertFrom-Json)
        , $h['list'] | Should -BeOfType [System.Array]
        $h['list'].Count | Should -Be 1
        $h['list'][0] | Should -BeOfType [hashtable]
        $h['list'][0]['x'] | Should -Be 1
    }

    It 'iç içe dizileri korur' {
        $h = ConvertTo-Hashtable ('{"m":[[1,2],[3]]}' | ConvertFrom-Json)
        $h['m'].Count | Should -Be 2
        , $h['m'][1] | Should -BeOfType [System.Array]
        $h['m'][1].Count | Should -Be 1
        $h['m'][0][1] | Should -Be 2
    }

    It 'null değerini korur (anahtar durur, değer $null)' {
        $h = ConvertTo-Hashtable ('{"n":null,"z":0}' | ConvertFrom-Json)
        $h.ContainsKey('n') | Should -BeTrue
        $null -eq $h['n'] | Should -BeTrue
        $h['z'] | Should -Be 0
    }

    It 'dizi içindeki null elemanı korur' {
        $h = ConvertTo-Hashtable ('{"a":[null,1]}' | ConvertFrom-Json)
        $h['a'].Count | Should -Be 2
        $null -eq $h['a'][0] | Should -BeTrue
    }

    It 'sayı ve bool türlerini korur' {
        $h = ConvertTo-Hashtable ('{"i":5,"t":true,"f":false,"d":1.5,"s":"5","big":4294967296}' | ConvertFrom-Json)
        # ConvertFrom-Json tamsayıyı 5.1'de Int32, 7'de Int64 verir; önemli olan metne / ondalığa dönmemesi.
        ($h['i'] -is [int] -or $h['i'] -is [long]) | Should -BeTrue
        $h['i'] | Should -Be 5
        $h['t'] | Should -BeOfType [bool]
        $h['t'] | Should -BeTrue
        $h['f'] | Should -BeFalse
        $h['d'] | Should -BeOfType ([System.ValueType])
        $h['d'] | Should -Be 1.5
        $h['s'] | Should -BeOfType [string]
        $h['s'] | Should -Be '5'
        $h['big'] | Should -Be 4294967296
    }

    It 'hashtable girdisini (psd1 çıktısı) iç içe dönüştürür, dizileri korur' {
        $in = @{ a = @{ b = @(1) }; c = @() }
        $h = ConvertTo-Hashtable $in
        $h['a']['b'].Count | Should -Be 1
        , $h['a']['b'] | Should -BeOfType [System.Array]
        $h['c'].Count | Should -Be 0
        $h | Should -Not -BeNullOrEmpty
    }

    It 'girdi nesnesini değiştirmez (kopya üretir)' {
        $in = @{ a = @{ b = 1 } }
        $h = ConvertTo-Hashtable $in
        $h['a']['b'] = 2
        $in['a']['b'] | Should -Be 1
    }

    It 'byte[] değerini bayt dizisi olarak bırakır' {
        $h = ConvertTo-Hashtable @{ blob = [byte[]](1, 2, 3) }
        , $h['blob'] | Should -BeOfType [byte[]]
        $h['blob'].Count | Should -Be 3
    }

    It '$null girdiyi $null döndürür' {
        $null -eq (ConvertTo-Hashtable $null) | Should -BeTrue
    }
}

Describe 'ConvertFrom-JsonText' {
    It 'en üst düzey tek elemanlı diziyi dizi olarak okur' {
        $r = ConvertFrom-JsonText '[5]'
        , $r | Should -BeOfType [System.Array]
        $r.Count | Should -Be 1
        $r[0] | Should -Be 5
    }

    It 'en üst düzey boş diziyi boş dizi olarak okur' {
        $r = ConvertFrom-JsonText '[]'
        $null -eq $r | Should -BeFalse
        , $r | Should -BeOfType [System.Array]
        $r.Count | Should -Be 0
    }

    It 'nesneyi hashtable olarak okur' {
        $r = ConvertFrom-JsonText '{"name":"x","list":[1,2],"o":{"k":[]}}'
        $r | Should -BeOfType [hashtable]
        $r['list'].Count | Should -Be 2
        $r['o']['k'].Count | Should -Be 0
    }

    It 'Türkçe karakterleri korur' {
        (ConvertFrom-JsonText '{"s":"Açılış sesini kapat ğüşiöç İ"}')['s'] | Should -Be 'Açılış sesini kapat ğüşiöç İ'
    }

    It 'geçersiz JSON için hata fırlatır' {
        { ConvertFrom-JsonText '{"a":' } | Should -Throw
        { ConvertFrom-JsonText '' } | Should -Throw
    }

    It 'sarmalayıcıyı bozan fazla içeriği reddeder' {
        { ConvertFrom-JsonText '1,"w":2' } | Should -Throw
    }
}

Describe 'ConvertTo-FaiRegistryValue / Test-FaiValueEqual' {
    It 'DWord: Int64 ve işaretsiz sınır değerlerini Int32 yapar' {
        (ConvertTo-FaiRegistryValue 5 'DWord') | Should -BeOfType [int]
        (ConvertTo-FaiRegistryValue ([long]4294967295) 'DWord') | Should -Be -1
    }

    It 'QWord: Int64 döndürür' {
        (ConvertTo-FaiRegistryValue 5 'QWord') | Should -BeOfType [long]
    }

    It 'MultiString ve Binary: dizi türünü kurar (JSON''dan Object[] gelse bile)' {
        $m = ConvertTo-FaiRegistryValue @('a', 'b') 'MultiString'
        , $m | Should -BeOfType [string[]]
        $b = ConvertTo-FaiRegistryValue @(1, 2, 255) 'Binary'
        , $b | Should -BeOfType [byte[]]
        $b.Count | Should -Be 3
    }

    It 'bilinmeyen tür için hata fırlatır' {
        { ConvertTo-FaiRegistryValue 1 'Nope' } | Should -Throw
    }

    It 'Test-FaiValueEqual: Int32 ile Int64 eşit, diziler eleman eleman, metin harf duyarlı' {
        Test-FaiValueEqual 5 ([long]5) | Should -BeTrue
        Test-FaiValueEqual @(1, 2) @(1, 2) | Should -BeTrue
        Test-FaiValueEqual @(1, 2) @(1, 3) | Should -BeFalse
        Test-FaiValueEqual @(1) @(1, 2) | Should -BeFalse
        Test-FaiValueEqual 'a' 'A' | Should -BeFalse
        Test-FaiValueEqual $null $null | Should -BeTrue
        Test-FaiValueEqual $null 0 | Should -BeFalse
    }
}
