# Profil: hangi tweak'lerin (ve hangi parametrelerle) uygulanacağını söyleyen JSON dosyası (profiles/*.json).
# Biçim ve doğrulama: profiles/_schema.json (belge) + src/Core/Schema.ps1 (Get-FaiProfileError).
#
#   {
#     "name": "fedai", "description": "...",
#     "tweaks": [ "sound.startup-sound-off", { "id": "sound.volume", "params": { "level": 15 } } ],
#     "autoConfirm": [ "graphics.p0-state" ],     // -Unattended'da onaysız uygulanacak Caution tweak'ler
#     "apps": [], "games": [], "layout": {}, "exceptions": {}    // sonraki fazlar
#   }

class Profile {
    [string] $Name
    [string] $Description = ''
    # Sıralı liste; her eleman @{ Id = '...'; Params = @{...} }
    [hashtable[]] $Tweaks = @()
    [string[]] $AutoConfirm = @()
    [object[]] $Apps = @()
    [object[]] $Games = @()
    [hashtable] $Layout = @{}
    [hashtable] $Exceptions = @{}

    Profile() { }

    static [Profile] FromHashtable([hashtable] $Data, [string] $Source) {
        $errors = @(Get-FaiProfileError -Data $Data)
        if ($errors.Count -gt 0) {
            throw ("Profil geçersiz ({0}):`n  {1}" -f $Source, ($errors -join "`n  "))
        }
        $p = [Profile]::new()
        $p.Name = [string]$Data['name']
        if ($Data.ContainsKey('description')) { $p.Description = [string]$Data['description'] }
        $list = New-Object 'System.Collections.Generic.List[hashtable]'
        foreach ($entry in @($Data['tweaks'])) {
            if ($entry -is [string]) {
                $list.Add(@{ Id = $entry; Params = @{} })
            }
            else {
                $params = @{}
                if ($entry.ContainsKey('params')) { $params = $entry['params'] }
                $list.Add(@{ Id = [string]$entry['id']; Params = $params })
            }
        }
        $p.Tweaks = $list.ToArray()
        if ($Data.ContainsKey('autoConfirm')) { $p.AutoConfirm = [string[]]@($Data['autoConfirm']) }
        if ($Data.ContainsKey('apps')) { $p.Apps = [object[]]@($Data['apps']) }
        if ($Data.ContainsKey('games')) { $p.Games = [object[]]@($Data['games']) }
        if ($Data.ContainsKey('layout')) { $p.Layout = $Data['layout'] }
        if ($Data.ContainsKey('exceptions')) { $p.Exceptions = $Data['exceptions'] }
        return $p
    }

    [bool] IsAutoConfirmed([string] $TweakId) {
        return ($this.AutoConfirm -contains $TweakId)
    }
}
