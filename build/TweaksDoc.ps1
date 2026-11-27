<#
.SYNOPSIS
    Generates the docs/TWEAKS.md catalog document from the .psd1 files under tweaks/.

.DESCRIPTION
    Called without parameters: builds the production bundle in a temporary folder, loads the tweak catalog (including
    schema validation), writes docs/TWEAKS.md and prints what it did. The output is stable (sorted); if the content
    did not change, the file is not touched. If a tweak file is invalid, it fails with the field path and no document is written.

.PARAMETER Check
    Check only: exits with 1 if the document is out of date (CI). No file is written.

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
$lines.Add('# Tweak catalog')
$lines.Add('')
$lines.Add('> Auto-generated: `pwsh -NoProfile -File build/TweaksDoc.ps1` (source: `tweaks/**/*.psd1`). Do not edit by hand.')
$lines.Add('')
$lines.Add('Risk: **Safe** is applied directly · **⚠ Caution** asks for confirmation · **⛔ Risk** requires typing "YES" and is not applied in `-Unattended` mode.')
$lines.Add('Changes are listed with default parameters; a profile can override the parameters.')
$lines.Add('')
$lines.Add('Tweaks generated from the profile are not files in the catalog: `app.<id>` (profile `apps`, `apps/catalog.json`), `gaming.per-game` (profile `games`: IFEO `CpuPriorityClass` + the `\FAI_WinOP\GameAffinity` startup task for processor affinity; masks come from the machine''s processor count), `layout.profile` (profile `layout`), `updates.on` / `updates.off` (`-UpdatesOn` / `-UpdatesOff`). Format: `profiles/_schema.json`.')
$lines.Add('')
$lines.Add('| Id | Title | Risk | Condition | Parameters |')
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
            $lines.Add('Confirmation warning: ' + (ConvertTo-MdText $t.Confirm))
        }
        $flags = New-Object 'System.Collections.Generic.List[string]'
        if ($t.First) { $flags.Add('first step of every run (before apps)') }
        if ($t.AlwaysConfirm) { $flags.Add('confirmation is asked on every run (autoConfirm does not apply, not applied in `-Unattended` mode)') }
        if ($t.Tool) { $flags.Add('tool: does not run automatically with a profile, only from the menu / with `-Only`') }
        if ($flags.Count -gt 0) {
            $lines.Add('')
            $lines.Add('Run: ' + ($flags -join ' · '))
        }
        if ($t.Conditions.Count -gt 0) {
            $lines.Add('')
            $lines.Add('Condition: ' + (ConvertTo-MdText ((@($t.Conditions | ForEach-Object { $_.Describe() })) -join ' and ')))
        }
        if ($t.Params.Count -gt 0) {
            $lines.Add('')
            $lines.Add('Parameters (default): ' + ((@($t.Params.Keys | Sort-Object | ForEach-Object { '`' + $_ + '` = ' + (Format-ParamValue $t.Params[$_]) })) -join ' · '))
        }
        $lines.Add('')
        $lines.Add(('Changes ({0}):' -f $t.Actions.Count))
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
$summary = '{0} tweaks, {1} categories, {2} actions' -f $ids.Count, $categories.Count, $actionCount

if ($Check) {
    if ($upToDate) { Write-Host "docs/TWEAKS.md is up to date ($summary)."; exit 0 }
    Write-Host "docs/TWEAKS.md is out of date: run 'pwsh -NoProfile -File build/TweaksDoc.ps1' and commit." -ForegroundColor Red
    exit 1
}
if ($upToDate) { Write-Host "docs/TWEAKS.md is already up to date ($summary)."; exit 0 }
# .md: UTF-8 BOM'suz, LF (.gitattributes).
[System.IO.File]::WriteAllText($outFile, $content, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "docs/TWEAKS.md written ($summary)."
