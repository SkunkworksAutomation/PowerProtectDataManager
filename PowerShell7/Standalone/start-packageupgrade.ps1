$servers = @(
    'ppdm-01.vcorp.local',
    'ppdm-02.vcorp.local'
)

$packageVersion = "19.19.0-15"

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
        if($query.content){
            $results = $query.content
        } else {
            $results = $query
        }
                
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
                if($query.content){
                    $results = $Paging.content
                } else {
                    $results = $Paging
                }

                # INCREMENT THE PAGE NUMBER
                $Page++   
            } 
            until ($Paging.page.number -eq $Query.page.totalPages)
        }

        return $results
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
                Write-Host "[PowerProtect]: $($Message)" -ForegroundColor Yellow 
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
                Write-Host "[PowerProtect]: ERROR: $($Message)`n$($_) `nAttempt: $($retry) of $($retries.length)" -ForegroundColor Red
                Write-Host "[PowerProtect]: Attempting to recover in 60 seconds...`n" -ForegroundColor Yellow
                Start-Sleep -Seconds 60
                if($retry -eq $retries.length) {
                    throw "[ERROR]: Could not recover from: `n$($_) in $($retries.length) attempts!"
                }
            }
        }
        
        Write-Host "[PowerProtect]: SUCCESS: $($Message)" -ForegroundColor Green
        $match = $action.psobject.Properties.name
        if($match -match "results") {
            return $action.results
        } else {
            return $action
        }
    } # END PROCESS
} # END FUNCTION

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
    } # END PROCESS
} # END FUNCTION

<#
    # GETTER EXAMPLE
    $policies = get-dm `
    -Version 2 `
    -Endpoint "protection-policies"

    # SETTER EXAMPLE
    set-dm `
    -Version 2 `
    -Method PATCH `
    -Endpoint 'copies-batch' `
    -Body $Body `
    -Message 'Updating the retention of asset copies'
#>
# WORKFLOW

foreach($server in $servers) {

    #TIMER
    $StopWatch = New-Object -TypeName System.Diagnostics.Stopwatch
    $StopWatch.start()

    # CONNECT TO THE REST API
    connect-dmapi -Server $server

    # Query for the upgrade package
    Write-Host "[PowerProtect]: Querying for $($packageVersion) package on: $($server)" -ForegroundColor Cyan
    $filters = @(
        "packageVersion eq `"$($packageVersion)`""
        "and state eq `"AVAILABLE`""
    )
    $query = get-dm `
    -Version 2 `
    -Endpoint "upgrade-packages?filter=$($filters)"
    
    # pre-check the package
    $precheck = set-dm `
    -Version 2 `
    -Method POST `
    -Endpoint "upgrade-packages/$($query.id)/precheck" `
    -Message "Initiating precheck of $($packageVersion) upgrade on: $($server)"
    $precheck | Select-Object packageVersion,state | Format-Table -AutoSize

    # Monitor the status
    do {
        $monitor = get-dm `
        -Version 2 `
        -Endpoint "upgrade-packages/$($query.id)"

        if($monitor.state -ne "AVAILABLE"){
            Write-Host "[PowerProtect]: Package state: $($monitor.state). Retry in 15 seconds..." -ForegroundColor Yellow
            start-sleep -Seconds 15
        }
    }
    until($monitor.state -eq "AVAILABLE")

    # UPDATE THE REQUEST BODY
    # PowerProtect Data Manager returns the sizeInBytes in scientific notation
    # "sizeInBytes": 1.6941321031E10,
    # PowerProtect Data Manager expects an integer in the PUT 
    $query.sizeInBytes = [long]$query.sizeInBytes*10
    # Accept the upgrade certificate
    $query.certificateTrustedByUser = $true
    # Add the eula property
    $query | Add-Member -MemberType NoteProperty -Name eula -Value $null -Force
    $query.eula = [ordered]@{
        productEulaChanged = $true
        telemetryEulaChanged = $false
        productEulaAccepted = $true
    }
    # Update the package state to INSTALLED
    $query.state = "INSTALLED"

    # Start the upgrade
    try {
        set-dm `
        -Version 2 `
        -Method PUT `
        -Endpoint "upgrade-packages/$($query.id)?forceUpgrade=true" `
        -Body $query `
        -Message "Initiating $($package) upgrade on: $($server)" | `
        Out-Null
    }
    catch {
        $_.Exception.Message
    }

    # DISCONNECT FROM THE REST API
    disconnect-dmapi
}
