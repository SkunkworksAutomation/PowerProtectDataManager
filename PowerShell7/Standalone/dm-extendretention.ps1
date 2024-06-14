[CmdletBinding()]
param (
    [Parameter( Mandatory=$false)]
    [switch]$Extend
)
$ReportPath = ".\ExtendedRetentionReport.csv"
$ppdm = "ppdm-01.vcorp.local"
$assets = @(
    'ubu-mid-01',
    'ubu-ora-01',
    'ubu-web-01'
)

# NUMBER OF DAYS TO EXTEND RETENTION BY
$noDays = 5

# TIME OFFSET
$offset = "-05:00"

# START DATETME
$date1 = Get-Date('2024-06-14')
$time1 = "00:00:00.0000"
$sDate = "$($date1.toString('yyyy-MM-dd'))T$($time1)$($offset)"

# END DATETIME
$date2 = Get-Date('2024-06-14')
$time2 = "23:59:59.9999"
$eDate = "$($date2.tostring('yyyy-MM-dd'))T$($time2)$($offset)"

# DO NOT MODIFY BELOW THIS LINE
$global:dmAuthObject = $null

function connect-dmapi {
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
       
        # LOGON TO THE REST API 
        $Auth = Invoke-RestMethod -Uri "https://$($Server):8443/api/v2/login" `
                    -Method POST `
                    -ContentType 'application/json' `
                    -Body (ConvertTo-Json $login) `
                    -SkipCertificateCheck
        $Object = @{
            server ="https://$($Server):8443/api"
            token= @{
                authorization="Bearer $($Auth.access_token)"
            } # END TOKEN
        } # END

        $global:dmAuthObject = $Object

        if(!$null -eq $dmAuthObject.token) {
            Write-Host "`n[CONNECTED]: $($dmAuthObject.server)" -ForegroundColor Green
        } else {
            Write-Host "`n[ERROR]: $($dmAuthObject.server)" -ForegroundColor Red
        }

    } # END PROCESS
} # END FUNCTION

