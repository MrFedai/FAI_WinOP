# Tweak catalog

> Auto-generated: `pwsh -NoProfile -File build/TweaksDoc.ps1` (source: `tweaks/**/*.psd1`). Do not edit by hand.

Risk: **Safe** is applied directly · **⚠ Caution** asks for confirmation · **⛔ Risk** requires typing "YES" and is not applied in `-Unattended` mode.
Changes are listed with default parameters; a profile can override the parameters.

Tweaks generated from the profile are not files in the catalog: `app.<id>` (profile `apps`, `apps/catalog.json`), `gaming.per-game` (profile `games`: IFEO `CpuPriorityClass` + the `\FAI_WinOP\GameAffinity` startup task for processor affinity; masks come from the machine's processor count), `layout.profile` (profile `layout`), `updates.on` / `updates.off` (`-UpdatesOn` / `-UpdatesOff`). Format: `profiles/_schema.json`.

| Id | Title | Risk | Condition | Parameters |
| --- | --- | --- | --- | --- |
| [`bloat.edge-remove`](#bloatedge-remove) | Remove Microsoft Edge (WebView2 stays) | ⚠ Caution | — | — |
| [`bloat.persistence`](#bloatpersistence) | Keep removed apps from coming back | ⚠ Caution | — | — |
| [`bloat.remove`](#bloatremove) | Remove unnecessary Store apps | ⚠ Caution | — | — |
| [`graphics.amd-settings`](#graphicsamd-settings) | AMD: simplified Adrenalin and low latency | Safe | HasAmdGpu | — |
| [`graphics.nvidia-settings`](#graphicsnvidia-settings) | NVIDIA: tray icon and legacy sharpening off | Safe | HasNvidia | — |
| [`graphics.p0-state`](#graphicsp0-state) | NVIDIA: stay in the P0 power state | ⚠ Caution | HasNvidia | — |
| [`power.plan`](#powerplan) | Power plan: high performance on AC, balanced on battery | Safe | — | `hibernateOnBatterySec`, `sleepOnBatterySec` |
| [`privacy.app-permissions`](#privacyapp-permissions) | Turn off app permissions (camera and microphone stay on) | Safe | — | — |
| [`privacy.search-ads`](#privacysearch-ads) | Turn off search and Start ads | Safe | — | — |
| [`privacy.telemetry`](#privacytelemetry) | Minimize telemetry | Safe | — | — |
| [`refresh.reboot-to-bios`](#refreshreboot-to-bios) | Restart to UEFI (BIOS) settings | ⚠ Caution | — | `delay` |
| [`setup.background-apps-off`](#setupbackground-apps-off) | Turn off background apps (except an exception list) | Safe | — | `exceptions` |
| [`setup.default-browser`](#setupdefault-browser) | Default browser (via Settings) | ⚠ Caution | — | `appName`, `progId`, `scope` |
| [`setup.edition-pro`](#setupedition-pro) | Windows Home → Pro upgrade (via Settings) | ⚠ Caution | Edition Core | — |
| [`setup.mmagent-off`](#setupmmagent-off) | Turn off memory compression and prefetching | Safe | MinRamGB 16 | — |
| [`setup.store-optimize`](#setupstore-optimize) | Microsoft Store: automatic updates, video and personalization off | ⚠ Caution | — | — |
| [`setup.updates-staged`](#setupupdates-staged) | Windows Update: install pending first, then pause | ⚠ Caution | — | `pauseDays` |
| [`sound.startup-sound-off`](#soundstartup-sound-off) | Turn off the startup sound | Safe | — | — |
| [`sound.volume`](#soundvolume) | Set the volume level | Safe | — | `level` |
| [`system.restore-point`](#systemrestore-point) | System Restore point | Safe | — | `description` |
| [`system.timer-resolution`](#systemtimer-resolution) | Timer resolution 0.5 ms | Safe | — | `resolution` |
| [`ui.account-pictures-black`](#uiaccount-pictures-black) | Default account pictures black | Safe | — | — |
| [`ui.copilot-off`](#uicopilot-off) | Turn off Copilot | Safe | — | — |
| [`ui.explorer`](#uiexplorer) | File Explorer layout | Safe | — | — |
| [`ui.lockscreen-black`](#uilockscreen-black) | Lock and sign-in screen black | Safe | — | — |
| [`ui.notepad-settings`](#uinotepad-settings) | Notepad settings | Safe | — | `aiRewrite`, `openInNewWindow`, `restoreSession` |
| [`ui.notifications`](#uinotifications) | Turn off notifications (except an exception list) | ⚠ Caution | — | `exceptions` |
| [`ui.taskbar`](#uitaskbar) | Taskbar: buttons off, tray in overflow, only File Explorer + Chrome | Safe | — | — |
| [`ui.theme-black`](#uitheme-black) | Black theme (dark, transparency off, automatic accent, solid black wallpaper) | Safe | — | — |
| [`ui.visual-effects`](#uivisual-effects) | Reduce visual effects (font smoothing on) | Safe | — | — |
| [`ui.widgets-off`](#uiwidgets-off) | Turn off Widgets | Safe | — | — |

## bloat

### bloat.edge-remove

**Remove Microsoft Edge (WebView2 stays)** · Risk: ⚠ Caution

Removes Edge (Chromium) system-wide with its own installer. WebView2 Runtime and EdgeUpdate are left alone: apps that use WebView2, such as WhatsApp, keep working and WebView2 keeps updating. An EdgeUpdate policy blocks reinstalling Edge (Install{Edge}=0) while installing and updating WebView2 stays explicitly allowed. microsoft-edge: links (Settings, Widgets, search results) open in the default browser through a small redirect script; only http / https addresses are accepted. Limits: if Windows Update ships a separate Edge package, Edge can come back (the EdgeUpdate policy does not stop it); system components that call msedge.exe directly will not open; if the user choice (UserChoice) for microsoft-edge: was already bound to Edge, Windows may ask "how do you want to open this" once. Revert: the policy and the redirect are removed first, then Edge is reinstalled with winget.

Confirmation warning: Edge will be removed. Export favorites / passwords to Chrome first. WebView2 stays.

Changes (8):

- `Microsoft Edge is removed (WebView2 Runtime and its updater stay)`
- `Registry: HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate\Install{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062} = 0 (DWord)`
- `Registry: HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate\Install{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5} = 1 (DWord)`
- `Registry: HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate\Update{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5} = 1 (DWord)`
- `File: %ProgramData%\FAI_WinOP\EdgeRedirect.ps1 is written (563 characters, UTF8BOM)`
- `Registry: HKLM:\SOFTWARE\Classes\microsoft-edge\ = URL:microsoft-edge (String)`
- `Registry: HKLM:\SOFTWARE\Classes\microsoft-edge\URL Protocol =  (String)`
- `Registry: HKLM:\SOFTWARE\Classes\microsoft-edge\shell\open\command\ = "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "%ProgramData%\FAI_WinOP\EdgeRedirect.ps1" "%1" (ExpandString)`

### bloat.persistence

**Keep removed apps from coming back** · Risk: ⚠ Caution

Removes the provisioned copies of the packages in the bloat.remove list (so they are not reinstalled for new users or after updates), stops Windows from installing suggested / sponsored apps on its own (ContentDeliveryManager and CloudContent policy), and sets up a scheduled task (\\FAI\_WinOP\\BloatCleanup, SYSTEM) that, at startup, removes the same list again from all users if the Windows build number changed (major or monthly update); the task writes to %ProgramData%\\FAI\_WinOP\\BloatCleanup.log. The protected list and the profile's apps are excluded from the task script too. Removing provisioned packages cannot be undone: revert deletes the task and script and restores the settings; apps are reinstalled from the Store. The DisableWindowsConsumerFeatures policy is officially effective only on Enterprise / Education; on Pro the ContentDeliveryManager values do the real work.

Confirmation warning: Removing provisioned packages cannot be undone (reinstall the app from the Store if needed).

Changes (10):

- `Bloatware persistence: the provisioned copy of 44 packages is removed, startup task \FAI_WinOP\BloatCleanup repeats it after updates`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SilentInstalledAppsEnabled = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\PreInstalledAppsEnabled = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\PreInstalledAppsEverEnabled = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\OemPreInstalledAppsEnabled = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SubscribedContentEnabled = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\FeatureManagementEnabled = 0 (DWord)`
- `Registry: HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent\DisableWindowsConsumerFeatures = 1 (DWord)`
- `Registry: HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent\DisableConsumerAccountStateContent = 1 (DWord)`
- `Registry: HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent\DisableCloudOptimizedContent = 1 (DWord)`

### bloat.remove

**Remove unnecessary Store apps** · Risk: ⚠ Caution

Removes preinstalled Store apps from an explicit blocklist (no wildcards, each by package name) for the signed-in user. Before running, the installed ones are shown as a table and confirmation is requested. The protected list (src/Core/Bloat.ps1, Get-FaiBloatProtected) and the Appx names of the profile's apps (apps/catalog.json appxNames) are never removed: Store, winget (App Installer), Snipping Tool, WhatsApp, Claude, shell / system components, codecs, Photos, Paint, Notepad, Terminal, Calculator, Media Player, driver control panels, Xbox identity. Revert: while the provisioned copy stays on the machine the package is registered again; if bloat.persistence also removed the provisioned copy, revert warns and the app is reinstalled from the Store.

Confirmation warning: The apps above will be removed (they can be reinstalled from the Store).

Changes (44):

- `Appx: Clipchamp.Clipchamp is removed (user)`
- `Appx: Microsoft.549981C3F5F10 is removed (user)`
- `Appx: Microsoft.BingFinance is removed (user)`
- `Appx: Microsoft.BingNews is removed (user)`
- `Appx: Microsoft.BingSearch is removed (user)`
- `Appx: Microsoft.BingSports is removed (user)`
- `Appx: Microsoft.BingWeather is removed (user)`
- `Appx: Microsoft.Copilot is removed (user)`
- `Appx: Microsoft.GamingApp is removed (user)`
- `Appx: Microsoft.GetHelp is removed (user)`
- `Appx: Microsoft.Getstarted is removed (user)`
- `Appx: Microsoft.Messaging is removed (user)`
- `Appx: Microsoft.Microsoft3DViewer is removed (user)`
- `Appx: Microsoft.MicrosoftOfficeHub is removed (user)`
- `Appx: Microsoft.MicrosoftSolitaireCollection is removed (user)`
- `Appx: Microsoft.MicrosoftStickyNotes is removed (user)`
- `Appx: Microsoft.MixedReality.Portal is removed (user)`
- `Appx: Microsoft.MSPaint is removed (user)`
- `Appx: Microsoft.Office.OneNote is removed (user)`
- `Appx: Microsoft.OneConnect is removed (user)`
- `Appx: Microsoft.OutlookForWindows is removed (user)`
- `Appx: Microsoft.People is removed (user)`
- `Appx: Microsoft.PowerAutomateDesktop is removed (user)`
- `Appx: Microsoft.Print3D is removed (user)`
- `Appx: Microsoft.SkypeApp is removed (user)`
- `Appx: Microsoft.Todos is removed (user)`
- `Appx: Microsoft.Wallet is removed (user)`
- `Appx: Microsoft.Windows.DevHome is removed (user)`
- `Appx: Microsoft.WindowsAlarms is removed (user)`
- `Appx: Microsoft.WindowsFeedbackHub is removed (user)`
- `Appx: Microsoft.WindowsMaps is removed (user)`
- `Appx: Microsoft.WindowsSoundRecorder is removed (user)`
- `Appx: Microsoft.XboxApp is removed (user)`
- `Appx: Microsoft.YourPhone is removed (user)`
- `Appx: Microsoft.ZuneVideo is removed (user)`
- `Appx: MicrosoftCorporationII.QuickAssist is removed (user)`
- `Appx: MicrosoftTeams is removed (user)`
- `Appx: MSTeams is removed (user)`
- `Appx: 5A894077.McAfeeSecurity is removed (user)`
- `Appx: AmazonVideo.PrimeVideo is removed (user)`
- `Appx: BytedancePte.Ltd.TikTok is removed (user)`
- `Appx: Disney.37853FC22B2CE is removed (user)`
- `Appx: king.com.CandyCrushSaga is removed (user)`
- `Appx: king.com.CandyCrushSodaSaga is removed (user)`

## graphics

### graphics.amd-settings

**AMD: simplified Adrenalin and low latency** · Risk: Safe

AMD Software (Adrenalin) settings, registry only: automatic updates, system tray, web content, animations, notification bubbles and in-game overlay are off. In the class key of the display adapter whose provider is AMD, Radeon Anti-Lag is on (KMD\_DeLagEnabled=1); under UMD, vertical sync is always off, texture filtering quality is performance, and tessellation overrides the application setting; under power\_v1, Vari-Bright (abmlevel) is off. UMD values are UTF-16 text digits (e.g. 30 00 = "0"). Values were taken from the Ultimate reference and not verified on real AMD hardware; a driver update may reset some of them.

Condition: HasAmdGpu

Changes (12):

- `Registry: HKCU:\Software\AMD\CN\AutoUpdate = 0 (DWord)`
- `Registry: HKCU:\Software\AMD\CN\SystemTray = false (String)`
- `Registry: HKCU:\Software\AMD\CN\AllowWebContent = false (String)`
- `Registry: HKCU:\Software\AMD\CN\AnimationEffect = false (String)`
- `Registry: HKCU:\Software\AMD\CN\CN_Hide_Toast_Notification = true (String)`
- `Registry: HKCU:\Software\AMD\DVR\ShowRSOverlay = false (String)`
- `Registry: HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\*\KMD_DeLagEnabled = 1 (DWord) — only: [0-9][0-9][0-9][0-9] — ProviderName: Advanced Micro Devices* / AMD* / ATI*`
- `Registry: HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\*\UMD\VSyncControl = 48,0 (Binary) — only: [0-9][0-9][0-9][0-9] — ProviderName: Advanced Micro Devices* / AMD* / ATI*`
- `Registry: HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\*\UMD\TFQ = 50,0 (Binary) — only: [0-9][0-9][0-9][0-9] — ProviderName: Advanced Micro Devices* / AMD* / ATI*`
- `Registry: HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\*\UMD\Tessellation = 49,0 (Binary) — only: [0-9][0-9][0-9][0-9] — ProviderName: Advanced Micro Devices* / AMD* / ATI*`
- `Registry: HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\*\UMD\Tessellation_OPTION = 50,0 (Binary) — only: [0-9][0-9][0-9][0-9] — ProviderName: Advanced Micro Devices* / AMD* / ATI*`
- `Registry: HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\*\power_v1\abmlevel = 0,0,0,0 (Binary) — only: [0-9][0-9][0-9][0-9] — ProviderName: Advanced Micro Devices* / AMD* / ATI*`

### graphics.nvidia-settings

**NVIDIA: tray icon and legacy sharpening off** · Risk: Safe

NVIDIA settings that can be made with the registry alone: the NVIDIA tray icon does not start at sign-in (NvTray\\StartOnLogin=0) and the legacy image sharpening scaler is turned off (nvlddmkm FTS\\EnableGR535=0; written only if the FTS key created by the driver exists). Control Panel settings (low latency, power management, vertical sync, texture filtering…) live in the NVIDIA DRS database; since no unsigned third-party tool (Profile Inspector) is used, they are outside this tweak's scope (later, via NVAPI). Not verified on real NVIDIA hardware.

Condition: HasNvidia

Changes (3):

- `Registry: HKCU:\Software\NVIDIA Corporation\NvTray\StartOnLogin = 0 (DWord)`
- `Registry: HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\*\EnableGR535 = 0 (DWord) — only: FTS`
- `Registry: HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\*\FTS\EnableGR535 = 0 (DWord) — only: Parameters`

### graphics.p0-state

**NVIDIA: stay in the P0 power state** · Risk: ⚠ Caution

Turns off dynamic P-state switching on the NVIDIA GPU (DisableDynamicPstate=1): the card stays in the highest power state (P0) even when idle, which reduces latency spikes from clock drops. The value is written only to the display adapter class keys (0000, 0001…) whose provider is NVIDIA; Intel / AMD keys are not touched. On a laptop, battery life gets shorter and heat rises; for this reason confirmation is requested on every run (the profile's autoConfirm does not apply, and it is not applied with -Unattended). Takes effect when the driver is reloaded or after a restart. Note: the effect has not been measured on real hardware (Phase 9).

Confirmation warning: The GPU stays at full power even when idle: on a laptop, battery life gets shorter and heat rises.

Run: confirmation is asked on every run (autoConfirm does not apply, not applied in `-Unattended` mode)

Condition: HasNvidia

Changes (1):

- `Registry: HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\*\DisableDynamicPstate = 1 (DWord) — only: [0-9][0-9][0-9][0-9] — ProviderName: NVIDIA*`

## power

### power.plan

**Power plan: high performance on AC, balanced on battery** · Risk: Safe

Copies the tool's own power plan (FAI\_WinOP, fixed GUID) from Balanced and makes it active; the existence of any plan is not assumed (if Balanced was deleted, a copy of the active plan is used). On AC: processor minimum / maximum state 100%, core parking off (minimum cores 100%), cooling active, USB selective suspend and PCIe link state power management off, disk never turns off, wireless adapter at maximum performance, no sleep or hibernate. On battery (DC): Balanced defaults stay; sleep (sleepOnBatterySec, default 900 s) and hibernate (hibernateOnBatterySec, default 10800 s) are explicitly on. On a laptop, hibernate (powercfg /hibernate on) is also enabled. Display and brightness are not touched. Revert returns to the previous active plan and deletes the tool's plan.

Parameters (default): `hibernateOnBatterySec` = `10800` · `sleepOnBatterySec` = `900`

Changes (12):

- `Power plan 'FAI_WinOP' (46414900-5769-4e4f-9000-000000000001): if missing, created as a copy of 381b4222-f694-41f0-9685-ff5bb260df2e and activated`
- `Power: 46414900-5769-4e4f-9000-000000000001 / SUB_PROCESSOR / PROCTHROTTLEMIN → on AC = 100`
- `Power: 46414900-5769-4e4f-9000-000000000001 / SUB_PROCESSOR / PROCTHROTTLEMAX → on AC = 100`
- `Power: 46414900-5769-4e4f-9000-000000000001 / SUB_PROCESSOR / CPMINCORES → on AC = 100`
- `Power: 46414900-5769-4e4f-9000-000000000001 / SUB_PROCESSOR / SYSCOOLPOL → on AC = 1`
- `Power: 46414900-5769-4e4f-9000-000000000001 / 2a737441-1930-4402-8d77-b2bebba308a3 / 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 → on AC = 0`
- `Power: 46414900-5769-4e4f-9000-000000000001 / SUB_PCIEXPRESS / ASPM → on AC = 0`
- `Power: 46414900-5769-4e4f-9000-000000000001 / SUB_DISK / DISKIDLE → on AC = 0`
- `Power: 46414900-5769-4e4f-9000-000000000001 / 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 / 12bbebe6-58d6-4636-95bb-3217ef867c1a → on AC = 0`
- `Power: 46414900-5769-4e4f-9000-000000000001 / SUB_SLEEP / STANDBYIDLE → on AC = 0, on battery = 900`
- `Power: 46414900-5769-4e4f-9000-000000000001 / SUB_SLEEP / HIBERNATEIDLE → on AC = 0, on battery = 10800`
- `Hibernate is turned on`

## privacy

### privacy.app-permissions

**Turn off app permissions (camera and microphone stay on)** · Risk: Safe

Turns off, at the device level, the permissions under Settings \> Privacy & security \> App permissions: location, notification access, account info, contacts, calendar, phone calls, call history, email, tasks, messaging, radios, sync with other devices, app diagnostics, documents, pictures, videos, music, file system, text / image generation (AI models) and passkey listing. Camera and microphone stay on (device and user level). The permissions mostly affect Store (packaged) apps; for desktop apps only the location, camera and microphone permissions apply. While location is off, automatic time zone and Find my device do not work. On a version without a permission key (e.g. music, AI models) the value is still written but has no effect.

Changes (24):

- `Registry: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam\Value = Allow (String)`
- `Registry: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone\Value = Allow (String)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam\Value = Allow (String)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone\Value = Allow (String)`
- `Registry: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location\Value = Deny (String)`
- `Registry: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userNotificationListener\Value = Deny (String)`
- `Registry: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userAccountInformation\Value = Deny (String)`
- `Registry: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\contacts\Value = Deny (String)`
- `Registry: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\appointments\Value = Deny (String)`
- `Registry: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\phoneCall\Value = Deny (String)`
- `Registry: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\phoneCallHistory\Value = Deny (String)`
- `Registry: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\email\Value = Deny (String)`
- `Registry: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userDataTasks\Value = Deny (String)`
- `Registry: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\chat\Value = Deny (String)`
- `Registry: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\radios\Value = Deny (String)`
- `Registry: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\bluetoothSync\Value = Deny (String)`
- `Registry: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\appDiagnostics\Value = Deny (String)`
- `Registry: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\documentsLibrary\Value = Deny (String)`
- `Registry: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\picturesLibrary\Value = Deny (String)`
- `Registry: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\videosLibrary\Value = Deny (String)`
- `Registry: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\broadFileSystemAccess\Value = Deny (String)`
- `Registry: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\passkeysEnumeration\Value = Deny (String)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\musicLibrary\Value = Deny (String)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\systemAIModels\Value = Deny (String)`

### privacy.search-ads

**Turn off search and Start ads** · Risk: Safe

Turns off web (Bing) results and suggestions in Start search, search highlights (dynamic search box), Microsoft / work account cloud content search and device search history. Also turns off suggestions and account notifications in the Start menu, suggested content in the Settings app, and sync provider (OneDrive / Microsoft 365) promotions in File Explorer. Local file and app search keep working. For the change to take effect, Explorer may need to restart or you may need to sign out and back in.

Changes (15):

- `Registry: HKCU:\Software\Policies\Microsoft\Windows\Explorer\DisableSearchBoxSuggestions = 1 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\Search\BingSearchEnabled = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings\IsDynamicSearchBoxEnabled = 0 (DWord)`
- `Registry: HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search\EnableDynamicContentInWSB = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings\IsMSACloudSearchEnabled = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings\IsAADCloudSearchEnabled = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings\IsDeviceSearchHistoryEnabled = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SubscribedContent-338388Enabled = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SystemPaneSuggestionsEnabled = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\Start_IrisRecommendations = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\Start_AccountNotifications = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SubscribedContent-338393Enabled = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SubscribedContent-353694Enabled = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SubscribedContent-353696Enabled = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ShowSyncProviderNotifications = 0 (DWord)`

### privacy.telemetry

**Minimize telemetry** · Risk: Safe

Lowers diagnostic data to the lowest level the edition allows: telemetry policy, the DiagTrack (Connected User Experiences and Telemetry) and dmwappushservice services, CEIP / compatibility / disk diagnostic tasks, advertising ID, tailored experiences, feedback requests, error reporting, activity history, and ink and typing data submission. Edition difference: AllowTelemetry=0 (Security) is fully effective only on Enterprise, Education and Server; Home and Pro apply it as 1 (Required diagnostic data), so Required is the lowest policy level reachable on Home / Pro. On Home / Pro, what actually stops sending is turning off the DiagTrack service. The CEIPEnable and AITEnable policies may have no effect in newer versions and are written for older components. AllowTelemetry=0 cuts off Windows Insider flights (Insider builds get no updates). Windows Update, Store and Defender keep working; Settings shows "Some settings are managed by your organization". Do not use on a device managed with MDM / Intune (dmwappushservice carries registration messages).

Changes (30):

- `Registry: HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection\AllowTelemetry = 0 (DWord)`
- `Registry: HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection\DoNotShowFeedbackNotifications = 1 (DWord)`
- `Service: DiagTrack → start = Disabled, status = Stopped`
- `Service: dmwappushservice → start = Disabled, status = Stopped`
- `Registry: HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows\CEIPEnable = 0 (DWord)`
- `Registry: HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat\AITEnable = 0 (DWord)`
- `Registry: HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat\DisableInventory = 1 (DWord)`
- `Scheduled task: \Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser → disabled`
- `Scheduled task: \Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser Exp → disabled`
- `Scheduled task: \Microsoft\Windows\Application Experience\ProgramDataUpdater → disabled`
- `Scheduled task: \Microsoft\Windows\Application Experience\MareBackup → disabled`
- `Scheduled task: \Microsoft\Windows\Customer Experience Improvement Program\Consolidator → disabled`
- `Scheduled task: \Microsoft\Windows\Customer Experience Improvement Program\UsbCeip → disabled`
- `Scheduled task: \Microsoft\Windows\Autochk\Proxy → disabled`
- `Scheduled task: \Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector → disabled`
- `Scheduled task: \Microsoft\Windows\Feedback\Siuf\DmClient → disabled`
- `Scheduled task: \Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload → disabled`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo\Enabled = 0 (DWord)`
- `Registry: HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo\DisabledByGroupPolicy = 1 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy\TailoredExperiencesWithDiagnosticDataEnabled = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\CPSS\Store\TailoredExperiencesWithDiagnosticDataEnabled\Value = 0 (DWord)`
- `Registry: HKCU:\Software\Policies\Microsoft\Windows\CloudContent\DisableTailoredExperiencesWithDiagnosticData = 1 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Siuf\Rules\NumberOfSIUFInPeriod = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Siuf\Rules\PeriodInNanoSeconds is deleted`
- `Registry: HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting\Disabled = 1 (DWord)`
- `Registry: HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\Disabled = 1 (DWord)`
- `Registry: HKLM:\SOFTWARE\Policies\Microsoft\Windows\System\EnableActivityFeed = 0 (DWord)`
- `Registry: HKLM:\SOFTWARE\Policies\Microsoft\Windows\System\PublishUserActivities = 0 (DWord)`
- `Registry: HKLM:\SOFTWARE\Policies\Microsoft\Windows\System\UploadUserActivities = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Input\TIPC\Enabled = 0 (DWord)`

## refresh

### refresh.reboot-to-bios

**Restart to UEFI (BIOS) settings** · Risk: ⚠ Caution

Tool: restarts the computer in a few seconds directly into the UEFI firmware settings (shutdown /r /fw). It does not run automatically with a profile; only from the menu or with -Only, with confirmation. Save open documents. To cancel before the time runs out: shutdown /a. Not supported on legacy BIOS installs.

Confirmation warning: The computer will restart in a few seconds; unsaved work will be lost.

Run: tool: does not run automatically with a profile, only from the menu / with `-Only`

Parameters (default): `delay` = `10`

Changes (1):

- `Reboot to UEFI (BIOS) settings after 10 s`

## setup

### setup.background-apps-off

**Turn off background apps (except an exception list)** · Risk: Safe

With a privacy policy (AppPrivacy\\LetAppsRunInBackground=2, "force deny") Store / packaged apps are stopped from running in the background; the package family names in the exceptions parameter (default WhatsApp: 5319275A.WhatsAppDesktop\_cv1g1gvanyjgm) stay allowed through LetAppsRunInBackground\_ForceAllowTheseApps. The policy also covers apps installed later; the per-app option in Settings appears grayed out because of the policy. Win32 apps (e.g. Telegram Desktop installed with winget) are not affected by this setting, so they are not in the list. The user-wide switch (GlobalUserDisabled) was not used: it would turn off the exceptions too.

Parameters (default): `exceptions` = `5319275A.WhatsAppDesktop_cv1g1gvanyjgm`

Changes (2):

- `Registry: HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy\LetAppsRunInBackground = 2 (DWord)`
- `Registry: HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy\LetAppsRunInBackground_ForceAllowTheseApps = 5319275A.WhatsAppDesktop_cv1g1gvanyjgm (MultiString)`

### setup.default-browser

**Default browser (via Settings)** · Risk: ⚠ Caution

If the default browser for https is not appName, opens Settings \> Default apps for that app; the user clicks the "Set default" button, then the result is checked. Because of the Windows 11 UserChoice hash protection and the UCPD driver, there is no reliable programmatic way (docs/APPS.md). Not applied in non-interactive mode; revert is also done manually from the Settings page.

Confirmation warning: The Settings page will open; you need to click the "Set default" button yourself.

Parameters (default): `appName` = `Google Chrome` · `progId` = `ChromeHTML` · `scope` = `Machine`

Changes (1):

- `Default browser: Google Chrome (ChromeHTML) — one click in Settings, manual`

### setup.edition-pro

**Windows Home → Pro upgrade (via Settings)** · Risk: ⚠ Caution

Home (Core) edition only: opens the Settings \> Activation page; the upgrade to Pro is done with the user's own product key ("Change product key") or with an upgrade bought from the Microsoft Store. The tool contains no key, enters no generic / KMS key and performs no activation bypass (no pirated activation). Windows restarts at the end of the upgrade; once the edition is Pro, the tweak condition is not met and it is skipped. Not applied in non-interactive mode; there is no revert.

Confirmation warning: Settings \> Activation will open; you do the upgrade yourself with your own product key or from the Store.

Condition: Edition Core

Changes (1):

- `Settings opens (ms-settings:activation): Activation page opened: enter your own Pro key with "Change product key", or get the Pro upgrade from the Store. Windows restarts after the upgrade.`

### setup.mmagent-off

**Turn off memory compression and prefetching** · Risk: Safe

In the memory manager (MMAgent), memory compression, application launch prefetching (prefetch) and application preloading (PreLaunch) are turned off; also PrefetchParameters\\EnablePrefetcher=0. For machines with plenty of RAM (at least 16 GB): the CPU time spent on compression and background disk reads go away. Page combining and OperationAPI are not touched. Memory compression takes effect after a restart. Get-MMAgent needs the SysMain service to be running. Cost: EnablePrefetcher=0 also turns off boot prefetching, so boot and first app launches may take longer; on an NVMe SSD the gain is small. On a machine with Hyper-V enabled, Windows may reject the prefetch change ("The request is not supported"). Not in the fedai profile (Phase 9: it was observed to lengthen boot).

Condition: MinRamGB 16

Changes (4):

- `Memory manager: MemoryCompression → off`
- `Memory manager: ApplicationLaunchPrefetching → off`
- `Memory manager: ApplicationPreLaunch → off`
- `Registry: HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters\EnablePrefetcher = 0 (DWord)`

### setup.store-optimize

**Microsoft Store: automatic updates, video and personalization off** · Risk: ⚠ Caution

Automatic download and update of Store apps is turned off (WindowsStore\\WindowsUpdate\\AutoDownload=2); Store apps are updated with winget upgrade instead. In the Store's own settings (settings.dat), video autoplay, app install notifications and personalized experience are turned off. If the Store has never been opened, the settings file does not exist: those steps are skipped and applied on the first run after the Store has been opened once. If the Store is open while writing, it is closed.

Changes (4):

- `Registry: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate\AutoDownload = 2 (DWord)`
- `App setting: Microsoft.WindowsStore VideoAutoplay = False (Bool)`
- `App setting: Microsoft.WindowsStore EnableAppInstallNotifications = False (Bool)`
- `App setting: Microsoft.WindowsStore PersistentSettings\PersonalizationEnabled = False (Bool)`

### setup.updates-staged

**Windows Update: install pending first, then pause** · Risk: ⚠ Caution

First, all pending software updates (Windows Update Agent; drivers excluded) are downloaded and installed, with progress printed. If the installation asks for a restart, the run stops here: restart and run the profile again (if the CLI provides a ResumeCommand, it continues on its own through RunOnce); the remaining updates and the pause are done in that run. When none are pending, updates are paused for pauseDays (default 365) days: the pause values of Settings \> Windows Update (UX\\Settings, start / end in UTC). FlightSettingsMaxPauseDays is not written; how 365 days appears in Settings will be verified in a VM. -UpdatesOn / -UpdatesOff separately remove / re-apply the pause. -Undo removes the pause; installed updates are not rolled back. Security patches are paused too; a long pause can make an Insider build expire. Confirmation is requested on every run.

Confirmation warning: All updates, including security patches, are paused for 365 days; a long pause can make an Insider build expire.

Run: confirmation is asked on every run (autoConfirm does not apply, not applied in `-Unattended` mode)

Parameters (default): `pauseDays` = `365`

Changes (2):

- `Windows Update: all pending updates are installed`
- `Windows Update: paused for 365 days`

## sound

### sound.startup-sound-off

**Turn off the startup sound** · Risk: Safe

Turns off the Windows sign-in (startup) sound. Equivalent of the Settings \> Personalization \> Themes \> Sounds \> "Play Windows Startup sound" checkbox; two values are written together, one of which is read only on some versions.

Changes (2):

- `Registry: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\BootAnimation\DisableStartupSound = 1 (DWord)`
- `Registry: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\EditionOverrides\UserSetting_DisableStartupSound = 1 (DWord)`

### sound.volume

**Set the volume level** · Risk: Safe

Sets the level of the default audio output device to the level parameter (0-100, default 15). Skipped if there is no output device (server, virtual machine). If the device changes, the new device uses its own level.

Parameters (default): `level` = `15`

Changes (1):

- `Audio: default output → level = 15%`

## system

### system.restore-point

**System Restore point** · Risk: Safe

The first step (First) of every run: creates a System Restore point before the profile's apps and the other tweaks. Turns on System Protection if it is off on the system drive. Windows' once-per-24-hours point limit (SystemRestorePointCreationFrequency) is temporarily lifted during creation, then restored. -Undo does not delete the point; FAI\_WinOP has its own revert, so this point is a last resort (rstrui). Note: turning on System Protection / creating a point has not been verified on a real machine (VM).

Run: first step of every run (before apps)

Parameters (default): `description` = `FAI_WinOP`

Changes (1):

- `System Restore point: 'FAI_WinOP'`

### system.timer-resolution

**Timer resolution 0.5 ms** · Risk: Safe

Installs the FAI\_TimerResolution service (src/Native/TimerResolution.cs, starts automatically at boot) and sets the system timer to 0.5 ms (5000 × 100 ns). On Windows 11, a resolution requested by a process affects only that process; for a system-wide effect GlobalTimerResolutionRequests=1 is required (Session Manager\\kernel). May slightly increase power consumption on battery. -Undo removes the service and deletes the value.

Parameters (default): `resolution` = `5000`

Changes (2):

- `Registry: HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel\GlobalTimerResolutionRequests = 1 (DWord)`
- `Timer resolution service: 0.5 ms`

## ui

### ui.account-pictures-black

**Default account pictures black** · Risk: Safe

Windows' default user and guest pictures (the .png / .bmp files in %ProgramData%\\Microsoft\\User Account Pictures) are replaced with a plain black image of the same size; users who have not set their own account picture see a black circle in Start, on the sign-in screen and in Settings. Subfolders (users' own pictures) and the picture the user chose are not changed. The original files are backed up and revert writes them back exactly. The effect shows after signing in again.

Changes (1):

- `Image: %ProgramData%\Microsoft\User Account Pictures\*.png,*.bmp solid color #000000 (size is kept)`

### ui.copilot-off

**Turn off Copilot** · Risk: Safe

Windows Copilot is turned off by policy ("Turn off Windows Copilot", user and machine) and the Copilot button on the taskbar is hidden. The Copilot app itself is removed by bloat.remove (Microsoft.Copilot). In newer builds Copilot is a separate app, so the policy affects only the old integrated Copilot; the button and the app removal do the real work. Explorer restarts.

Changes (3):

- `Registry: HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot\TurnOffWindowsCopilot = 1 (DWord)`
- `Registry: HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot\TurnOffWindowsCopilot = 1 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ShowCopilotButton = 0 (DWord)`

### ui.explorer

**File Explorer layout** · Risk: Safe

File Explorer opens to This PC, file extensions are shown, and the title bar shows the full path. Gallery and Home are hidden in the navigation pane; 3D Objects is hidden from This PC (it does not exist on Windows 11 anyway; the action is only a safeguard). Home is hidden with the HubMode policy: Microsoft may change this behavior with updates, to be verified on real hardware (Phase 9). Navigation pane changes show after Explorer restarts.

Changes (6):

- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\LaunchTo = 1 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\HideFileExt = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState\FullPath = 1 (DWord)`
- `Registry: HKCU:\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}\System.IsPinnedToNameSpaceTree = 0 (DWord)`
- `Registry: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HubMode = 1 (DWord)`
- `Registry: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{31C0DD25-9439-4F12-BF41-7FF4EDA38722}\PropertyBag\ThisPCPolicy = Hide (String)`

### ui.lockscreen-black

**Lock and sign-in screen black** · Risk: Safe

A plain black image (C:\\ProgramData\\FAI\_WinOP\\Black.png, 1920x1080) is generated and assigned by policy (PersonalizationCSP) as the lock screen image; Windows Spotlight and lock screen tips are disabled by this image, and the user cannot change it from Settings. The blurred (acrylic) background on the sign-in screen is turned off, so the sign-in screen also looks black. The path is written assuming the system drive is C: (the policy value does not expand environment variables). The effect shows at the next lock.

Changes (5):

- `Image: C:\ProgramData\FAI_WinOP\Black.png solid color #000000 (1920x1080, existing size is kept)`
- `Registry: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP\LockScreenImagePath = C:\ProgramData\FAI_WinOP\Black.png (String)`
- `Registry: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP\LockScreenImageUrl = C:\ProgramData\FAI_WinOP\Black.png (String)`
- `Registry: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP\LockScreenImageStatus = 1 (DWord)`
- `Registry: HKLM:\SOFTWARE\Policies\Microsoft\Windows\System\DisableAcrylicBackgroundOnLogon = 1 (DWord)`

### ui.notepad-settings

**Notepad settings** · Risk: Safe

Notepad (Store version) is configured through its own settings file (settings.dat): files open in a new window (instead of a tab), the previous session is not restored at startup (unsaved tabs are not remembered), and rewriting with Copilot (AI) is off. Notepad is closed if it is open. The settings file is created the first time the app opens: if Notepad has never been opened, the tweak shows as "already set" and is applied on the next run. Value names and meanings depend on the Notepad version; to be verified on a real machine (Phase 9).

Parameters (default): `aiRewrite` = `False` · `openInNewWindow` = `1` · `restoreSession` = `False`

Changes (3):

- `App setting: Microsoft.WindowsNotepad OpenFile = 1 (Int32)`
- `App setting: Microsoft.WindowsNotepad GhostFile = False (Bool)`
- `App setting: Microsoft.WindowsNotepad RewriteEnabled = False (Bool)`

### ui.notifications

**Turn off notifications (except an exception list)** · Risk: ⚠ Caution

Notifications stay on globally, but every app and system component that sends notifications is turned off one by one; those that match the patterns in the exceptions parameter (-like, default \*WhatsApp\*, \*Telegram\*) stay on. Windows Security / Defender and Security and Maintenance notifications are always kept. Also turned off: the Windows welcome experience, suggestions to finish setting up, and tip / suggestion notifications. An app's notification entry is created with its first notification: an app installed later is turned off when the profile is run again.

Parameters (default): `exceptions` = `*WhatsApp*, *Telegram*`

Changes (10):

- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications\ToastEnabled = 1 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.Suggested\Enabled = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.StartupApp\Enabled = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Microsoft.SkyDrive.Desktop\Enabled = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\windows.immersivecontrolpanel_cw5n1h2txyewy!microsoft.windows.immersivecontrolpanel\Enabled = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\*\Enabled = 0 (DWord) — excluding: Windows.Defender*, *SecHealthUI*, Windows.SystemToast.SecurityAndMaintenance, *WhatsApp*, *Telegram*`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SubscribedContent-310093Enabled = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SubscribedContent-338389Enabled = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SoftLandingEnabled = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement\ScoobeSystemSettingEnabled = 0 (DWord)`

### ui.taskbar

**Taskbar: buttons off, tray in overflow, only File Explorer + Chrome** · Risk: Safe

The Search box, Task View and Chat buttons are removed (the Widgets button by ui.widgets-off, the Copilot button by ui.copilot-off). Alignment and auto-hide are not set in this tweak but by the profile's layout.taskbar.alignment / autoHide (single source; -ExportLayout captures them). In the notification area only the overflow arrow and system icons (Wi-Fi, volume, battery) remain: app icons move to the overflow menu, and apps that arrive later also land there with Windows' default. Pins are only File Explorer and Google Chrome (the others are removed; the Windows "Start Layout" policy is used once, after which the user can pin whatever they like). If Chrome is not installed, only Explorer is pinned and Chrome is added on the next run. Explorer restarts; without an interactive session (CI) the pinning step cannot be applied.

Changes (5):

- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\Search\SearchboxTaskbarMode = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ShowTaskViewButton = 0 (DWord)`
- `Registry: HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Chat\ChatIcon = 3 (DWord)`
- `Registry: HKCU:\Control Panel\NotifyIconSettings\*\IsPromoted = 0 (DWord)`
- `Taskbar pins only: Microsoft.Windows.Explorer, Google Chrome.lnk`

### ui.theme-black

**Black theme (dark, transparency off, automatic accent, solid black wallpaper)** · Risk: Safe

Apps and Windows switch to dark mode and transparency effects are turned off. The accent color is Automatic (from the wallpaper; on solid black, the Windows default) and is not shown on Start / taskbar and window title bars: surfaces stay in dark mode's own dark gray. The wallpaper is removed and the desktop becomes a solid black color (Personalize \> Background: Solid color). Changes are broadcast immediately; some apps turn dark when reopened.

Changes (9):

- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize\AppsUseLightTheme = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize\SystemUsesLightTheme = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize\EnableTransparency = 0 (DWord)`
- `Registry: HKCU:\Control Panel\Desktop\AutoColorization = 1 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize\ColorPrevalence = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\DWM\ColorPrevalence = 0 (DWord)`
- `Registry: HKCU:\Control Panel\Desktop\WallPaper =  (String)`
- `Registry: HKCU:\Control Panel\Colors\Background = 0 0 0 (String)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers\BackgroundType = 1 (DWord)`

### ui.visual-effects

**Reduce visual effects (font smoothing on)** · Risk: Safe

System \> Advanced system settings \> Performance Options is set to "Custom": menu / tooltip fade and slide animations, combo box and list box scrolling animations, mouse pointer and window shadows, icon label shadows, translucent selection rectangle, window minimize / maximize animations and taskbar animations are turned off. Smoothing the edges of screen fonts (ClearType) and thumbnail previews stay on; window contents keep showing while dragging. UserPreferencesMask is a binary (REG\_BINARY) value; changes take full effect after signing out and back in.

Changes (8):

- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\VisualFXSetting = 3 (DWord)`
- `Registry: HKCU:\Control Panel\Desktop\UserPreferencesMask = 144,18,3,128,16,0,0,0 (Binary)`
- `Registry: HKCU:\Control Panel\Desktop\WindowMetrics\MinAnimate = 0 (String)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarAnimations = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ListviewAlphaSelect = 0 (DWord)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ListviewShadow = 0 (DWord)`
- `Registry: HKCU:\Control Panel\Desktop\FontSmoothing = 2 (String)`
- `Registry: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\IconsOnly = 0 (DWord)`

### ui.widgets-off

**Turn off Widgets** · Risk: Safe

The Widgets app (MicrosoftWindows.Client.WebExperience) is removed for this user: the board and its taskbar button go with it. The policy path ("Allow widgets" = Disabled, Policies\\Microsoft\\Dsh) cannot be written even as administrator in newer builds because of the UCPD driver; the taskbar value (TaskbarDa) is also protected. The package is not needed by the shell; it is an exception by exact name in the protected list (MicrosoftWindows.Client.\*). The provisioned copy stays: the board appears for new users, and revert registers the package again. The legacy Windows 10 News and interests policy (Windows Feeds\\\\EnableFeeds) is also under UCPD protection and has no effect on Windows 11: it is not written. Explorer restarts.

Changes (1):

- `Appx: MicrosoftWindows.Client.WebExperience is removed (user)`
