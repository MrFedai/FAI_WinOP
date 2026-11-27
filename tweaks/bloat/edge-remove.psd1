@{
    Id          = 'bloat.edge-remove'
    Title       = 'Remove Microsoft Edge (WebView2 stays)'
    Description = 'Removes Edge (Chromium) system-wide with its own installer. WebView2 Runtime and EdgeUpdate are left alone: apps that use WebView2, such as WhatsApp, keep working and WebView2 keeps updating. An EdgeUpdate policy blocks reinstalling Edge (Install{Edge}=0) while installing and updating WebView2 stays explicitly allowed. microsoft-edge: links (Settings, Widgets, search results) open in the default browser through a small redirect script; only http / https addresses are accepted. Limits: if Windows Update ships a separate Edge package, Edge can come back (the EdgeUpdate policy does not stop it); system components that call msedge.exe directly will not open; if the user choice (UserChoice) for microsoft-edge: was already bound to Edge, Windows may ask "how do you want to open this" once. Revert: the policy and the redirect are removed first, then Edge is reinstalled with winget.'
    Category    = 'bloat'
    Risk        = 'Caution'
    Confirm     = 'Edge will be removed. Export favorites / passwords to Chrome first. WebView2 stays.'
    Actions     = @(
        # Kaldırma ilk adım: geri alma ters sırada çalışır, Install{Edge}=0 ilkesi kalkmadan Edge kurulamaz.
        @{ Type = 'EdgeRemove' }
        # EdgeUpdate ilkesi: Edge (Stable) kurulamaz; WebView2 Runtime kurulabilir ve her zaman güncellenir.
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate'; Name = 'Install{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}'; Value = 0; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate'; Name = 'Install{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'; Value = 1; Kind = 'DWord' }
        @{ Type = 'Registry'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate'; Name = 'Update{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'; Value = 1; Kind = 'DWord' }
        # microsoft-edge: → varsayılan tarayıcı
        @{ Type = 'File'; Path = '%ProgramData%\FAI_WinOP\EdgeRedirect.ps1'; Encoding = 'UTF8BOM'; Content = @'
# FAI_WinOP bloat.edge-remove: opens microsoft-edge: links in the default browser. http / https only.
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