function set-dm {
    [CmdletBinding()]
     param (
        [Parameter( Mandatory=$true)]
        [string]$Endpoint,
        [Parameter( Mandatory=$true)]
        [ValidateSet('PUT','POST','PATCH')]
        [string]$Method,
        [Parameter( Mandatory=$true)]
        [int]$Version,
        [Parameter( Mandatory=$false)]
        [object]$Body,
        [Parameter( Mandatory=$true)]
        [string]$Message
    )
    begin {}
    process {
        $retries = @(1..5)
        foreach($retry in $retries) {
            try {
                Write-Host "[(PowerProtect Data Manager)]: $($Message)" -ForegroundColor Yellow 
                if($null -eq $Body) {
                    $action = Invoke-RestMethod -Uri "$($dmAuthObject.server)/v$($Version)/$($Endpoint)" `
                    -Method $Method `
                    -ContentType 'application/json' `
                    -Headers ($dmAuthObject.token) `
                    -SkipCertificateCheck
                } else {
                    $action = Invoke-RestMethod -Uri "$($dmAuthObject.server)/v$($Version)/$($Endpoint)" `
                    -Method $Method `
                    -ContentType 'application/json' `
                    -Body ($Body | ConvertTo-Json -Depth 20) `
                    -Headers ($dmAuthObject.token) `
                    -SkipCertificateCheck
                }
                break;   
            } catch {
                Write-Host "[(PowerProtect Data Manager)]: ERROR: $($Message)`n$($_) `nAttempt: $($retry) of $($retries.length)" -ForegroundColor Red
                Write-Host "[(PowerProtect Data Manager)]: Attempting to recover in 60 seconds...`n" -ForegroundColor Yellow
                Start-Sleep -Seconds 60
                if($retry -eq $retries.length) {
                    throw "[ERROR]: Could not recover from: `n$($_) in $($retries.length) attempts!"
                }
            }
        }
        
        Write-Host "[(PowerProtect Data Manager)]: SUCCESS: $($Message)" -ForegroundColor Green
        
        $match = $action.psobject.Properties.name
        if($match -match "results") {
            return $action.results
        } else {
            return $action
        }
        
    }
}

function get-dm {
    [CmdletBinding()]
     param (
        [Parameter( Mandatory=$true)]
        [int]$Version,
        [Parameter( Mandatory=$true)]
        [string]$Endpoint
    )
    begin {}
    process {

        $Page = 1
        $results = @()

        # CHECK TO SEE IF A FILTER WAS PASSED IN
        $match = $Endpoint -match '\?filter='
        # JOIN THE PATH PARAMS TO THE END POINT
        $join = "&"
        if(!$match) {
            $join = "?"
        }

        $query = Invoke-RestMethod -Uri "$($dmAuthObject.server)/v$($Version)/$($Endpoint)$($join)pageSize=100&page=$($Page)" `
        -Method GET `
        -ContentType 'application/json' `
        -Headers ($dmAuthObject.token) `
        -SkipCertificateCheck

        $results = $query.content
        
         if($query.page.totalPages -gt 1) {
             # INCREMENT THE PAGE NUMBER
             $Page++
             # PAGE THROUGH THE RESULTS
             do {
                 $Paging = Invoke-RestMethod -Uri "$($dmAuthObject.server)/v$($Version)/$($Endpoint)$($join)pageSize=100&page=$($Page)" `
                 -Method GET `
                 -ContentType 'application/json' `
                 -Headers ($dmAuthObject.token) `
                 -SkipCertificateCheck
 
                 # CAPTURE THE RESULTS
                 $results += $Paging.content
 
                 # INCREMENT THE PAGE NUMBER
                 $Page++   
             } 
             until ($Paging.page.number -eq $Query.page.totalPages)
         }

        return $results
    }
}

function disconnect-dmapi {
    [CmdletBinding()]
    param (
    )
    begin {}
    process {
        #LOGOFF OF THE POWERPROTECT API
        Invoke-RestMethod -Uri "$($dmAuthObject.server)/v2/logout" `
        -Method POST `
        -ContentType 'application/json' `
        -Headers ($dmAuthObject.token) `
        -SkipCertificateCheck

        $global:dmAuthObject = $null
    }
} #END FUNCTION

# WORKFLOW
# CONNECT TO THE REST API
connect-dmapi -Server $ppdm

<#
    PROTECTION POLICIES
#>
Write-Host "[PowerProtect]: Getting protection policy information..."
# QUERY FOR THE ASSETS
$policies = get-dm `
-Version 2 `
-Endpoint "protection-policies"

<#
    ASSETS
#>
Write-Host "[PowerProtect]: Getting asset information..."
# DEFINE THE FILTER CRITERIA
$Filters = @(
    "name in(`"$($assets -join '`",`"')`")"
)
# CREATE THE FILTER
$Filter = ($Filters -join ' ') -replace '\s','%20' -replace '"','%22'

# QUERY FOR THE ASSETS
$query = get-dm `
-Version 2 `
-Endpoint "assets?filter=$($Filter)"

<#
    COPIES
#>
Write-Host "[PowerProtect]: Getting copy information..."
$Copies = @()
foreach($asset in $query) {
    
    # STORAGE SYSTEM ID
    $ssId = (
        (
            $policies | `
            Where-Object {$_.id -eq $asset.protectionPolicyId}
            ).stages | `
            Where-Object {$_.type -eq "PROTECTION"}
    ).target.storageSystemId

    # DEFINE THE FILTER CRITERIA
    $Filters = @(
        "storageSystemId eq `"$($ssId)`"",
        "and createTime ge `"$($sDate)`"",
        "and createTime le `"$($eDate)`"",
        "and replicatedCopy eq false",
        "and not state in (`"DELETED`", `"SOFT_DELETED`")"
    )
    # CREATE THE FILTER
    $Filter = ($Filters -join ' ') -replace '\s','%20' -replace '"','%22'
    # QUERY FOR THE COPIES
    $query = get-dm `
    -Version 2 `
    -Endpoint "assets/$($asset.id)/copies?filter=$($Filter)"

    $Copies += $query
}

# BUILD THE REQUEST BODY 
$Body = @{requests = @()}
for($i=0; $i -lt $Copies.count; $i++) {
     
    # GET THE CURRENT RETENTION OF THE COPY
    [datetime]$Retention = Get-Date($Copies[$i].retentionTime)
    # ADD THE $noDays TO THE RETENTION
    [datetime]$Target = $Retention.AddDays($noDays)

    $Body.requests += [ordered]@{
        id = $i
        body = @{
            id = $Copies[$i].id
            retentionTime = "$($Target.toString('O'))"
        }
    }
}

$Report = @()
$Copies | ForEach-Object {
    $newRetention = Get-Date($_.retentionTime).AddDays($noDays)
    $Object = [ordered]@{
        assetId = $_.assetId
        assetName = $_.assetName
        assetType = $_.assetType
        createTime = $_.createTime
        storageSystemId = $_.storageSystemId
        retentionTime = $_.retentionTime
        newRetentionTime =  $newRetention.ToString('O')
        replicatedCopy = $_.replicatedCopy
    }
    $Report += (New-Object -TypeName psobject -Property $Object)
}

if($Extend) {
    Write-Host "[EXTENDING]: Retention time of copies for the defined assets" -ForegroundColor Yellow

    # UPDATE THE RETENTION
    set-dm `
    -Version 2 `
    -Method PATCH `
    -Endpoint 'copies-batch' `
    -Body $Body `
    -Message 'Updating the retention of asset copies'
}

Write-Host "[GENERATING]: Report $($ReportPath)" -ForegroundColor Green
$Report | export-csv $ReportPath -NoTypeInformation

# DISCONNECT FROM THE REST API
disconnect-dmapi