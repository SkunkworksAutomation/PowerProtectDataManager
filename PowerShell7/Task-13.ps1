<#
    THIS CODE REQUIRES POWWERSHELL 7.x.(latest)
    https://github.com/PowerShell/PowerShell/releases/tag/v7.3.4
#>

Import-Module .\dell.ppdm.psm1 -Force
$ppdm = 'ppdm-01.vcorp.local'
$pagesize = 25
$asset = @()
[bool]$excluded = $true
connect-ppdmapi -Server $ppdm

# ARRAY OF VIRTUAL MACHINES
$vms = @(
    'vc1-win-01'
)
<#
    INCLUDE OR EXCLUDE ALL DISKS FOR VRTUAL MACHINE ASSETS EXCPET:
    Hard disk 1
#>

$vms | foreach-object {
    $Filters = @(
        "name eq `"$($_)`""
        "type eq `"VMWARE_VIRTUAL_MACHINE`""
    )
    $asset += get-assets -Filters $Filters -PageSize $pagesize

    set-diskexclusions -Asset $asset -Excluded $excluded

}
# $result | select-object id,name,type,updateAt | format-table -AutoSize


disconnect-ppdmapi