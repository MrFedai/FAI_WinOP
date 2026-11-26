# Gerçek dosya sistemi güvenliği sağlayıcısı (System.IO + Get-Acl / Set-Acl). Veri klasörünü koruyan mantık
# src/Core/DataGuard.ps1'de; bu sınıf yalnız Windows'a dokunur. Kimlikler SID ile (yerelleştirilmiş ad kullanılmaz).

class WindowsFileSecurityProvider : IFileSecurityProvider {
    WindowsFileSecurityProvider() { }

    # GetAttributes bağlantıyı izlemez: kırık bağlantı da öğe sayılır (ReparsePoint bitiyle).
    hidden [object] Attributes([string] $Path) {
        $attr = $null
        try { $attr = [System.IO.File]::GetAttributes($Path) }
        catch [System.IO.FileNotFoundException] { $attr = $null }
        catch [System.IO.DirectoryNotFoundException] { $attr = $null }
        return $attr
    }

    [string] GetItemType([string] $Path) {
        $attr = $this.Attributes($Path)
        if ($null -eq $attr) { return '' }
        if (([int]$attr -band [int][System.IO.FileAttributes]::Directory) -ne 0) { return 'Directory' }
        return 'File'
    }

    [bool] IsReparsePoint([string] $Path) {
        $attr = $this.Attributes($Path)
        if ($null -eq $attr) { return $false }
        return (([int]$attr -band [int][System.IO.FileAttributes]::ReparsePoint) -ne 0)
    }

    [string] GetOwnerSid([string] $Path) {
        try {
            $acl = Get-Acl -LiteralPath $Path -ErrorAction Stop
            $sid = $acl.GetOwner([System.Security.Principal.SecurityIdentifier])
            if ($null -eq $sid) { return '' }
            return $sid.Value
        }
        catch { return '' }
    }

    [string[]] GetEntries([string] $Directory) {
        if (-not [System.IO.Directory]::Exists($Directory)) { return [string[]]@() }
        $arr = [string[]]@([System.IO.Directory]::GetFileSystemEntries($Directory))
        [System.Array]::Sort($arr, [System.StringComparer]::OrdinalIgnoreCase)
        return $arr
    }

    # FileSystemRights → Full | Read | Write (genel haklar dahil: GENERIC_ALL tam, GENERIC_READ / EXECUTE okuma).
    hidden static [string] AccessOf([int] $Rights) {
        if (($Rights -band 0x10000000) -ne 0 -or ($Rights -band 0x1F01FF) -eq 0x1F01FF) { return 'Full' }
        $readMask = 0x200A9 -bor 0x100000 -bor 0x20000000 -bor [int]::MinValue
        if (($Rights -band (-bnot $readMask)) -eq 0) { return 'Read' }
        return 'Write'
    }

    [hashtable] GetAcl([string] $Path) {
        $acl = Get-Acl -LiteralPath $Path -ErrorAction Stop
        $owner = $acl.GetOwner([System.Security.Principal.SecurityIdentifier])
        $ownerSid = ''
        if ($null -ne $owner) { $ownerSid = $owner.Value }
        $both = [int]([System.Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit')
        $rules = New-Object System.Collections.ArrayList
        foreach ($r in $acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])) {
            $inherits = (([int]$r.InheritanceFlags -band $both) -eq $both) -and
            (([int]$r.PropagationFlags -band [int][System.Security.AccessControl.PropagationFlags]::InheritOnly) -eq 0)
            [void]$rules.Add(@{
                    Sid       = $r.IdentityReference.Value
                    Access    = [WindowsFileSecurityProvider]::AccessOf([int]$r.FileSystemRights)
                    Deny      = ($r.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Deny)
                    Inherited = [bool]$r.IsInherited
                    Inherits  = [bool]$inherits
                })
        }
        return @{ Protected = [bool]$acl.AreAccessRulesProtected; Owner = $ownerSid; Rules = $rules.ToArray() }
    }

    [void] CreateDirectory([string] $Path) { [void][System.IO.Directory]::CreateDirectory($Path) }

    [void] MoveItem([string] $Path, [string] $Destination) {
        $attr = $this.Attributes($Path)
        if ($null -eq $attr) { throw "Taşınacak öğe yok: $Path" }
        if (([int]$attr -band [int][System.IO.FileAttributes]::Directory) -ne 0) { [System.IO.Directory]::Move($Path, $Destination) }
        else { [System.IO.File]::Move($Path, $Destination) }
    }

    [void] SetRestrictedAcl([string] $Path, [string[]] $ReaderSid) {
        $sec = New-Object System.Security.AccessControl.DirectorySecurity
        $sec.SetAccessRuleProtection($true, $false)
        $inherit = [System.Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
        $propagate = [System.Security.AccessControl.PropagationFlags]::None
        $allow = [System.Security.AccessControl.AccessControlType]::Allow
        $grants = New-Object System.Collections.ArrayList
        [void]$grants.Add(@('S-1-5-18', [System.Security.AccessControl.FileSystemRights]::FullControl))
        [void]$grants.Add(@('S-1-5-32-544', [System.Security.AccessControl.FileSystemRights]::FullControl))
        foreach ($r in @($ReaderSid)) {
            if ($r) { [void]$grants.Add(@($r, [System.Security.AccessControl.FileSystemRights]::ReadAndExecute)) }
        }
        foreach ($g in $grants) {
            $sid = New-Object System.Security.Principal.SecurityIdentifier([string]$g[0])
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($sid, $g[1], $inherit, $propagate, $allow)
            $sec.AddAccessRule($rule)
        }
        $sec.SetOwner((New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')))
        # Set-Acl (SetNamedSecurityInfo) kalıtımı var olan alt öğelere de yayar.
        Set-Acl -LiteralPath $Path -AclObject $sec -ErrorAction Stop
    }
}
