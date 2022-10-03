#Base Install Flags
$Arguments = @(
    "/silent"
    "/noreboot"
    "/EnableCEIP=false"
)

#AutoUpdateCheck - Select Parameter (auto, disabled, manual)
$Arguments += "/AutoUpdateCheck=$AutoUpdateCheck"

#AutoUpdateStream - Select Parameter (LTSR, Current)
$Arguments += "/AutoUpdateStream=$AutoUpdateStream"

#Enable SSO - Bool Parameter
if ($includeSSON) { $Arguments += '/includeSSON ENABLE_SSON="Yes"' }

#IncludeAppProtection - Bool Parameter
if ($includeappprotection) { $Arguments += '/includeappprotection' }

#STORE0 Information - String Parameters
$STORE0 = @($STORE0_storename,$STORE0_servernamedomain,$STORE0_storedescription).where({$_})
if ($STORE0 -match ';') { throw "Semi-colons BAD" }
if ($STORE0.Count -eq 3) {
    $Arguments += "STORE0=`"$STORE0_storename;$STORE0_servernamedomain;On;$STORE0_storedescription`""
} elseif ($STORE0.Count -lt 3 -and $STORE0.Count -gt 0) {
    throw "All STORE0 variables must be defined if specifying a default store."
}

Start-Process -Wait $InstallerFile -ArgumentList $Arguments
