<#
.SYNOPSIS
    FAI_WinOP — a profile-driven optimizer for Windows 11. Without a profile, the interactive menu opens.

.DESCRIPTION
    Recommended install (SHA-256 verified, in an administrator PowerShell):
        & ([scriptblock]::Create((irm https://github.com/MrFedai/FAI_WinOP/releases/latest/download/get.ps1))) -Profile fedai -DryRun
    If not run as administrator, it elevates itself (UAC). This file is built by build/Bundle.ps1; source: src/Entry.ps1.

.PARAMETER FaiProfile
    -Profile: embedded profile name (fedai), a .json path or an https URL. If omitted, the menu opens.
.PARAMETER DryRun
    Preview: nothing changes, no questions are asked.
.PARAMETER Unattended
    No questions: Risk is never applied, Caution only with autoConfirm in the profile.
.PARAMETER Undo
    Reverts the last session that has not been undone (or the one given with -Session).
.PARAMETER Session
    With -Undo: the session ID. With -Profile / -Only: resume this unfinished session (the resume command after a
    restart adds it; an untrusted or already reverted session is not written to, a new session is opened).
.PARAMETER SkipFailed
    With -Undo: skips entries that cannot be reverted and closes the session (skipped entries are in the report).
    Without it, the session stays open and running -Undo again retries only the rest.
.PARAMETER Only
    Only these tweaks (comma-separated). Without a profile, only these run; allows tool tweaks (Tool).
.PARAMETER Skip
    Tweak / app IDs to leave out of the profile (app: app.<id>).
.PARAMETER UpdatesOn
    Resumes Windows Update (removes the pause).
.PARAMETER UpdatesOff
    Pauses Windows Update for 365 days.
.PARAMETER ExportProfile
    Writes this machine's state as a profile: a name (Documents\FAI_WinOP\<name>.json) or a .json path.
.PARAMETER ExportLayout
    Writes the taskbar / Start / desktop layout to the profile's layout section (-Profile .json path or
    Documents\FAI_WinOP\layout.json).
.PARAMETER Version
    Downloads this version (vX.Y.Z) from GitHub releases, verifies its SHA-256 and runs it.
.PARAMETER List
    Lists tweaks, apps and embedded profiles.
.PARAMETER AllowOtherUser
    If the elevating administrator account does not own the desktop session, the tool stops (HKCU, desktop and pins
    would go to the elevating account's profile). With this switch it applies to that account's profile on purpose.
    -DryRun goes through the same check.

.EXAMPLE
    .\install.ps1 -Profile fedai -DryRun
.EXAMPLE
    .\install.ps1 -Undo
.EXAMPLE
    .\install.ps1 -Only refresh.reboot-to-bios
#>
[CmdletBinding()]
param(
    # -Profile ($PROFILE otomatik değişkenini ezmemek için değişken adı FaiProfile).
    [Alias('Profile')] [string] $FaiProfile = '',
    [switch] $DryRun,
    [switch] $Unattended,
    [switch] $Undo,
    [string] $Session = '',
    [switch] $SkipFailed,
    [string[]] $Only = @(),
    [string[]] $Skip = @(),
    [switch] $UpdatesOn,
    [switch] $UpdatesOff,
    [string] $ExportProfile = '',
    [switch] $ExportLayout,
    [string] $Version = '',
    [switch] $List,
    [switch] $AllowOtherUser
)

# Nokta-kaynak (birim testleri, Load-Bundle) yalnız tanımları yükler, çalıştırmaz.
if ($MyInvocation.InvocationName -ne '.') {
    $faiExitCode = Invoke-FaiCli -Bound $PSBoundParameters -ScriptPath $PSCommandPath
    # Dosya olarak çalıştıysa süreç çıkış kodu; irm | iex'te exit kullanıcının penceresini kapatırdı.
    if ($PSCommandPath) { exit $faiExitCode }
}
