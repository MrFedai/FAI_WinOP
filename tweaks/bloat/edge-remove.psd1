@{
    Id          = 'bloat.edge-remove'
    Title       = 'Microsoft Edge''i kaldır (WebView2 kalır)'
    Description = 'Edge''i (Chromium) kendi kurucusuyla sistem düzeyinde kaldırır. WebView2 Runtime''a ve EdgeUpdate''e dokunmaz: WhatsApp gibi WebView2 kullanan uygulamalar çalışmaya, WebView2 güncellenmeye devam eder. EdgeUpdate ilkesiyle Edge''in yeniden kurulması engellenir (Install{Edge}=0), WebView2''nin kurulması ve güncellenmesi açıkça izinli kalır. microsoft-edge: bağlantıları (Ayarlar, Widget''lar, arama sonuçları) küçük bir yönlendirme betiğiyle varsayılan tarayıcıda açılır; yalnız http / https adresi kabul edilir. Sınırlar: Windows Update ayrı bir Edge paketi gönderirse Edge geri gelebilir (EdgeUpdate ilkesi onu durdurmaz); msedge.exe''yi doğrudan çağıran sistem bileşenleri açılmaz; microsoft-edge: için kullanıcı seçimi (UserChoice) önceden Edge''e bağlıysa Windows bir kez "nasıl açılsın" sorabilir. Geri alma: önce ilke ve yönlendirme kalkar, sonra Edge winget ile yeniden kurulur.'
    Category    = 'bloat'
    Risk        = 'Caution'
    Confirm     = 'Edge kaldırılacak. Sık kullanılanları / parolaları önce Chrome''a aktarın. WebView2 kalır.'
    Actions     = @(
        # Kaldırma ilk adım: geri alma ters sırada çalışır, Install{Edge}=0 ilkesi kalkmadan Edge kurulamaz.
        @{ Type = 'EdgeRemove' }
        # EdgeUpdate ilkesi: Edge (Stable) kurulamaz; WebView2 Runtime kurulabilir ve her zaman güncellenir.
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate'; Name = 'Install{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate'; Name = 'Install{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'; Value = 1; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate'; Name = 'Update{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'; Value = 1; Kind = 'DWord' }
        # microsoft-edge: → varsayılan tarayıcı
        @{ Type = 'File'; Path = '%ProgramData%\FAI_WinOP\EdgeRedirect.ps1'; Encoding = 'UTF8BOM'; Content = @'
# FAI_WinOP bloat.edge-remove: microsoft-edge: bağlantısını varsayılan tarayıcıda açar. Yalnız http / https.
#   microsoft-edge:https://site/yol  ·  microsoft-edge:?url=https%3A%2F%2Fsite%2F&launchContext1=...
param([string] $Uri = '', [switch] $Print)
$target = ($Uri -replace '^microsoft-edge:', '').Trim().Trim('"')
if ($target -notmatch '^https?://' -and $target -match '[?&]url=([^&]+)') { $target = [Uri]::UnescapeDataString($Matches[1]) }
if ($target -notmatch '^https?://[^\s"]+$') { exit 1 }
if ($Print) { return $target }
Start-Process -FilePath $target
'@ }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Classes\microsoft-edge'; Name = ''; Value = 'URL:microsoft-edge'; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Classes\microsoft-edge'; Name = 'URL Protocol'; Value = ''; Kind = 'String' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Classes\microsoft-edge\shell\open\command'; Name = ''; Kind = 'ExpandString'
            Value = '"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "%ProgramData%\FAI_WinOP\EdgeRedirect.ps1" "%1"'
        }
    )
}
