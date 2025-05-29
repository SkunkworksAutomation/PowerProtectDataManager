$servers = @(
    'ppdm-01.vcorp.local',
    'ppdm-02.vcorp.local'
)
$path = "M:\__Dell\__PPDM\19.19"
$package = "dellemc-ppdm-upgrade-sw-19.19.0-15.pkg"

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

# WORKFLOW

foreach($server in $servers) {

    #TIMER
    $StopWatch = New-Object -TypeName System.Diagnostics.Stopwatch
    $StopWatch.start()

    # CONNECT TO THE REST API
    connect-dmapi -Server $server

    try {
        Write-Host "[PowerProtect]: initiating $($package) upload to: $($server)" -ForegroundColor Cyan
        # Define a boundry for the multipart for data
        [string]$boundry = (New-Guid).Guid
        $headers = @{
            Authorization=$dmAuthObject.token.authorization
            "Content-Type"="multipart/form-data;boundary=----$($boundry)"
        }

        # Multipart content
        $mpc = [System.Net.Http.MultipartFormDataContent]::new()

        # Multipart file
        $mpf = "$($path)/$($package)"

        # Filestream
        $fs = [System.IO.FileStream]::new(
            $mpf,
            [System.IO.FileMode]::Open
        )

        # File headers
        $fh = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
        $fh.Name = "file"
        $fh.FileName = "$($path)/$($package)"

        # File content
        $fc = [System.Net.Http.StreamContent]::new($fs)
        $fc.Headers.ContentDisposition = $fh

        # Update the multipart content with the file content
        $mpc.Add($fc)

        # Add the multipart content to the request body
        $body = $mpc
        $upload = Invoke-RestMethod `
        -Uri "$($dmAuthObject.server)/v2/upgrade-packages" `
        -Method POST `
        -Headers $headers `
        -Body $body `
        -SkipCertificateCheck
        
        $StopWatch.stop()
        $Timespan = New-TimeSpan -Milliseconds $StopWatch.ElapsedMilliseconds

        $upload | `
        Select-Object `
        name,
        packageVersion,
        packageDelivery,
        @{l="packageUpload";e={"{0:dd}d:{0:hh}h:{0:mm}m:{0:ss}s" -f $TimeSpan}},
        madeAvailable,
        state | `
        Format-List
    }
    catch {
        $_.Exception.Message
    }
    # DISCONNECT FROM THE REST API
    disconnect-dmapi
}
