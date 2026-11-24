# DefaultBrowserAction: varsayılan tarayıcıyı denetler; değilse Ayarlar'da uygulamanın "Varsayılan uygulamalar" sayfasını
# açar ve kullanıcının "Varsayılan olarak ayarla"ya basmasını bekler. Yalnız $Ctx sağlayıcılarıyla.
#
#   @{ Type='DefaultBrowser'; ProgId='ChromeHTML'; AppName='Google Chrome'; Scope='Machine' }
#
# Neden programla değil: Windows 11'de http/https UserChoice anahtarı karma (Hash) ile imzalı ve UCPD sürücüsü
# (UserChoice Protection Driver) bu anahtarlara Microsoft dışı süreçlerin yazmasını engelliyor. Güvenilir ve desteklenen
# tek yol Ayarlar'daki tek tık düğmesi (ayrıntı: docs/APPS.md).
# AppName: uygulamanın RegisteredApplications adı; Scope: Machine (makine geneli kurulum, ör. Chrome MSI) | User.
# Okuma: HKCU ...\UrlAssociations\https\UserChoiceLatest\ProgId (24H2+), yoksa ...\https\UserChoice.
# Etkileşimsiz kipte uygulanamaz (sayfa açılır, eylem hata verir). Geri alma da elle: önceki tarayıcı farklıysa
# Varsayılan uygulamalar sayfası açılır ve uyarı yazılır (hata değil).

class DefaultBrowserAction : ActionBase {
    static [string] $AssocPath = 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https'

    DefaultBrowserAction([hashtable] $Definition) : base($Definition) { }

    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        foreach ($m in (Get-FaiUnknownKeyError $Def @('Type', 'ProgId', 'AppName', 'Scope'))) { $e.Add($m) }
        if (-not $Def.Contains('ProgId')) { $e.Add('ProgId: zorunlu alan eksik') }
        elseif (Test-FaiHasPlaceholder $Def['ProgId']) { }
        elseif ($Def['ProgId'] -isnot [string] -or $Def['ProgId'] -notmatch '^[A-Za-z0-9][A-Za-z0-9._\-]*$') { $e.Add('ProgId: ProgID olmalı (ör. ChromeHTML)') }
        if (-not $Def.Contains('AppName')) { $e.Add('AppName: zorunlu alan eksik') }
        elseif ($Def['AppName'] -isnot [string] -or [string]::IsNullOrWhiteSpace($Def['AppName'])) { $e.Add('AppName: boş olmayan metin olmalı') }
        if ($Def.Contains('Scope') -and -not (Test-FaiHasPlaceholder $Def['Scope']) -and ($Def['Scope'] -isnot [string] -or @('Machine', 'User') -cnotcontains $Def['Scope'])) {
            $e.Add('Scope: Machine ya da User olmalı')
        }
        return $e.ToArray()
    }

    [string] ProgId() { return [string]$this.Definition['ProgId'] }

    [string] AppName() { return [string]$this.Definition['AppName'] }

    [string] SettingsUri() {
        $scope = 'Machine'
        if ($this.Definition.ContainsKey('Scope')) { $scope = [string]$this.Definition['Scope'] }
        return ('ms-settings:defaultapps?registeredApp{0}={1}' -f $scope, [Uri]::EscapeDataString($this.AppName()))
    }

    # Şu anki https işleyicisinin ProgID'si; okunamazsa boş metin.
    static [string] Current([ExecutionContext] $Ctx) {
        $base = [DefaultBrowserAction]::AssocPath
        $latest = $Ctx.Registry.GetValue("$base\UserChoiceLatest\ProgId", 'ProgId')
        if ($latest) { return [string]$latest }
        $classic = $Ctx.Registry.GetValue("$base\UserChoice", 'ProgId')
        if ($classic) { return [string]$classic }
        return ''
    }

    [bool] Test([ExecutionContext] $Ctx) { return ([DefaultBrowserAction]::Current($Ctx) -eq $this.ProgId()) }

    [hashtable] Snapshot([ExecutionContext] $Ctx) { return @{ ProgId = [DefaultBrowserAction]::Current($Ctx) } }

    [void] Apply([ExecutionContext] $Ctx) {
        $Ctx.Shell.OpenUri($this.SettingsUri())
        $hint = "Ayarlar'da '{0}' sayfası açıldı: 'Varsayılan olarak ayarla' düğmesine basın." -f $this.AppName()
        if ($Ctx.Unattended) { throw "Etkileşimsiz kipte yapılamaz. $hint" }
        [void]$Ctx.Prompt.Confirm("$hint Bitirince E yazın.")
        $now = [DefaultBrowserAction]::Current($Ctx)
        if ($now -ne $this.ProgId()) { throw ("Varsayılan tarayıcı değişmedi (şu an: '{0}', beklenen: '{1}')." -f $now, $this.ProgId()) }
    }

    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        $was = [string]$Snapshot['ProgId']
        if (-not $was -or $was -eq [DefaultBrowserAction]::Current($Ctx)) { return }
        $Ctx.Shell.OpenUri('ms-settings:defaultapps')
        $Ctx.Logger.Warn(("Varsayılan tarayıcı programla geri alınamaz: önceki tarayıcıyı ('{0}') Varsayılan uygulamalar sayfasından seçin." -f $was))
    }

    [string] Describe() { return ("Varsayılan tarayıcı: {0} ({1}) — Ayarlar'da tek tıkla, elle" -f $this.AppName(), $this.ProgId()) }

    [string] Preview([ExecutionContext] $Ctx) {
        $now = [DefaultBrowserAction]::Current($Ctx)
        if (-not $now) { $now = 'bilinmiyor' }
        return ('{0} [şu an: {1}]' -f $this.Describe(), $now)
    }
}
