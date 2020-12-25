[CmdletBinding()]
Param()

$RootFolder = "C:\Powershell"

$OutputFile = $($RootFolder.Split([IO.Path]::GetInvalidFileNameChars()) -join '') + ".csv"
$ErrorFile = $($RootFolder.Split([IO.Path]::GetInvalidFileNameChars()) -join '') + ".errors.csv"

$PermissionsOutput = @()
$ErrorOutput = @()
$FormattedOutput = @()

function LogError ([string]$Path,[string]$Exception) {
    New-Object -TypeName PSObject -Property @{
        Path = $Path
        Exception = $Exception
    } | Export-Csv -NoTypeInformation -Append -Path $ErrorFile
}

function Get-Permissions {
    param(
        [string]$Path,
        [bool]$Inheritance = $false
    )

    try {
        $acl = Get-Acl $Path -ErrorAction Stop
        Write-Verbose $Path
        ForEach ($entry in $acl.access) {
            If ((!$entry.IsInherited -and !$Inheritance) -or ($Inheritance)) { 
                New-Object -TypeName PSObject -Property @{
                    Folder = $Path
                    Access = $entry.FileSystemRights
                    Control = $entry.AccessControlType
                    User = $entry.IdentityReference
                    Inheritance = $entry.IsInherited
                }
            }
        }
    } catch {
        LogError -Path $Path -Exception $_.exception
    }
}

$PermissionsOutput = $(
    Get-Permissions -Path "$RootFolder" -Inheritance $true;
    cmd /c dir "$RootFolder" /b /s | %{ Get-Permissions -Path "$_" }
)

$PermissionsOutput | Select-Object -Property Folder,Control,Access,Inheritance -Unique | ForEach-Object {
    $CurrentFolder = $_.Folder
    $CurrentControl = $_.Control
    $CurrentAccess = $_.Access
    $CurrentInheritance = $_.Inheritance
    $CurrentUsers = ""
    $PermissionsOutput | Where-Object { $_.Folder -eq $CurrentFolder -and $_.Control -eq $CurrentControl -and $_.Access -eq $CurrentAccess -and $_.Inheritance -eq $CurrentInheritance } | ForEach-Object {
        $CurrentUsers = "$CurrentUsers" + $_.User + ";"
    }
    $FormattedOutput += New-Object -TypeName PSObject -Property @{
        Folder = $CurrentFolder
        Access = $CurrentAccess
        Control = $CurrentControl
        Users = $CurrentUsers
        Inheritance = $CurrentInheritance
    }
}

$FormattedOutput | Select-Object -Property Folder,Users,Control,Access,Inheritance | Export-Csv -NoTypeInformation -Path $OutputFile