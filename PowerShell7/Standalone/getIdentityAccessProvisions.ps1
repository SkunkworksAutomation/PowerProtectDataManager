# GLOBAL VARS
$global:ApiVersion = 'v2'
$global:Port = 8443
$global:AuthObject = $null

# VARS
$Servers = @(
    "ppdm-01.vcorp.local"
)
$Retires = @(1..5)
$Seconds = 10
$PageSize = 100

function connect-dmapi {
<#
    .SYNOPSIS
    Connect to the PowerProtect Data Manager REST API.

    .DESCRIPTION
    Creates a credentials file for PowerProtect Data Manager if one does not exist.
    Connects to the PowerProtect Data Manager REST API

    .PARAMETER Server
    Specifies the FQDN of the PowerProtect Data Manager server.

    .OUTPUTS
    System.Object 
    $global:AuthObject

    .EXAMPLE
    PS> connect-ppdmapi -Server 'ppdm-01.vcorp.local'

    .LINK
    https://developer.dell.com/apis/4378/versions/19.14.0/docs/getting%20started/authentication-and-authorization.md

#>
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
        $Login = @{
            username="$($Credential.username)"
            password="$($Credential.GetNetworkCredential().Password)"
        }
        # LOGON TO THE POWERPROTECT API 
        $Auth = Invoke-RestMethod -Uri "https://$($Server):$($Port)/api/$($ApiVersion)/login" `
                    -Method POST `
                    -ContentType 'application/json' `
                    -Body (ConvertTo-Json $Login) `
                    -SkipCertificateCheck
        $Object = @{
            server ="https://$($Server):$($Port)/api/$($ApiVersion)"
            token= @{
                authorization="Bearer $($Auth.access_token)"
            } #END TOKEN
        } #END AUTHOBJ

        $global:AuthObject = $Object

        Write-Host "`n$($global:AuthObject.server)" -ForegroundColor green

    } #END PROCESS
} # END FUNCTION

function get-identityprovisions {
    <#
        .SYNOPSIS
        Get PowerProtect Data Manager protection policies
        
        .DESCRIPTION
        Get PowerProtect Data Manager protection policies based on filters
    
        .PARAMETER Filters
        An array of values used to filter the query
    
        .PARAMETER PageSize
        An int representing the desired number of elements per page
    
        .OUTPUTS
        System.Array
    
        .EXAMPLE
        PS> # Get identity-access-provisions
        PS>  $id = get-identityprovisions -PageSize 100
    
    #>
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$false)]
        [array]$Filters,
        [Parameter( Mandatory=$true)]
        [int]$PageSize
    )
    begin {}
    process {
        
        $Page = 1
        $Results = @()
        $Endpoint = "identity-access-provisions"

        if($Filters.Length -gt 0) {
            $Join = ($Filters -join ' ') -replace '\s','%20' -replace '"','%22'
            $Endpoint = "$($Endpoint)?filter=$($Join)"
        }else {
            $Endpoint = "$($Endpoint)?"
        }
        $Query =  Invoke-RestMethod -Uri "$($AuthObject.server)/$($Endpoint)pageSize=$($PageSize)&page=$($Page)" `
        -Method GET `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -SkipCertificateCheck

        # CAPTURE THE RESULTS
        $Results = $Query.content
        
        if($Query.page.totalPages -gt 1) {
            # INCREMENT THE PAGE NUMBER
            $Page++
            # PAGE THROUGH THE RESULTS
            do {
                $Paging = Invoke-RestMethod -Uri "$($AuthObject.server)/$($Endpoint)pageSize=$($PageSize)&page=$($Page)" `
                -Method GET `
                -ContentType 'application/json' `
                -Headers ($AuthObject.token)

                # CAPTURE THE RESULTS
                $Results += $Paging.content

                # INCREMENT THE PAGE NUMBER
                $Page++   
            } 
            until ($Paging.page.number -eq $Query.page.totalPages)
        }
        return $Results

    } # END PROCESS
}

function disconnect-dmapi {
<#
    .SYNOPSIS
    Disconnect from the PowerProtect Data Manager REST API.

    .DESCRIPTION
    Destroys the bearer token contained with $global:AuthObject

    .OUTPUTS
    System.Object 
    $global:AuthObject

    .EXAMPLE
    PS> disconnect-dmapi

    .LINK
    https://developer.dell.com/apis/4378/versions/19.14.0/docs/getting%20started/authentication-and-authorization.md

#>
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
} # END FUNCTION

# WORKFLOW
$Report = @()
$Servers | foreach-object {
    foreach($Retry in $Retires){
        try {
            # CONNECT THE THE REST API
            connect-dmapi -Server $_

            $Ids = get-identityprovisions -PageSize $PageSize

            foreach($Id in $Ids) {

                if($Id.identityProvider.serviceMarker -match "active-directory") {
                    $Members = Get-AdGroupMember -Identity "$($Id.subject)"
                    foreach($Member in $Members) {
                        $object = [ordered]@{
                            ppdm = $_
                            group = "$($Id.identityProvider.selector)\$($Id.subject)"
                            roles = $Id.access.role.name -join ','
                            user = "$($Member.name)"
                            id = "$($Member.samaccountname)"
                        } # END OBJECT
                        $Report += (New-Object -TypeName psobject -Property $object)

                    } # END FOREACH
                    
                } else {
                    $object = [ordered]@{
                            ppdm = $_
                            group = "local"
                            roles = $Id.access.role.name -join ','
                            user = "$($Id.subject)"
                            id = "$($Id.subject)"
                        } # END OBJECT
                    $Report += (New-Object -TypeName psobject -Property $object)
                }
            }
            # DISCONNECT FROM THE API
            disconnect-dmapi
            break;
        }
        catch {
            if($Retry -lt $Retires.length) {
                Write-Host "[WARNING]: $($_). Sleeping $($Seconds) seconds... Attempt #: $($Retry)" -ForegroundColor Yellow
                Start-Sleep -Seconds $Seconds
            } else {
                Write-Host "[ERROR]: $($_). Attempts: $($Retry), moving on..." -ForegroundColor Red
            }
        } # END TRY / CATCH
    } # END RETRIES
    
    
} # END FOREACH

$Report | format-table -autosize