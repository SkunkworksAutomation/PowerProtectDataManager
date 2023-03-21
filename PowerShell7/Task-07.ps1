<#
    THIS CODE REQUIRES POWWERSHELL 7.x.(latest)
    https://github.com/PowerShell/PowerShell/releases/tag/v7.3.1
#>

Import-Module .\dell.ppdm.psm1 -Force
$ppdm = 'ppdm-01.vcorp.local'
$pagesize = 25
$Results = @()
$Date = (Get-Date).AddDays(-1)

connect-ppdmapi -Server $ppdm

<#
    GET SYSTEM JOBS
#>

$Filters = @(
    "parentId eq null"
    "and classType in (`"JOB`", `"JOB_GROUP`")"
    "and category in (`"HOST_CONFIGURATION`",`"CLOUD_COPY_RECOVER`",`"CLOUD_DR`",`"CONFIG`",`"DELETE`",`"DISASTER_RECOVERY`",`"DISCOVER`",`"MANAGE`",`"NOTIFY`",`"SYSTEM`",`"VALIDATE`")"
)

$Results = get-activities -Filters $Filters -PageSize $pagesize

$Results | Format-List

disconnect-ppdmapi