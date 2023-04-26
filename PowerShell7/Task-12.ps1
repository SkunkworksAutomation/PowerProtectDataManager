<#
    THIS CODE REQUIRES POWWERSHELL 7.x.(latest)
    https://github.com/PowerShell/PowerShell/releases/tag/v7.3.1
#>

Import-Module .\dell.ppdm.psm1 -Force
$ppdm = 'ppdm-01.vcorp.local'
$pagesize = 25
$activities = @()
$Date = (Get-Date).AddDays(-1)

connect-ppdmapi -Server $ppdm

<#
    CANCEL ACTIVITIES QUEUED, AND RUNNING
#>


$Filters = @(
    "classType eq `"JOB`""
    "and category eq `"PROTECT`""
    "and state in (`"QUEUED`",`"RUNNING`")"
    "and startTime ge `"$($Date.ToString('yyyy-MM-dd'))T00:00:00.000Z`""
)

$activities = get-activities -Filters $Filters -PageSize $pagesize

$activities | Select-Object id,name,startTime,endTime,@{l="status";e={$_.result.status}},state | Format-table -AutoSize

$activities | foreach-object {
    set-activity -Id $_.id
}


disconnect-ppdmapi