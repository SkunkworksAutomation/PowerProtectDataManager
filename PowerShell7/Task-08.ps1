<#
    THIS CODE REQUIRES POWWERSHELL 7.x.(latest)
    https://github.com/PowerShell/PowerShell/releases/tag/v7.3.3
#>

Import-Module .\dell.ppdm.psm1 -Force
$ppdm = 'ppdm-01.vcorp.local'
$pagesize = 100
$policy1 = "Source-Policy"
$policy2 = "Target-Policy"

connect-ppdmapi -Server $ppdm

<#
    MOVE ASSETS FROM A SOURCE TO A TARGET PROTECTION POLICIES
#>

# GET THE SOURCE POLICY BY NAME
$Filters = @(
    "name eq `"$($policy1)`""
)
$source = get-policy -Filters $Filters -PageSize $pagesize
$source | select-object name,id,assetType | format-table -AutoSize

# GET POLICY MEMBERS
$Filters = @(
    "protectionLifeCycle.id eq `"$($source.id)`""
)
$assets = get-assets -Filters $Filters -PageSize $pagesize
$assets | sort-object name | select-object name,id,type | format-table -AutoSize

# REMOVE THE MEMBERS FROM THE SOURCE POLICY
set-policyassignment -PolicyId $source.id -Operation Unassign -Assets $assets


# GET THE TARGET POLICY BY NAME
$Filters = @(
    "name eq `"$($policy2)`""
)
$target = get-Policy -Filters $Filters -PageSize $pagesize

# ADD THE MEMBERS TO THE TARGET POLICY
set-policyassignment -PolicyId $target.id -Operation Assign -Assets $assets


disconnect-ppdmapi