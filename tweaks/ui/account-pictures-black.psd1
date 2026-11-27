@{
    Id          = 'ui.account-pictures-black'
    Title       = 'Default account pictures black'
    Description = 'Windows'' default user and guest pictures (the .png / .bmp files in %ProgramData%\Microsoft\User Account Pictures) are replaced with a plain black image of the same size; users who have not set their own account picture see a black circle in Start, on the sign-in screen and in Settings. Subfolders (users'' own pictures) and the picture the user chose are not changed. The original files are backed up and revert writes them back exactly. The effect shows after signing in again.'
    Category    = 'ui'
    Risk        = 'Safe'
    Actions     = @(
        @{ Type = 'SolidImage'; Directory = '%ProgramData%\Microsoft\User Account Pictures'; Filter = @('*.png', '*.bmp'); Color = '000000' }
    )
}
