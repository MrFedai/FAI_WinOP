# App catalog and installation (Phase 4)

Source: [`apps/catalog.json`](../apps/catalog.json) (format: [`apps/_schema.json`](../apps/_schema.json), validation in
`src/Core/AppCatalog.ps1`). The profile's `apps` list gives IDs; the engine handles each app **before** the tweaks as an
`app.<id>` tweak (the notification exception and the taskbar pin need an installed app) (dry-run, report, snapshot, `-Undo` all use the same path).

```json
"apps": [ "chrome", "spotify", { "id": "telegram", "keepAutostart": true } ]
```

## Post-install rules

| Field | What it does |
| --- | --- |
| `removeAutostart` + `startupRegistryNames` / `startupFolderNames` | The Run value or the Startup folder shortcut is **not deleted**; like Task Manager's "Disable", a disabled marker (`03…`) is written under `Explorer\StartupApproved`. It stays disabled even if the app rewrites its Run value, and the user can enable it from Task Manager. A name without wildcards is disabled in HKCU in advance, even before the value exists (for apps that write it on first launch). |
| `startupTaskNames` | Disables the scheduled task that starts the app at sign-in. |
| `removeDesktopShortcut` + `desktopShortcutNames` | **Every** `.lnk` added to the user / public desktop during installation is deleted (before / after comparison); those whose name is in the list are deleted on every run (ones that come back with updates). |
| `quietUninstall` (`{ path, args }`, app level) | Silent uninstaller that runs instead of winget on revert. For installers whose uninstall entry has no silent command (winget starts them interactively): Steam. |
| `flattenStartMenu` + `startMenuFolders` | The shortcuts of the folder under Start > Programs are moved to the root, uninstall shortcuts and `.url` files are deleted, and the empty folder is deleted. |
| `keepAutostart` in the profile | The app's autostart rule is not applied (fedai: WhatsApp, Telegram). |

Revert (`-Undo`): before touching any file / value / task, the action writes its old state to the session log. If the app
was installed in that run, it is uninstalled and everything we moved / wrote is deleted; if it was already installed, the deleted
shortcuts, the moved folder and the StartupApproved values come back exactly.

Known limit: Electron apps (Discord, Claude) can set `StartupApproved` back to "enabled" when their "launch at startup"
setting is on. It is turned off again when the profile is run again; the lasting fix is the app's own setting.

## Package IDs

All 12 IDs were verified on 2026-11-24 with `winget show --id <id> --exact --source <source>` (winget 1.29).
Re-verification: [`tests/Integration/App-Ids.ps1`](../tests/Integration/App-Ids.ps1) (read-only; runs on every push in
Windows CI).

| id | Package | Source | Installer |
| --- | --- | --- | --- |
| claude | `Anthropic.Claude` | winget | exe |
| telegram | `Telegram.TelegramDesktop` | winget | inno |
| whatsapp | `9NKSQGP7F2NH` | msstore | Store (MSIX) |
| discord | `Discord.Discord` | winget | exe (Squirrel) |
| steam | `Valve.Steam` | winget | nullsoft |
| tradingview | `TradingView.TradingViewDesktop` | winget | msix |
| ollama | `Ollama.Ollama` | winget | inno |
| vscode | `Microsoft.VisualStudioCode` | winget | inno (user scope) |
| protonvpn | `Proton.ProtonVPN` | winget | inno |
| chrome | `Google.Chrome` | winget | wix (MSI, machine scope) |
| spotify | `9NCBCSZSJRSB` | msstore | Store (MSIX) — the installer of the winget `Spotify.Spotify` does not work in an administrator session (`-1978335146`, seen in CI) |
| obs | `OBSProject.OBSStudio` | winget | nullsoft |

## Post-install names: verification status

Real install test: [`tests/Integration/Apps-Install.ps1`](../tests/Integration/Apps-Install.ps1) installs the apps,
reports an ERROR if a new shortcut is left on the desktop, and dumps the new Run values, Startup items, Start items and
StartupApproved state. In CI it is the `apps` job (manual trigger only: Actions → CI → Run workflow) or `-Force -Undo` in a Hyper-V VM.

**First run (2026-11-24, GitHub `windows-latest`, administrator):** 11 apps installed + layout applied, the second run
was all ALREADY SET, **new shortcuts on the desktop: 0** (Phase 4 acceptance). The Spotify winget installer rejected the administrator session →
switched to the Store version. In the discovery dump, the Ollama (`Ollama`) and Proton (`Proton`) Start folders were left unflattened →
catalog fixed. Chrome is already installed on the runner image.

**Latest run (2026-11-24, 3b74cdd):** 12/12 installed, 0 new shortcuts on the desktop, second run 12/12 ALREADY SET,
`-Undo` 11/12: **Steam** was not removed. Diagnosis (winget `--verbose-logs`): Steam's uninstall entry has no
`QuietUninstallString`; even with `--silent`, winget starts `uninstall.exe` **without arguments**, the NSIS uninstaller (`Un_A.exe`) waits
in an invisible confirmation window, and winget still says "Successfully uninstalled". The same file with `/S` removes it completely in 3-6 s.
Fix: `quietUninstall` in the catalog (`%ProgramFiles(x86)%\Steam\uninstall.exe /S`); revert runs this instead of winget.
After each uninstall, the provider waits until the package disappears from the list (at most 120 s) and reports an ERROR if it does not (it does not pass silently).

