<#
    THIS CODE REQUIRES POWWERSHELL 7.x.(latest)
    https://github.com/PowerShell/PowerShell/releases/tag/v7.3.3
#>

Import-Module .\dell.ppdm.psm1 -Force
$ppdm = 'ppdm-01.vcorp.local'
$pagesize = 25
$Results = @()
$Date = (Get-Date).AddDays(-1)

connect-ppdmapi -Server $ppdm

<#
    GET ACTIVITIES
    "OK","CANCELED","FAILED","OK_WITH_ERRORS","UNKNOWN","SKIPPED"
#>

 
$Status = @(
    "OK",
    "CANCELED",
    "FAILED",
    "OK_WITH_ERRORS",
    "UNKNOWN",
    "SKIPPED"
)
$Filters = @(
    "classType eq `"JOB`""
    "and category eq `"PROTECT`""
    "and result.status in (`"$($Status -join '","')`")"
    "and startTime ge `"$($Date.ToString('yyyy-MM-dd'))T00:00:00.000Z`""
)

$Results = get-activities -Filters $Filters -PageSize $pagesize

$Results | Select-Object name,startTime,endTime,@{l="status";e={$_.result.status}},state | Format-table -AutoSize

disconnect-ppdmapi