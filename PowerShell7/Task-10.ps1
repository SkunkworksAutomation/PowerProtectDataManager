<#
    THIS CODE REQUIRES POWWERSHELL 7.x.(latest)
    https://github.com/PowerShell/PowerShell/releases/tag/v7.3.3
#>

Import-Module .\dell.ppdm.psm1 -Force
$ppdm = 'ppdm-01.vcorp.local'
$version = "19.12.0-19"
$dd = 'ddve-01.vcorp.local'

connect-ppdmapi -Server $ppdm

<#
    PERFORM DISASTER RECOVERY OF POWERPROTECT DATA MANAGER SERVER
#>

# GET THE DR CONFIGURATION
$config = get-drserverconfig
$config | Format-List

# UPDATE THE DR CONFIGURATION
$update = set-drserverconfig -DataDomain $dd -ConfigId $config.id
$update | format-list

# GET THE DR SERVER HOSTS BY VERSION
$hosts = get-drserverhosts -Version $version
$hosts | format-list

# GET THE LATEST DR BACKPUP FOR THE HOST
$backup = get-drserverbackups -NodeId $hosts.nodeId
$backup | format-list

# START THE NEW RECOVERY
new-drserverrecovery -Backup $backup

disconnect-ppdmapi