<#
    THIS CODE REQUIRES: 
    
    POWWERSHELL 7.x.(latest)
    https://github.com/PowerShell/PowerShell/releases
    
    VMWARE POWERCLI
    https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.esxi.install.doc/GUID-F02D0C2D-B226-4908-9E5C-2E783D41FE2D.html
    
    CHECK THE CURRENT SYSTEM
    get-module -ListAvailable -Name VMware.PowerCLI

    INSTALL ON THE CURRENT SYSTEM
    install-module VMware.PowerCLI -Scope CurrentUser

    SET POWERCLI TO IGNORE THE VCENTER CERTIFICATE    	
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

    POSH-SSH
    https://www.powershellgallery.com/packages/Posh-SSH/

    INSTALL ON THE CIRRENT SYSTEM
    Install-Module -Name Posh-SSH

    TESTED ON:
     - POWERPROTECT DATA MANAGER: 
     - 19.16.0-11
#>

# POWERPROTECT DATA MANAGER
$ppdm = "ppdm-01.vcorp.local"
$pagesize = 100

# VCENTER
$vcenter = "vc-01.vcorp.local"

# ACTIVE DIRECTORY DOMAIN
$domain = "vcorp.local"

# REPORT PARANS
$Date = Get-Date
[array]$Report = @()
$ReportFile = ".\$($Date.ToString('yyyy-MM-dd'))-whitespace.csv"


# DO NOT MODIFY BELOW THIS LINE
$global:ApiVersion = 'v2'
$global:Port = 8443
$global:AuthObject = $null
$global:vcAuthObject = $null

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
            password="$(ConvertFrom-SecureString -SecureString $Credential.password -AsPlainText)"
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

        $global:AuthObject | Format-List

    } #END PROCESS
} #END FUNCTION

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
} #END FUNCTION

function get-dmassets {
<#
    .SYNOPSIS
    Get PowerProtect Data Manager assets

    .DESCRIPTION
    Get PowerProtect Data Manager assets based on filters

    .PARAMETER Filters
    An array of values used to filter the query

    .PARAMETER PageSize
    An int representing the desired number of elements per page

    .OUTPUTS
    System.Array

    .EXAMPLE
    PS> # GET ASSETS BASED ON A FILTER
    PS> $Filters = @(
    "name eq `"vc1-ubu-01`""
    )
    PS> $Assets = get-dmassets -Filters $Filters -PageSize $PageSize

    .EXAMPLE
    PS> # GET ALL ASSETS
    PS> $Assets = get-dmassets -PageSize $PageSize

    .LINK
    https://developer.dell.com/apis/4378/versions/19.14.0/reference/ppdm-public.yaml/paths/~1api~1v2~1assets/get

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
        
        $Results = @()
        
        $Endpoint = "assets"
        if($Filters.Length -gt 0) {
            $Join = ($Filters -join ' ') -replace '\s','%20' -replace '"','%22'
            $Endpoint = "$($Endpoint)?filter=$($Join)&pageSize=$($PageSize)"
        } else {
            $Endpoint = "$($Endpoint)?pageSize=$($PageSize)"
        }

        $Query =  Invoke-RestMethod -Uri "$($AuthObject.server)/$($Endpoint)&queryState=BEGIN" `
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
function connect-vcenter {
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
            $Credential = Get-Credential -Message "Enter you vCenter credentials"
            $Credential | Export-CliXml ".\$($Server).xml"
        } 
    }
    process {
        
        $global:vcAuthObject = Connect-VIServer -Server $Server -Protocol https -Credential $Credential
        $global:vcAuthObject | Format-List
    }
}
# WORKFLOW
# CHECK FOR ALL OF THE CREDENTIALS
# POWERPROTECT
$Exists = Test-Path -Path ".\$($ppdm).xml" -PathType Leaf
if($Exists) {
    $dmCreds = Import-CliXml ".\$($ppdm).xml"
} else {
    $dmCreds = Get-Credential -Message "Enter your powerprotect data manager credentials"
    $dmCreds | Export-CliXml ".\$($ppdm).xml"
} 
# VCENTER
$Exists = Test-Path -Path ".\$($vcenter).xml" -PathType Leaf
if($Exists) {
    $vcCreds = Import-CliXml ".\$($vcenter).xml"
} else {
    $vcCreds = Get-Credential -Message "Enter your vCenter credentials"
    $vcCreds | Export-CliXml ".\$($vcenter).xml"
} 
# WINDOWS
$Exists = Test-Path -Path ".\windows.xml" -PathType Leaf
if($Exists) {
    $wnCreds = Import-CliXml ".\windows.xml"
} else {
    $wnCreds = Get-Credential -Message "Enter your windows credentials"
    $wnCreds | Export-CliXml ".\windows.xml"
} 
# LINUX
$Exists = Test-Path -Path ".\linux.xml" -PathType Leaf
if($Exists) {
    $lxCreds = Import-CliXml ".\linux.xml"
} else {
    $lxCreds = Get-Credential -Message "Enter your linux credentials"
    $lxCreds | Export-CliXml ".\linux.xml"
}

