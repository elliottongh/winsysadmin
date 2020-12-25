$search_folder = "C:\Powershell\"
$out_file = "C:\Powershell\Results\Temp-Temp.csv"
$out_error = "C:\Powershell\Results\Temp-Temp-errors.csv"

$found = @()
$errors = @()

try {
    $acl = Get-Acl $search_folder

    ForEach ($entry in $acl.access) {
        $found += New-Object -TypeName PSObject -Property @{
            Folder = $search_folder
            Access = $entry.FileSystemRights
            Control = $entry.AccessControlType
            User = $entry.IdentityReference
            Inheritance = $entry.IsInherited    
        }        
    }
} catch {
    $errors += New-Object -TypeName PSObject -Property @{
        Item = $search_folder
        Error = $_.exception
    }
}

cmd /c dir "$search_folder" /b /s | ForEach {
    try {
        $item = $_
        $acl = Get-Acl $item

        ForEach ($entry in $acl.access) {
            If (!$entry.IsInherited) { 
                $found += New-Object -TypeName PSObject -Property @{
                    Folder = $item
                    Access = $entry.FileSystemRights
                    Control = $entry.AccessControlType
                    User = $entry.IdentityReference
                    Inheritance = $entry.IsInherited    
                }        
            }
        }
    } catch {
        $errors += New-Object -TypeName PSObject -Property @{
            Item = $item
            Error = $_.exception
        }
    }
}

$formatted = @()
$found | Select-Object -Property Folder,Control,Access,Inheritance -Unique | ForEach-Object {
    $CurrentFolder = $_.Folder
    $CurrentControl = $_.Control
    $CurrentAccess = $_.Access
    $CurrentInheritance = $_.Inheritance
    $CurrentUsers = ""
    $found | Where-Object { $_.Folder -eq $CurrentFolder -and $_.Control -eq $CurrentControl -and $_.Access -eq $CurrentAccess -and $_.Inheritance -eq $CurrentInheritance } | ForEach-Object {
        $CurrentUsers = "$CurrentUsers" + $_.User + ";"
    }
    $formatted += New-Object -TypeName PSObject -Property @{
        Folder = $CurrentFolder
        Access = $CurrentAccess
        Control = $CurrentControl
        Users = $CurrentUsers
        Inheritance = $CurrentInheritance
    }
}

$formatted | 
Select-Object -Property Folder,Users,Control,Access,Inheritance | 
Export-Csv -NoTypeInformation -Path $out_file

$errors |
Export-Csv -NoTypeInformation -Path $out_error