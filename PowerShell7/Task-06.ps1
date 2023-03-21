<#
    THIS CODE REQUIRES POWWERSHELL 7.x.(latest)
    https://github.com/PowerShell/PowerShell/releases/tag/v7.3.3
#>

Import-Module .\dell.ppdm.psm1 -Force
$ppdm = 'ppdm-01.vcorp.local'
$pagesize = 25
$Results = @()
connect-ppdmapi -Server $ppdm

<#
    GET PPDM ALERTS
#>

 
$Filters = @(
    "acknowledgement.acknowledgeState eq `"UNACKNOWLEDGED`""
)

$Results = get-alerts -Filters $Filters -PageSize $pagesize

$Results | Format-List

disconnect-ppdmapi