**Verification (2026-11-24, 66b4d1d):** CI `apps` job with 0 ERROR: 12/12 installed, 0 new shortcuts on the desktop, second run
12/12 ALREADY SET, `-Undo` 12/12 (including Steam), nothing left installed after revert.

| id | Run / Startup | Desktop | Start folder | Status |
| --- | --- | --- | --- | --- |
| claude | `*Claude*` (not written at install) | `Claude.lnk` | shortcut at root ✓ | Run name to be seen at first launch |
| telegram | `Telegram Desktop` (disabled in advance) | `Telegram.lnk` | `Telegram Desktop` ✓ | Run is written at first launch |
| discord | HKCU `Discord` ✓ | `Discord.lnk` | `Discord Inc` → at root ✓ | ✓ |
| steam | HKCU `Steam` ✓ | `Steam.lnk` | `Steam` ✓ | ✓ (revert with `quietUninstall`) |
| ollama | Startup folder `Ollama.lnk` ✓ | `Ollama.lnk` | `Ollama` → at root ✓ | ✓ |
| vscode | — | `Visual Studio Code.lnk` | `Visual Studio Code` ✓ | ✓ |
| protonvpn | `ProtonVPN`, `Proton VPN` (not written at install) | `Proton VPN.lnk` | `Proton` → at root ✓ | Run name to be seen at first launch |
| chrome | `GoogleChromeAutoLaunch_*` | `Google Chrome.lnk` | at root ✓ | preinstalled on the runner |
| obs | — | `OBS Studio.lnk` | `OBS Studio` → at root ✓ | ✓ |
| spotify, tradingview, whatsapp | MSIX `StartupTask` (not managed) | new shortcut cleanup | — (MSIX) | — |

A desktop shortcut that is not in the list is also deleted by the before / after comparison at install time; a wrong guessed name
only affects a shortcut that comes back with an update.

## Default browser (`setup.default-browser`)

Decision: **it is not set programmatically; the app's page is opened in Settings, the user clicks "Set default",
and the tool checks the result.**

- The `http` / `https` choice is kept under `HKCU\...\Shell\Associations\UrlAssociations\<protocol>\UserChoice` (and on 24H2+
  also `UserChoiceLatest\ProgId`) with a **hash** tied to the user and time; a write without the hash
  is reset by Windows.
- The **UCPD** driver (UserChoice Protection Driver) that arrived with the February 2024 update (Windows 11: KB5034765) blocks non-Microsoft processes
  from writing to the http/https and .pdf UserChoice keys (and their parent keys).
- The remaining ways are not suitable: turning off the UCPD service and computing the hash (system protection is disabled, may
  break with updates), a third-party unsigned tool (SetUserFTA etc.; repo rule: no unsigned binaries), a DISM / group policy
  default associations XML (applies to new user profiles or domain machines).
- Supported way: the one-click "Set default" in Windows 11 Settings (Firefox uses this too). The page
  opens directly: `ms-settings:defaultapps?registeredAppMachine=Google%20Chrome` (Chrome MSI is installed machine-wide;
  for a user-scope browser use `scope = 'User'`).

Behavior: the tweak is `Caution` (asks a question); not applied in non-interactive mode. When applied, it opens the page, and after the user confirms
`UserChoiceLatest\ProgId` (or `UserChoice` if missing) is read again; if it still differs, ERROR. Revert is also manual: if the previous browser
is different, the Default apps page is opened and a warning is written to the log. The value read on this machine: `ChromeHTML`.

## WhatsApp and WebView2

- WhatsApp's Windows app (`9NKSQGP7F2NH`) moved in July 2025 with beta 2.2569.0.0 from the native UWP / WinUI version to a
  **WebView2-based** one (it runs web.whatsapp.com inside WebView2); according to November 2025 news the stable version is also
  this (to be confirmed with the installed version in Phase 9). So WhatsApp **does not open without the Microsoft Edge WebView2 Runtime**.
- Claude, Discord, Spotify, VS Code, Telegram, Steam, OBS carry their own Chromium / Qt; they do not depend on WebView2.
  Microsoft Store, the new Outlook / Teams and some Windows components also use WebView2.
- WebView2 Runtime is a system component on Windows 11 and is installed / updated **separately** from the Edge browser
  (`Microsoft.EdgeWebView2Runtime`, updated through EdgeUpdate).
- Conclusion for Phase 5 (`bloat.edge-remove`): when removing Edge, the WebView2 Runtime and EdgeUpdate's WebView2 update must be
  **kept**; the policy that blocks reinstalling Edge must not cover WebView2. Check in Phase 9: after Edge is
  removed, WhatsApp opens and loads messages.

Sources: [Neowin](https://www.neowin.net/news/whatsapp-for-windows-is-ditching-uwp-for-a-web-app/),
[Notebookcheck](https://www.notebookcheck.net/WhatsApp-ditches-native-Windows-11-app-in-favor-of-Microsoft-WebView2.1063682.0.html),
[TechSpot](https://www.techspot.com/news/108752-whatsapp-dropping-native-windows-app-favor-web-based.html),
[Daring Fireball](https://daringfireball.net/2025/11/meta_whatsapp_windows_shitty_web_app),
[Mozilla: Set Default (UCPD)](https://firefox-source-docs.mozilla.org/widget/windows/shell/set-default.html),
[Microsoft: ms-settings:defaultapps](https://learn.microsoft.com/windows/uwp/launch-resume/launch-default-apps-settings),
[Chromium default_apps_util](https://chromium.googlesource.com/chromium/src/+/606f178bd02294de6187be5c0f4e2dcd86058dfa/base/win/default_apps_util.cc).
