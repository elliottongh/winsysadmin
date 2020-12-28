[CmdletBinding()]
Param(
    [string]$Root,
    [string]$ReportDir
)

$ScriptPath = split-path -parent $MyInvocation.MyCommand.Definition
if (!$ReportDir) { $ReportDir = $ScriptPath }
elseif (!(Test-Path -Path "$ReportDir")) { throw 'Invalid report directory' }

if (!$Root) { $Root = $ScriptPath }
elseif (!(Test-Path -Path "$Root")) { throw 'Invalid root' }

$ReportPrefix = "$ReportDir\$($Root.Split([IO.Path]::GetInvalidFileNameChars()) -join '')"

$OutputFile = "$ReportPrefix.csv"
$ErrorFile = "$ReportPrefix.errors.csv"

function Test-Closed {
    param(
        [string]$Path
    )
    return $(try { [IO.File]::OpenWrite("$Path").close();$true } catch {$false})
}

if ((Test-Path -Path "$OutputFile") -and !(Test-Closed -Path "$Outputfile")) { throw "$OutputFile open." }
if ((Test-Path -Path "$ErrorFile") -and !(Test-Closed -Path "$ErrorFile")) { throw "$ErrorFile open." }
if ((Test-Path -Path "$ReportPrefix.zip") -and !(Test-Closed -Path "$ReportPrefix.zip")) { throw "$ReportPrefix.zip open." }

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

$ReportFiles = @()
if (Test-Path -Path "$OutputFile") { $ReportFiles += $OutputFile }
if (Test-Path -Path "$ErrorFile") { $ReportFiles += $ErrorFile }
Compress-Archive -LiteralPath $ReportFiles -DestinationPath "$ReportPrefix.zip" -Force
if (Test-Path -Path "$OutputFile") { Remove-Item -Path "$OutputFile" -Force }
if (Test-Path -Path "$ErrorFile") { Remove-Item -Path "$ErrorFile" -Force }

Write-Output "$ReportPrefix.zip"