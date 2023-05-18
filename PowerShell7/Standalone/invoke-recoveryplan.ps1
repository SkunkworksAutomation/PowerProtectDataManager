<#
    THIS CODE REQUIRES POWWERSHELL 7.x.(latest)
    https://github.com/PowerShell/PowerShell/releases/tag/v7.3.4
#>

# GLOBAL VARS
$global:ApiVersion = 'v2'
$global:AuthObject = $null

# DATA VARS
[array]$assets = @()
[array]$esxhosts = @()
[array]$resourcepools = @()
[array]$datastores = @()
[array]$maps = @()
[array]$activities = @()

# RECOVERY VARS
$ppdm = 'ppdm-01.vcorp.local'
$policy = "Policy-VM"
$dcfolder = "Recover"
$network = "VM Network"
# PAGE SIZE RETURNED FROM POWERPROTECT DATA MANAGER
$pagesize = 100
# POLLING INTERVAL FOR ACTIVITY MONITROING
$poll = 15

function connect-ppdmapi {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$true)]
        [string]$Server
    )
    begin {
        # CHECK TO SEE IF CREDS FILE EXISTS IF NOT CREATE ONE
        $Exists = Test-Path -Path ".\$($Server).xml" -PathType Leaf
        if($Exists) {
            $Credential = Import-CliXml ".\$($Server).xml"
        } else {
            $Credential = Get-Credential
            $Credential | Export-CliXml ".\$($Server).xml"
        } 
    }
    process {
        $login = @{
            username="$($Credential.username)"
            password="$(ConvertFrom-SecureString -SecureString $Credential.password -AsPlainText)"
        }
        #LOGON TO THE POWERPROTECT API 
        $Auth = Invoke-RestMethod -Uri "https://$($Server):8443/api/$($ApiVersion)/login" `
                    -Method POST `
                    -ContentType 'application/json' `
                    -Body (ConvertTo-Json $login) `
                    -SkipCertificateCheck
        $Object = @{
            server ="https://$($Server):8443/api/$($ApiVersion)"
            token= @{
                authorization="Bearer $($Auth.access_token)"
            } #END TOKEN
        } #END AUTHOBJ

        $global:AuthObject = $Object
        $global:AuthObject | Format-List

    } #END PROCESS
} #END FUNCTION

function disconnect-ppdmapi {
    [CmdletBinding()]
    param (
    )
    begin {}
    process {
        #LOGOFF OF THE POWERPROTECT API
        Invoke-RestMethod -Uri "$($AuthObject.server)/logout" `
        -Method POST `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -SkipCertificateCheck

        $global:AuthObject = $null
    }
} #END FUNCTION

function get-protectionpolicies {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$true)]
        [array]$Filters,
        [Parameter( Mandatory=$true)]
        [int]$PageSize
    )
    begin {}
    process {
        $Results = @()
        
        $Endpoint = "protection-policies"
        if($Filters.Length -gt 0) {
            $Join = ($Filters -join ' ') -replace '\s','%20' -replace '"','%22'
            $Endpoint = "$($Endpoint)?filter=$($Join)"
        }

        $Query =  Invoke-RestMethod -Uri "$($AuthObject.server)/$($Endpoint)&pageSize=$($PageSize)&orderby=name" `
        -Method GET `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -SkipCertificateCheck
        $Results = $Query.content

        return $Results
    }
}

function get-assets {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$true)]
        [array]$Filters,
        [Parameter( Mandatory=$true)]
        [int]$PageSize
    )
    begin {}
    process {
        
        $Results = @()
        
        $Endpoint = "assets"
        if($Filters.Length -gt 0) {
            $Join = ($Filters -join ' ') -replace '\s','%20' -replace '"','%22'
            $Endpoint = "$($Endpoint)?filter=$($Join)"
        }

        $Query =  Invoke-RestMethod -Uri "$($AuthObject.server)/$($Endpoint)&pageSize=$($PageSize)&queryState=BEGIN" `
        -Method GET `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -SkipCertificateCheck
        $Results += $Query.content
        
        $Page = 1
        do {
            $Token = "$($Query.page.queryState)"
            if($Page -gt 1) {
                $Token = "$($Paging.page.queryState)"
            }
            $Paging = Invoke-RestMethod -Uri "$($AuthObject.server)/$($Endpoint)&queryState=$($Token)" `
            -Method GET `
            -ContentType 'application/json' `
            -Headers ($AuthObject.token) `
            -SkipCertificateCheck
            $Results += $Paging.content

            $Page++;
        } 
        until ($Paging.page.queryState -eq "END")

        return $Results

    } # END PROCESS
}
function get-vmcontainers {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$true)]
        [array]$Filters,
        [Parameter( Mandatory=$true)]
        [int]$PageSize
    )
    begin {}
    process {
        
        $Results = @()
        
        $Endpoint = "vm-containers"
        if($Filters.Length -gt 0) {
            $Join = ($Filters -join ' ') -replace '\s','%20' -replace '"','%22'
            $Endpoint = "$($Endpoint)?filterType=vCenterInventory&filter=$($Join)"
        }

        $Query =  Invoke-RestMethod -Uri "$($AuthObject.server)/$($Endpoint)&pageSize=$($PageSize)" `
        -Method GET `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -SkipCertificateCheck
        $Results = $Query.content
        
        return $Results

    } # END PROCESS
}