# CLEAN UP OPEN SSH SESSIONS
if(Get-SSHTrustedHost) {
    Write-Host "`n[POSH-SSH]: Cleaning up stored SSH host keys." -ForegroundColor Yellow
    (Get-SSHTrustedHost | Remove-SSHTrustedHost) | Out-Null
}

# CONNECT TO THE REST API
connect-dmapi -Server $ppdm 

# QUERY FOR PROTECTED VM ASSERTS
Write-Host "[PowerProtect]: Collecting protected virtual machine assets information" -ForegroundColor Green
$Filters = @(
    "type eq `"VMWARE_VIRTUAL_MACHINE`"",
    "and protectionStatus eq `"PROTECTED`""
)
$assets = get-dmassets -Filters $Filters -PageSize $PageSize

# DISCONNECT API
disconnect-dmapi

# CONNECT TO VCENTER
connect-vcenter -Server $vcenter

# GET VCENTER INFORMATION
Write-Host "[vMWare]: Collecting vCenter build information" -ForegroundColor Green
$ThisVc = $global:DefaultVIServers | Select-Object Name, Version, Build

# GET THE VIRTUAL MACHINES VIEW
Write-Host "[vMWare]: Collecting data from virtualmachine view" -ForegroundColor Green
$view = Get-VIew -ViewType VirtualMachine

Write-Host "[vMWare]: Disconnecting from: $($ThisVc.Name)`n" -ForegroundColor Yellow
Disconnect-VIServer -Server $ThisVc.Name -Force -Confirm:$false

