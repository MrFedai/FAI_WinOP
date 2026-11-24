<#
.SYNOPSIS
    docs/TWEAKS.md katalog belgesini tweaks/ altındaki .psd1 dosyalarından üretir.

.DESCRIPTION
    Parametresiz çağrı: üretim bundle'ını geçici klasöre kurar, tweak kataloğunu yükler (şema doğrulaması dahil),
    docs/TWEAKS.md'yi yazar ve ne yaptığını basar. Çıktı kararlıdır (sıralı); içerik değişmediyse dosyaya dokunmaz.
    Geçersiz tweak dosyası varsa alan yoluyla hata verir ve belge yazılmaz.

.PARAMETER Check
    Yalnız denetler: belge güncel değilse 1 ile çıkar (CI). Dosya yazılmaz.

.EXAMPLE
    pwsh -NoProfile -File build/TweaksDoc.ps1
    pwsh -NoProfile -File build/TweaksDoc.ps1 -Check
#>
[CmdletBinding()]
param([switch] $Check)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$outFile = Join-Path (Join-Path $repoRoot 'docs') 'TWEAKS.md'

# Bundle'daki sınıflar yalnız nokta-kaynak yapılan kapsamda görünür.
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('fai-tweaksdoc-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
    $bundle = Join-Path $tmp 'install.ps1'
    & (Join-Path $PSScriptRoot 'Bundle.ps1') -OutFile $bundle 6>&1 | Out-Null
    . $bundle
    $catalog = Import-FaiTweakCatalog -Path (Join-Path $repoRoot 'tweaks')
}
finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }

function ConvertTo-MdText([string] $Text) {
    # Düz metindeki Markdown işaretleri (ör. '*WhatsApp*' italik olmasın).
    return ($Text -replace '([\\*_`|<>\[\]])', '\$1')
}

function Format-ParamValue([object] $Value) {
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        return '`' + ((@($Value) | ForEach-Object { [string]$_ }) -join ', ') + '`'
    }
    return '`' + [string]$Value + '`'
}

$riskLabel = @{ Safe = 'Safe'; Caution = '⚠ Caution'; Risk = '⛔ Risk' }
$ids = @($catalog.Keys | Sort-Object)
$categories = @($ids | ForEach-Object { $catalog[$_].Category } | Sort-Object -Unique)
$actionCount = 0
$lines = New-Object 'System.Collections.Generic.List[string]'
$lines.Add('# Tweak kataloğu')
$lines.Add('')
$lines.Add('> Otomatik üretilir: `pwsh -NoProfile -File build/TweaksDoc.ps1` (kaynak: `tweaks/**/*.psd1`). Elle düzenlemeyin.')
$lines.Add('')
$lines.Add('Risk: **Safe** doğrudan uygulanır · **⚠ Caution** onay ister · **⛔ Risk** "EVET" yazılmasını ister, `-Unattended` kipte uygulanmaz.')
$lines.Add('Değişiklikler varsayılan parametrelerle listelenir; profil parametreleri geçersiz kılabilir.')
$lines.Add('')
$lines.Add('| Id | Başlık | Risk | Koşul | Parametre |')
$lines.Add('| --- | --- | --- | --- | --- |')
foreach ($id in $ids) {
    $t = $catalog[$id]
    $cond = '—'
    if ($t.Conditions.Count -gt 0) { $cond = (@($t.Conditions | ForEach-Object { $_.Describe() }) -join ', ') }
    $par = '—'
    if ($t.Params.Count -gt 0) { $par = (@($t.Params.Keys | Sort-Object | ForEach-Object { '`' + $_ + '`' }) -join ', ') }
    $anchor = $id -replace '[^a-z0-9-]', ''
    $lines.Add(('| [`{0}`](#{1}) | {2} | {3} | {4} | {5} |' -f $id, $anchor, (ConvertTo-MdText $t.Title), $riskLabel[$t.Risk], (ConvertTo-MdText $cond), $par))
}

foreach ($cat in $categories) {
    $lines.Add('')
    $lines.Add("## $cat")
    foreach ($id in @($ids | Where-Object { $catalog[$_].Category -eq $cat })) {
        $t = $catalog[$id]
        $lines.Add('')
        $lines.Add("### $id")
        $lines.Add('')
        $lines.Add('**' + (ConvertTo-MdText $t.Title) + '** · Risk: ' + $riskLabel[$t.Risk])
        $lines.Add('')
        $lines.Add((ConvertTo-MdText $t.Description))
        if ($t.Confirm) {
            $lines.Add('')
            $lines.Add('Onay uyarısı: ' + (ConvertTo-MdText $t.Confirm))
        }
        $flags = New-Object 'System.Collections.Generic.List[string]'
        if ($t.First) { $flags.Add('her çalıştırmada ilk adım (uygulamalardan önce)') }
        if ($t.AlwaysConfirm) { $flags.Add('onay her çalıştırmada sorulur (autoConfirm işlemez, `-Unattended` kipte uygulanmaz)') }
        if ($t.Tool) { $flags.Add('araç: profille otomatik çalışmaz, menüden / `-Only` ile') }
        if ($flags.Count -gt 0) {
            $lines.Add('')
            $lines.Add('Çalışma: ' + ($flags -join ' · '))
        }
        if ($t.Conditions.Count -gt 0) {
            $lines.Add('')
            $lines.Add('Koşul: ' + (ConvertTo-MdText ((@($t.Conditions | ForEach-Object { $_.Describe() })) -join ' ve ')))
        }
        if ($t.Params.Count -gt 0) {
            $lines.Add('')
            $lines.Add('Parametreler (varsayılan): ' + ((@($t.Params.Keys | Sort-Object | ForEach-Object { '`' + $_ + '` = ' + (Format-ParamValue $t.Params[$_]) })) -join ' · '))
        }
        $lines.Add('')
        $lines.Add(('Değişiklikler ({0}):' -f $t.Actions.Count))
        $lines.Add('')
        foreach ($a in $t.Actions) {
            $lines.Add('- `' + ($a.Describe() -replace '`', "'") + '`')
            $actionCount++
        }
    }
}
$content = ($lines -join "`n") + "`n"

$current = $null
if (Test-Path -LiteralPath $outFile) { $current = [System.IO.File]::ReadAllText($outFile) -replace "`r`n", "`n" }
$upToDate = ($current -ceq $content)
$summary = '{0} tweak, {1} kategori, {2} eylem' -f $ids.Count, $categories.Count, $actionCount

if ($Check) {
    if ($upToDate) { Write-Host "docs/TWEAKS.md güncel ($summary)."; exit 0 }
    Write-Host "docs/TWEAKS.md güncel değil: 'pwsh -NoProfile -File build/TweaksDoc.ps1' çalıştırıp commit edin." -ForegroundColor Red
    exit 1
}
if ($upToDate) { Write-Host "docs/TWEAKS.md zaten güncel ($summary)."; exit 0 }
# .md: UTF-8 BOM'suz, LF (.gitattributes).
[System.IO.File]::WriteAllText($outFile, $content, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "docs/TWEAKS.md yazıldı ($summary)."
