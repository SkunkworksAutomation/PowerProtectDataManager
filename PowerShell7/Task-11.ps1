<#
    THIS CODE REQUIRES POWWERSHELL 7.x.(latest)
    https://github.com/PowerShell/PowerShell/releases/tag/v7.3.3
#>

Import-Module .\dell.ppdm.psm1 -Force
$ppdm = 'ppdm-01.vcorp.local'
$pagesize = 25
# NAME OF THE PROTECTION POLICY
$name = "POLICY-VM01"


connect-ppdmapi -Server $ppdm

<#
    ENABLE OR DISABLE A PROTECTION POLICY
#>

# GET THE SOURCE POLICY BY NAME
$Filters = @(
    "name eq `"$($name)`""
)
$policy = get-policy -Filters $Filters -PageSize $pagesize

$policy | format-list

set-policy -Policy $policy -Enabled $true

disconnect-ppdmapi