foreach($asset in ($assets | sort-object Name)) {
    # QUERY THE VIEW FOR THE ASSET
    $vm = $view | Where-Object {$_.name -eq $asset.name}
    
    # AGGERATE DISKS
    [decimal]$Capacity = 0;
    [decimal]$FreeSpace = 0;
    # [decimal]$Used = 0;

    $vm.Guest.Disk | ForEach-Object {
        $Capacity = ($Capacity + $_.Capacity)
        $FreeSpace = ($FreeSpace + $_.FreeSpace)
    }

    $vmCapacity = $Capacity /1GB
    $vmFreeSpace = $FreeSpace /1GB
    $vmUsedSpace = ($Capacity - $FreeSpace) /1GB

    # QUERY THE OPERATING SYSTEM
    # AGGERATE DISKS
    [decimal]$Capacity = 0;
    [decimal]$FreeSpace = 0;

    if($vm.Guest.GuestFullName -match "^Microsoft") {
        Write-Host "[WINDOWS]: Collecting hard drive information on $($vm.Name)"
        $DiskCmd = Invoke-Command -ComputerName "$($vm.Name).$($domain)" -ScriptBlock {
            Get-PSDrive | `
            where-object {$_.Root -match "^[A-Z]:\\$" -and $_.Used -gt 0 -and $_.DisplayRoot -notmatch '^\\'}
        } -Credential $wnCreds
        
        $DiskCmd | ForEach-Object {
            $Capacity = $Capacity + ($_.Used + $_.Free)
            $FreeSpace = $FreeSpace + $_.Free
        }

        $osUsedSpace = ($Capacity - $FreeSpace) /1GB
        $osFreeSpace = $FreeSpace /1GB
        $osCapacity = $Capacity /1GB
       
    } else {
        <# 
            dell@uubu-fsa-01:~$ df -h --total
            Filesystem                         Size  Used Avail Use% Mounted on
            udev                               1.9G     0  1.9G   0% /dev
            tmpfs                              392M  1.3M  391M   1% /run
            /dev/mapper/ubuntu--vg-ubuntu--lv   12G  5.7G  5.3G  52% /
            tmpfs                              2.0G     0  2.0G   0% /dev/shm
            tmpfs                              5.0M     0  5.0M   0% /run/lock
            tmpfs                              2.0G     0  2.0G   0% /sys/fs/cgroup
            /dev/loop2                          41M   41M     0 100% /snap/snapd/20671
            /dev/loop1                          68M   68M     0 100% /snap/lxd/21835
            /dev/loop3                          92M   92M     0 100% /snap/lxd/24061
            /dev/loop4                          64M   64M     0 100% /snap/core20/2105
            /dev/sda2                          1.5G  209M  1.2G  16% /boot
            /dev/loop5                          64M   64M     0 100% /snap/core20/2182
            tmpfs                              392M     0  392M   0% /run/user/1000
            total                               20G  6.2G   13G  33% -
        #>

        $ssh = New-SSHSession `
        -ComputerName "$($vm.Name).$($domain)" `
        -Credential $lxCreds `
        -AcceptKey `
        -KeepAliveInterval 600

        Write-Host "[LINUX]: Collecting hard drive information on $($vm.Name)"
        $DiskCmd = Invoke-SSHCommand -Command "df -h --total" -SessionId $ssh.SessionId
        
        ($DiskCmd.Output | Select-Object -Skip 1) -split '`n' | ForEach-Object {
            $columns = $_ -split '\s+' | Select-Object -skiplast 2;
    
            if($columns[0] -eq 'total') {
                # LINUX
                $osUsedSpace = $columns[2] -replace '[G|M|K]$'
                $osFreeSpace = $columns[3] -replace '[G|M|K]$'
                $osCapacity = $columns[1] -replace '[G|M|K]$'
            }  
        }
        
        
              
        if(Get-SSHSession) {
            (Get-SSHSession | Remove-SSHSession) | Out-Null
        }
    }
    # BUILD THE REPORT OBJECT
    $Object = [ordered]@{
        vCenter = $ThisVc.Name
        Version = $ThisVc.Version
        Build = $ThisVc.Build
        ToolsVersion = $vm.Guest.ToolsVersion
        ToolsRunningStatus = $vm.Guest.ToolsRunningStatus
        Guest = $vm.Name
        OS = $vm.Guest.GuestFullName
        PowerState = $vm.Summary.Runtime.PowerState
        vmUsedSpaceGB = $vmUsedSpace
        vmFreeSpaceGB = $vmFreeSpace
        vmCapacityGB = $vmCapacity
        osUsedSpaceGB = $osUsedSpace
        osFreeSpaceGB = $osFreeSpace
        osCapacityGB = $osCapacity        
    }

    $Report += (New-Object -TypeName psobject -Property $Object)
}
$Report | sort-object Guest | Export-csv -Path $ReportFile
$Report | sort-object Guest | Select-Object Guest,vmCapacityGB,vmFreeSpaceGB,vmUsedSpaceGB,osCapacityGB,osFreeSpaceGB,osUsedSpaceGB | Format-Table -AutoSize