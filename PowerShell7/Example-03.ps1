<#
    THIS CODE REQUIRES POWWERSHELL 7.x.(latest)
    https://github.com/PowerShell/powershell/releases

#>
Import-Module .\dell.ppdm.psm1 -Force

# VARS
$Server = "ppdm-01.vcorp.local"
$PageSize = 100

# CONNECT THE THE REST API
connect-dmapi -Server $Server

# GET ALERTS BASED ON FILTERS
$Filters = @(
    "acknowledgement.acknowledgeState eq `"UNACKNOWLEDGED`""
)
$Alerts = get-dmalerts -Filters $Filters -PageSize $PageSize

# GET ALL ALERTS
# $Alerts = get-dmalerts -PageSize $PageSize

$Alerts | format-list 

# DISCONNECT FROM THE REST API
disconnect-dmapi