function get-esxdatastore {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$true)]
        [string]$InventorySourceId,
        [Parameter( Mandatory=$true)]
        [string]$HostSystemId

    )
    begin {}
    process {
        $Endpoint = "vcenter/$($InventorySourceId)/data-stores/$($HostSystemId)?orderby=freeSpace DESC"
        $Query =  Invoke-RestMethod -Uri "$($AuthObject.server)/$($Endpoint)" `
        -Method GET `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -SkipCertificateCheck
        $Results = $Query.datastores

        return $Results
    }
}

function get-latestcopies {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$true)]
        [array]$Filters
    )
    begin {}
    process {
        $Results = @()
        
        $Endpoint = "latest-copies"
        if($Filters.Length -gt 0) {
            $Join = ($Filters -join ' ') -replace '\s','%20' -replace '"','%22'
            $Endpoint = "$($Endpoint)?filter=$($Join)"
        }

        $Query =  Invoke-RestMethod -Uri "$($AuthObject.server)/$($Endpoint)&pageSize=$($PageSize)" `
        -Method GET `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -SkipCertificateCheck
        $Results = $Query.content

        return $Results
    }
}

function new-monitor {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$true)]
        [string]$ActivityId,
        [Parameter( Mandatory=$true)]
        [int]$Poll

    )
    begin {}
    process {
        do {
            #POLL THE RECOVERY ACTIVITY EVERY 60 SECONDS UNTIL COMPLETE
            $Endpoint = "activities"
            $Monitor = Invoke-RestMethod -Uri "$($AuthObject.server)/$($Endpoint)/$($ActivityId)" `
            -Method GET `
            -ContentType 'application/json' `
            -Headers ($AuthObject.token) `
            -SkipCertificateCheck

            if($Monitor.state -ne "COMPLETED"){
                if($Monitor.state -ne "RUNNING") {
                    Write-Host "[ACTIVITY]: $($ActivityId), State = $($Monitor.state), Sleeping $($Poll) seconds..." -ForegroundColor Yellow
                } else {
                    Write-Host "[ACTIVITY]: $($ActivityId), State = $($Monitor.state), Sleeping $($Poll) seconds..." -ForegroundColor Green
                }
                
                Start-Sleep -Seconds $Poll
            }
        } until($Monitor -and $Monitor.state -eq "COMPLETED")
    }
}
function get-exportedcopies {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$true)]
        [array]$Filters
    )
    begin {}
    process {
        $Results = @()

        # GET THE INSTANT ACCESS SESSION
        $Endpoint = "exported-copies"
        if($Filters.Length -gt 0) {
            $Join = ($Filters -join ' ') -replace '\s','%20' -replace '"','%22'
            $Endpoint = "$($Endpoint)?filter=$($Join)"
        }
        $Query = Invoke-RestMethod -Uri "$($AuthObject.server)/$($Endpoint)" `
        -Method GET `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -SkipCertificateCheck

        $Results = $Query.content[0].exportedCopiesDetails.targetExportedVmInfo

        return $Results
    }
}

