<#
    THIS CODE REQUIRES POWWERSHELL 7.x.(latest)
    https://github.com/PowerShell/PowerShell/releases/tag/v7.3.3
#>

Import-Module .\dell.ppdm.psm1 -Force
$ppdm = 'ppdm-01.vcorp.local'
$pagesize = 25
$Results = @()
connect-ppdmapi -Server $ppdm

# GRAB INFO FROM A CSV FILE
$sql = Import-Csv .\ppdm-sql-hosts.csv
<#
    fqdn,credentials
    vc1-sql-02.vcorp.local,MSSQL
    vc1-sql-03.vcorp.local,MSSQL
#>

<#
# GRAB INFO FROM A HASH TABLE
$sql = @(
    @{
        fqdn = 'vc1-sql-02.vcorp.local'
        credentials = 'MSSQL'
    },
    @{
        fqdn = 'vc1-sql-03.vcorp.local'
        credentials = 'MSSQL'
    }
)
#>

<#
   SET THE OS CREDENTIALS ON THE ASSET SOURCE
#>

# ITERATE OVER THE CONTENTS OF THE CSV FILE
$sql | foreach-object {

    # QUERY PPDM FOR THE ASSET SOURCE NAME
    $Filters = @(
        "name eq `"$($_.fqdn)`""
    )
    $SqlHost = get-sqlhosts -Filters $Filters
    # $SqlHost | format-list

    # QUERY PPDM FOR THE CREDENTIALS NAME
    $Filters = @(
        "name eq `"$($_.credentials)`""
    )
    $Credentials = get-sqlcredentials -Filters $Filters
    # $Credentials | format-list

    # ASSIGN THE CREDENTIALS
    set-sqlcredentials -SqlId $SqlHost.id -CredId $Credentials.id -Operation Assign

    # UNASSIGN THE CREDENTIALS
    # set-sqlcredentials -SqlId $SqlHost.id -Operation Unassign

}



# $Results 

disconnect-ppdmapi
