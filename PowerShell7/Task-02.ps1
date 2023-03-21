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
    GET FILESYSTEM ASSETS
#>

 
$Filters = @(
    "type eq `"FILE_SYSTEM`""
    "and lastDiscoveryStatus in (`"NEW`",`"DETECTED`",`"NOT_DETECTED`")"
)

$Results = get-assets -Filters $Filters -PageSize $pagesize

$Results | Select-Object id,name,type,status,protectionStatus,@{l="policyName";e={$_.protectionPolicy.name}},lastAvailableCopyTime| Format-List

disconnect-ppdmapi