function new-vmotion {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$true)]
        [string]$Ia,
        [Parameter( Mandatory=$true)]
        [object]$Body
    )
    begin {
        
    }
    process {
        $Endpoint = "restored-copies/$($Ia)/vmotion"
        Write-Host "`n[POST]: /$($Endpoint)`n $( ($Body | Convertto-Json -Depth 10) )"

        $action =  Invoke-RestMethod -Uri "$($AuthObject.server)/$($Endpoint)" `
        -Method POST `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -Body ($Body | Convertto-Json -Depth 10) `
        -SkipCertificateCheck

        return $action
    }
}
<#
    BEGIN DYNAMIC RECOVERY PLAN
#>
#TIMER
$StopWatch = New-Object -TypeName System.Diagnostics.Stopwatch
$StopWatch.start()

Write-Host "`n[($($ppdm))]: Starting dynamic recovery plan...`n"


# CONNECT TO THE API
connect-ppdmapi -Server $ppdm

# GET THE PROTECTION POLICIES
Write-Host "[($($ppdm))]: Querying for protection polices with names like $($policy)%"
$Filters = @(
    "name lk `"$($policy)%25`""
    "and assetType eq `"VMWARE_VIRTUAL_MACHINE`""
)
$policies = get-protectionpolicies -Filters $Filters -PageSize $pagesize
if($policies.length -gt 0) {
    Write-Host "[($($ppdm))]: Found $($policies.count) policie(s) with names like $($policy)%" -ForegroundColor green
} else {
    throw "[ERROR]: No policies found with names like $($policy)%"
}

# GET THE PROTECTION POLICIY MEMBERS WITH A BACKUP FOR EACH POLICY
$policies | foreach-object {
    Write-Host "[($($ppdm))]: Querying for members of $($_.name)"
    $Filters = @(
        "protectionPolicyId eq `"$($_.id)`""
        "and lastAvailableCopyTime ne null"
    )
    $query = get-assets -Filters $Filters -PageSize $pagesize
    if($query.length -gt 0) {
        Write-Host "[($($ppdm))]: Found $($query.count) member(s) in $($_.name)" -ForegroundColor green
        $assets += $query
    } else {
        throw "[ERROR]: No members found for policy $($_.name)"
    }
}

# GET THE VCENTER
Write-Host "[($($ppdm))]: Querying for the attached vcenter..."
$Filters = @(
    "viewType eq `"HOST`""
)
$vc = get-vmcontainers -Filters $Filters -PageSize $pagesize
if($vc.length -eq 1) {
    Write-Host "[($($ppdm))]: Found attached vcenter: $($vc[0].name)" -ForegroundColor green
} else {
    throw "[ERROR]: No attached vcenters found.`n"
}

# GET THE DATACENTER
Write-Host "[($($ppdm))]: Querying for the datacenter..."
$Filters = @(
    "viewType eq `"HOST`"",
    "and parentId eq `"$($vc[0].id)`""
)
$dc = get-vmcontainers -Filters $Filters -PageSize $pagesize
if($dc.length -eq 1) {
    Write-Host "[($($ppdm))]: Found datacenter: $($dc[0].name)" -ForegroundColor green
} else {
    throw "[ERROR]: No datacenters found.`n"
}

# GET THE FOLDER
Write-Host "[($($ppdm))]: Querying for target folder $($dcfolder)..."
$Filters = @(
    "viewType eq `"VM`"",
    "and parentId eq `"$($dc[0].id)`"",
    "and name eq `"$($dcfolder)`""
)
$folder = get-vmcontainers -Filters $Filters -PageSize $pagesize
if($folder.length -eq 1) {
    Write-Host "[($($ppdm))]: Found folder: $($dcfolder)" -ForegroundColor green
} else {
    throw "[ERROR]: No folder named $($dcfolder) found.`n"
}

 # GET THE CLUSTERS
 Write-Host "[($($ppdm))]: Querying for target clusters..."
 $Filters = @(
     "viewType eq `"HOST`"",
     "and parentId eq `"$($dc[0].id)`""
 )
 $clusters = get-vmcontainers -Filters $Filters -PageSize $pagesize
 if($clusters.length -gt 0) {
     Write-Host "[($($ppdm))]: Found $($clusters.count) cluster(s)" -ForegroundColor green
 } else {
     throw "[ERROR]: No clusters found.`n"
 }

