[CmdletBinding()]
Param(
    [string]$Root
)

$ScriptPath = split-path -parent $MyInvocation.MyCommand.Definition
if (!$Root) { $Root = $ScriptPath }
elseif (!(Test-Path -Path $Root)) { throw 'Invalid root' }

$OutputFile = "$ScriptPath\$($Root.Split([IO.Path]::GetInvalidFileNameChars()) -join '').csv"
$ErrorFile = "$ScriptPath\$($Root.Split([IO.Path]::GetInvalidFileNameChars()) -join '').errors.csv"

if ((Test-Path -Path "$OutputFile") -and !$(try { [IO.File]::OpenWrite("$OutputFile").close();$true } catch {$false})) { throw "$OutputFile open." }
if ((Test-Path -Path "$ErrorFile") -and !$(try { [IO.File]::OpenWrite("$ErrorFile").close();$true } catch {$false})) { throw "$ErrorFile open." }

$PermissionsOutput = @()
$ErrorOutput = @()
$FormattedOutput = @()

function Log-PermissionsError ([string]$Path,[string]$Exception) {
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
        Log-PermissionsError -Path $Path -Exception $_.exception
    }
}

$PermissionsOutput = $(
    Get-Permissions -Path "$Root" -Inheritance $true;
    cmd /c dir "$Root" /b /s | %{ Get-Permissions -Path "$_" }
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