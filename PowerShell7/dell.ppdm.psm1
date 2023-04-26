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

function set-activity {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$false)]
        [string]$Id
    )
    begin {
        
    } #END BEGIN
    process {
        $Results = @()
        $Endpoint = "activities/$($Id)/cancel"

        
        $Action =  Invoke-RestMethod -Uri "$($AuthObject.server)/$($Endpoint)" `
        -Method POST `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -Body ($Body | convertto-json -Depth 10) `
        -SkipCertificateCheck
        $Results += $Action

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

function set-policy {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$false)]
        [object]$Policy,
        [Parameter( Mandatory=$false)]
        [bool]$Enabled
    )
    begin {
        
    } #END BEGIN
    process {
        $Results = @()
        $Endpoint = "protection-policies-batch"
        $Endpoint

        $Body = [ordered]@{
            requests = @(
                @{
                    id = 1
                    body = @{
                        id= $Policy.id
                        enabled = $Enabled
                    }
                }
            )
        }
        $Action =  Invoke-RestMethod -Uri "$($AuthObject.server)/$($Endpoint)" `
        -Method PATCH `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -Body ($Body | convertto-json -Depth 10) `
        -SkipCertificateCheck
        $Results += $Action.content

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

function get-drserverconfig {
    [CmdletBinding()]
    param (
    )
    begin {
        
    } #END BEGIN
    process {
        $Endpoint = "server-disaster-recovery-configurations"
        
        $Query =  Invoke-RestMethod -Uri "$($AuthObject.server)/$($Endpoint)" `
        -Method GET `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -SkipCertificateCheck
 
        return $Query.content
    }
}

function set-drserverconfig {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$false)]
        [string]$PPDM,
        [Parameter( Mandatory=$false)]
        [string]$DataDomain,
        [Parameter( Mandatory=$false)]
        [string]$ConfigId
    )
    begin {
         # CHECK TO SEE IF CREDS FILE EXISTS IF NOT CREATE ONE
        $Exists = Test-Path -Path ".\$($DataDomain).xml" -PathType Leaf
        if($Exists) {
            $Credential = Import-CliXml ".\$($DataDomain).xml"
        } else {
            $Credential = Get-Credential -Message "Please enter your PowerProtect DD credentials"
            $Credential | Export-CliXml ".\$($DataDomain).xml"
        } 
    } #END BEGIN
    process {
        $Endpoint = "server-disaster-recovery-configurations/$($ConfigId)"

        # PARSE OUT THE PPDM FQDN
        $ppdm = (($AuthObject.server) -split 'https://' | select-object -Last 1) -split ':' | select-object -First 1

        $Body = @{
            id= "$($ConfigId)"
            repositoryHost="$($DataDomain)"
            repositoryPath=""
            repositoryFilesystem="BOOST_FILE_SYSTEM"
            credentialUsername="$($ppdm)"
            credentialPassword="$(ConvertFrom-SecureString -SecureString $Credential.password -AsPlainText)"
        }
        
        $Query =  Invoke-RestMethod -Uri "$($AuthObject.server)/$($Endpoint)" `
        -Method PUT `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -Body ($Body | convertto-json) `
        -SkipCertificateCheck
    
        return $Query
        
    }
}

function get-drserverhosts {
     [CmdletBinding()]
    param (
        [Parameter( Mandatory=$false)]
        [string]$Version
    )
    begin {

    } #END BEGIN
    process {
        $Endpoint = "server-disaster-recovery-hosts?filter=version eq `"$($Version)`""
        
        $Query =  Invoke-RestMethod -Uri "$($AuthObject.server)/$($Endpoint)" `
        -Method GET `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -SkipCertificateCheck
    
        return $Query.content
    }
}

function get-drserverbackups {
     [CmdletBinding()]
    param (
        [Parameter( Mandatory=$false)]
        [string]$NodeId
    )
    begin {

    } #END BEGIN
    process {
        $Endpoint = "server-disaster-recovery-backups?filter=nodeId eq `"$($NodeId)`""
        
        $Query =  Invoke-RestMethod -Uri "$($AuthObject.server)/$($Endpoint)" `
        -Method GET `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -SkipCertificateCheck

        # ASSUMES YOU WANT THE LATEST BACKUP
        return $Query.content[0]
    }
}

function new-drserverrecovery {
     [CmdletBinding()]
    param (
        [Parameter( Mandatory=$false)]
        [object]$Backup
    )
    begin {

    } #END BEGIN
    process {
        $Endpoint = "server-disaster-recovery-backups/$($Backup.id)"
        
        # ADD THE RECOVER PROPERTY TO THE REQUEST BODY
        $Backup | Add-Member -NotePropertyName recover -NotePropertyValue $true 

        $Action =  Invoke-RestMethod -Uri "$($AuthObject.server)/$($Endpoint)" `
        -Method PUT `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -Body ($Backup | convertto-json -Depth 50) `
        -SkipCertificateCheck

        return $Action
    }
}