# GET THE HOSTS AND RESOURCE POOLS FOR EACH CLUSTER
$clusters | foreach-object {
    Write-Host "[($($ppdm))]: Querying for hosts and resource pools for $($_.name)"
    $Filters = @(
        "viewType eq `"HOST`"",
        "and parentId eq `"$($_.id)`""
    )
    $query = get-vmcontainers -Filters $Filters -PageSize $pagesize
    $count = ($query | where-object {$_.type -eq "esxHost"}).count
    if($count -gt 0) {
        Write-Host "[($($ppdm))]: Found $($count) ESX host(s)" -ForegroundColor Green
        $esxhosts += $query | where-object {$_.type -eq "esxHost"}
    } else {
        throw throw "[ERROR]: No ESX hosts found.`n"
    }
    $count = ($query | where-object {$_.type -eq "resourcePool"}).count
    if($count -gt 0) {
        Write-Host "[($($ppdm))]: Found $($count) resource pool(s)" -ForegroundColor Green
        $resourcepools += $query | where-object {$_.type -eq "resourcePool"}
    } else {
        throw throw "[ERROR]: No resource pools found.`n"
    }
}

# GET THE DATASTORES FOR EACH ESX HOST
foreach($server in $esxhosts) {
    # GET THE DATASTORES
    Write-Host "[($($ppdm))]: Querying for datastores attached to $($server.name)"

    $query = get-esxdatastore `
    -InventorySourceId $vc[0].inventorySourceId `
    -HostSystemId $server.details.esxHost.attributes.esxHost.hostMoref
    
    if($query.count -gt 0) {
        Write-Host "[($($ppdm))]: Found $($query.count) datastore(s) attached to $($server.name)" -ForegroundColor Green
        $object = [ordered] @{
            host = "$($server.name)"
            datastoreName = ($query | Sort-Object freeSpace -Descending | Select-Object -first 1).name
            datastoreMoref = ($query | Sort-Object freeSpace -Descending | Select-Object -first 1).moref  -split ':' | Select-Object -last 1
        }
        $datastores += (new-object -TypeName pscustomobject -Property $object)
    } else {
        throw "[ERROR]: No datastores found.`n"
    }
}

# CALCULATE THE NUMBER OF GUESTS PER ESX HOST
$GuestsPerHost = [Math]::Ceiling($assets.length / $esxhosts.length)

for($i=0;$i -lt $assets.length;$i++) {
    $Filters = @(
        "assetId eq `"$($assets[$i].id)`"",
        "and copyType eq `"FULL`""
    )
    $copy = get-latestcopies -Filters $Filters
    if($copy.length -eq 1) {
        Write-Host "[($($ppdm))]: Copy Id: $($copy.id) for $($assets[$i].name)" -ForegroundColor green
    } else {
        throw "[ERROR]: No copies found for $($assets[$i].name)`n"
    }
    # GET THE RECOVERY GROUP NUMBER BASED ON POLICY NAMING CONVENTION
    [int]$GroupNo = $assets[$i].protectionPolicy.name -replace "[^0-9]",''

    # GET THE MODULUS TO DETERMINE GROUPING OF VMS PER HOST
     $Mod = $i % $GuestsPerHost
     if($Mod -eq 0){
         #INCREMENT THE GROUP NUMBER IF THE MODULUS EQUALS 0
         $ModNo ++;
     }

     # BUILD THE RECOVERY OBJECT
     $object = [ordered]@{
        vmName = $assets[$i].name
        vmMoref = ($assets[$i].details.vm.vmMoref -split ':') | Select-Object -last 1
        vmId = $assets[$i].id
        clusterName = ($clusters | where-object {$_.id -eq $esxhosts[$ModNo-1].parentId}).name
        clusterMoref = ($clusters | where-object {$_.id -eq $esxhosts[$ModNo-1].parentId}).id -split ':' | select-object -last 1
        hostName = $esxhosts[$ModNo-1].name
        hostMoref = ($esxhosts[$ModNo-1].id -split ':') | Select-Object -last 1
        datastoreName= ($datastores | Where-Object {$_.host -eq $esxhosts[$ModNo-1].name }).datastoreName
        datastoreMoref= ($datastores | Where-Object {$_.host -eq $esxhosts[$ModNo-1].name }).datastoreMoref
        datacenterName = $dc[0].name
        datacenterMoref = ($dc[0].id  -split ':') | Select-Object -last 1
        folderMoref = $folder[0].details.folder.moRef
        resourcePoolName = ($resourcepools | Where-Object{$_.parentId -eq $esxhosts[$ModNo-1].parentId -and $_.name -eq $assets[$i].details.vm.resourcePool}).name
        resourcePoolMoref = ($resourcepools | Where-Object{$_.parentId -eq $esxhosts[$ModNo-1].parentId -and $_.name -eq $assets[$i].details.vm.resourcePool}).details.resourcePool.moRef
        networkLabel = "Network adapter 1"
        networkName = "$($network)"
        networkMoref = $esxhosts[$ModNo-1].details.esxHost.attributes.esxHost.networks[0].moref
        lastAvailableCopyId= $copy[0].id
        inventorySourceId = $assets[$i].details.vm.inventorySourceId
        group = $GroupNo
    }
    # ASSIGN THE OBJECT TO THE RECOVERY MAP
    $maps += (new-object -TypeName pscustomobject -Property $object)
}

