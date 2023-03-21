<#
    THIS CODE REQUIRES POWWERSHELL 7.x.(latest)
    https://github.com/PowerShell/PowerShell/releases/tag/v7.3.3
#>

Import-Module .\dell.ppdm.psm1 -Force
Import-Module .\dell.utilities.psm1 -Force

$ppdm = 'ppdm-01.vcorp.local'
$user = 'POLICY-DB01-ppdm-01-488d9'

connect-ppdmapi -Server $ppdm

<#
    CALL IDENTITY ACCESS MANAGEMENT SERVICE TO RETRIEVE PASSWORD AND UPDATE DDBOOST SE PASSWORD

    CYBERARC CENTRAL CREDENTIAL PROVIDER (CCP)
    https://docs.cyberark.com/Product-Doc/OnlineHelp/AAM-CP/Latest/en/Content/CCP/Calling-the-Web-Service-using-REST.htm

    CYBERARC PRIV CLOUD
    https://docs.cyberark.com/Product-Doc/OnlineHelp/PrivCloud/Latest/en/Content/WebServices/GetPasswordValueV10.htm
#>

# MAKE CALL TO YOUR IAM SERVER AND RETRIEVE THE SECRET FOR THE ACCOUNT

Write-Host "[CyberArc]: Retrieving credential information for: $($user)" -ForegroundColor Green
$iam = get-iamsecret -User $user

# DISPLAY RESULTS FOR DEMO PURPOSES
$iam | Format-Table -AutoSize

# UPDATE THE CREDENTIALS ON PPDM
set-password -IAM $iam

disconnect-ppdmapi