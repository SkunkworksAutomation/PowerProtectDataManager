<#
    THIS CODE REQUIRES POWWERSHELL 7.x.(latest)
    https://github.com/PowerShell/PowerShell/releases/tag/v7.3.3
#>

$global:ApiVersion = 'v2'
$global:AuthObject = $null

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
function get-activities {
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
        $Endpoint = "activities"
        
        if($Filters.Length -gt 0) {
            $Join = ($Filters -join ' ') -replace '\s','%20' -replace '"','%22'
            $Endpoint = "activities?filter=$($Join)"
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
    }
}

function get-alerts {
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
        $Endpoint = "alerts"
        
        if($Filters.Length -gt 0) {
            $Join = ($Filters -join ' ') -replace '\s','%20' -replace '"','%22'
            $Endpoint = "alerts?filter=$($Join)"
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
    }
}

function set-password {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$true)]
        [object]$IAM
    )
    begin {
        
    } #END BEGIN
    process {
        # QUERY FOR THE CREDENTIALS WE WANT TO UPDATE
        $Creds = Invoke-RestMethod -Uri "$($AuthObject.server)/credentials?filter=name eq `"$($IAM.id)`"" `
        -Method GET `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -SkipCertificateCheck

        # CREATE THE REQUEST BODY FROM THE IAM RESULTS AND PPDM REST API
        $Body = [ordered]@{
            requests = @(
                @{
                    id=0
                    body=@{
                        id= $Creds.content[0].id
                        password= $IAM.secret
                    }
                }
            )
        }
        # UPDATE THE CREDENTIALS
        $Update =  Invoke-RestMethod -Uri "$($AuthObject.server)/credentials-batch" `
        -Method PATCH `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -Body ($Body | Convertto-Json -Depth 10) `
        -SkipCertificateCheck

        # MONITOR THE PAWWORD UPDATE ACTIVITY
        do {
            #POLL THE RECOVERY ACTIVITY EVERY 60 SECONDS UNTIL COMPLETE
            $Monitor = Invoke-RestMethod -Uri "$($AuthObject.server)/activities/$($Update.activityId)" `
            -Method GET `
            -ContentType 'application/json' `
            -Headers ($AuthObject.token) `
            -SkipCertificateCheck

            if($Monitor.state -eq "QUEUED") {
                Write-Host "[ACTIVITY]: $($Update.activityId), State = $($Monitor.state), Sleeping 5 seconds..." -ForegroundColor Yellow
                Start-Sleep -Seconds 5
            } elseif($Monitor.state -eq "RUNNING") {
                Write-Host "[ACTIVITY]: $($Update.activityId), State = $($Monitor.state), Sleeping 5 seconds..."
                Start-Sleep -Seconds 5
            } else {
                Write-Host "[ACTIVITY]: $($Update.activityId), State = $($Monitor.state)" -ForegroundColor Green
            }    
        } 
        until($Monitor -and $Monitor.state -eq "COMPLETED")

        Write-Host "`n[PowerProtect Data Manager]: Database server lockboxes will now automatically be updated."
    }
} #END FUNCTION

function get-policy {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$true)]
        [array]$Filters,
        [Parameter( Mandatory=$true)]
        [int]$PageSize
    )
    begin {
        
    } #END BEGIN
    process {
        $Results = @()
        $Endpoint = "protection-policies"
        
        if($Filters.Length -gt 0) {
            $Join = ($Filters -join ' ') -replace '\s','%20' -replace '"','%22'
            $Endpoint = "protection-policies?filter=$($Join)"
        }
        $Endpoint

        $Query =  Invoke-RestMethod -Uri "$($AuthObject.server)/$($Endpoint)&pageSize=$($PageSize)" `
        -Method GET `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -SkipCertificateCheck
        $Results += $Query.content

        return $Results
    }
}

function set-policyassignment {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$true)]
        [string]$PolicyId,
        [Parameter( Mandatory=$true)]
        [ValidateSet("Assign", "Unassign")]  
        [string]$Operation,
        [Parameter( Mandatory=$true)]
        [array]$Assets
    )
    begin {
        
    } #END BEGIN
    process {
        if($Operation -eq "Assign") {
            $Endpoint = "protection-policies/$($PolicyId)/asset-assignments"
        } else {
            $Endpoint = "protection-policies/$($PolicyId)/asset-unassignments"
        }

        $Endpoint

        $Action =  Invoke-RestMethod -Uri "$($AuthObject.server)/$($Endpoint)" `
        -Method POST `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -Body ($Assets.id | convertto-json) `
        -SkipCertificateCheck
 
        return $Action
    }
}

function get-sqlhosts {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$true)]
        [array]$Filters
    )
    begin {
        
    } #END BEGIN
    process {
        $Results = @()
        $Endpoint = "hosts"
        
        if($Filters.Length -gt 0) {
            $Join = ($Filters -join ' ') -replace '\s','%20' -replace '"','%22'
            $Endpoint = "$($Endpoint)?filter=$($Join)"
        }
        $Endpoint

        $Query =  Invoke-RestMethod -Uri "$($AuthObject.server)/$($Endpoint)" `
        -Method GET `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -Body ($Assets.id | convertto-json) `
        -SkipCertificateCheck
 
        return $Query.content
    }
}

function get-sqlcredentials {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$true)]
        [array]$Filters
    )
    begin {
        
    } #END BEGIN
    process {
        $Results = @()
        $Endpoint = "credentials"
        
        if($Filters.Length -gt 0) {
            $Join = ($Filters -join ' ') -replace '\s','%20' -replace '"','%22'
            $Endpoint = "$($Endpoint)?filter=$($Join)"
        }
        $Endpoint

        $Query =  Invoke-RestMethod -Uri "$($AuthObject.server)/$($Endpoint)" `
        -Method GET `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -Body ($Assets.id | convertto-json) `
        -SkipCertificateCheck
 
        return $Query.content
    }
}

function set-sqlcredentials {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$false)]
        [object]$SqlHost,
        [Parameter( Mandatory=$false)]
        [string]$CredId,
        [Parameter( Mandatory=$true)]
        [ValidateSet("Assign", "Unassign")]
        [string]$Operation

    )
    begin {
        
    } #END BEGIN
    process {
        $Results = @()
        $Endpoint = "hosts"
        
        $Endpoint

        if($Operation -eq 'Assign') {
           $Body = [ordered]@{
                id = $SqlHost.id
                type = 'APP_HOST'
                details = @{
                    appHost = @{
                        dbConnection = @{
                            type = 'OS'
                            credentialId = "$($CredId)"
                            configureCredential = $true
                            tnsName = $null
                            tnsAdmin = $null
                        }
                    }
                }
                applicationsOfInterest = @(
                    [ordered]@{
                        name = "$($SqlHost.details.appHost.applicationsOfInterest.name)"
                        version = "$($SqlHost.details.appHost.applicationsOfInterest.version)"
                        type =  "$($SqlHost.details.appHost.applicationsOfInterest.type)"
                        updateCapable = $true
                        pushHostCredential = $true
                    }
                )
            }
        } else {
             $Body = [ordered]@{
                id = $SqlHost.id
                type = 'APP_HOST'
                details = @{
                    appHost = @{
                    }
                }
            }
        }
     
        $Action =  Invoke-RestMethod -Uri "$($AuthObject.server)/$($Endpoint)/$($SqlHost.id)" `
        -Method PUT `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -Body ($Body | convertto-json -Depth 10) `
        -SkipCertificateCheck
 
        return $Action
        
    }
}