Write-host "[EXECUTING]: Recovery Plan...`n" -ForegroundColor Yellow
$steps = ($maps | Select-Object group -Unique) | Sort-Object group,vmname

foreach($step in $steps.group) {
    # GET THE GROUP TO RECOVER
    $group = $maps | Where-Object { $_.group -eq $step }
    Write-Host "[RECOVERING]: Asset group $($step) to ESX: $($group[0].hostName), Datastore: $($group[0].datastoreName)"

    $group | foreach-object {
        # BUILD THE JSON REQUEST BODY
        $Body = [ordered]@{
            description = "DR_$($_.vmName) instant access recovery"
            copyIds = @("$($_.lastAvailableCopyId)")
            restoreType = "INSTANT_ACCESS"
            options = @{
                enableCompressedRestore = $false
            }
            restoredCopiesDetails = [ordered]@{
                targetVmInfo = [ordered]@{
                    inventorySourceId = "$($_.inventorySourceId)"
                    vmName = "DR_$($_.vmName)"
                    dataCenterMoref = "$($_.dataCenterMoref)"
                    hostMoref = "$($_.hostMoref)"
                    dataStoreMoref = "$($_.datastoreMoref)"
                    clusterMoref = "$($_clusterMoref)"
                    folderMoref = "$($_.folderMoref)"
                    resourcePoolMoref = "$($_.resourcePoolMoref)"
                    disks = @()
                    vmPowerOn = $true
                    vmReconnectNic = $false
                    tagRestoreDirective = "OFF"
                    spbmRestoreDirective = "OFF"
                    networks = @(
                        [ordered]@{
                            networkLabel = "$($_.networkLabel)"
                            networkMoref = "$($_.networkMoref)"
                            networkName = "$($_.networkName)"
                            reconnectNic = $true
                        }
                    )
                    recoverConfig = $true
                }
            }
        } #END BODY

        Write-Host "[MOUNTING]: Instant access recovery session for: $($_.vmName)"
        $Endpoint = "restored-copies"
        $action =  Invoke-RestMethod -Uri "$($AuthObject.server)/$($Endpoint)" `
        -Method POST `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -Body ($Body | Convertto-Json -Depth 10) `
        -SkipCertificateCheck

        $activities += $action.activityId
    }

    $activities | foreach-object {
        new-monitor -ActivityId $_ -Poll $poll
    }

    Write-Host "`n[MIGRATE]: Instant access recovery sessions mounted... invoking vmotion" -ForegroundColor Green
    $group | foreach-object {
        # GET THE INSTANT ACCESS SESSION
        $Filters = @(
            "copyId eq `"$($_.lastAvailableCopyId)`"",
            "and exportType ne `"RESTORED_COPIES`""
            "and dataSourceSubType eq `"VIRTUALMACHINE`""
        )
        $ia = get-exportedcopies -Filters $Filters

        $Body = [ordered]@{
            description = "Relocate virtual machine for DR_$($_.vmName)"
            copyId = "$($_.lastAvailableCopyId)"
            vmMoref = "$($_.vmMoref)"
            targetDatastoreMoref = "$($_.datastoreMoref)"
            disks = @()
        }
        $vmotion = new-vmotion -Ia $ia[0].restoredCopyId -Body $Body
        $vmotion | format-list
    }
}



# DISCONNECT FROM THE API
disconnect-ppdmapi


# GET THE ELAPSED TIME
Write-Host
Write-Host "[RUNTIME]: h:$($StopWatch.Elapsed.Hours) m:$($StopWatch.Elapsed.Minutes) s:$($StopWatch.Elapsed.Seconds)" -ForegroundColor Green
Write-Host

$StopWatch.stop()