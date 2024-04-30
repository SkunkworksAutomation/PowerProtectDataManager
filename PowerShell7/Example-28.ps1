<#
    THIS CODE REQUIRES POWWERSHELL 7.x.(latest)
    https://github.com/PowerShell/powershell/releases

    PROCESS: 
    1.) EXPORT AN ACTIVITY CSV FROM THE UI TO THE SCRIPT DIRECTORY
    2.) REMOVE UNWANTED ASSETS FROM THE CSV AND SAVE
    3.) RUN THE CODE

#>
Import-Module .\dell.ppdm.psm1 -Force

# VARS
$Server = "ppdm-04.vcorp.local"
$PageSize = 100
$Csv = Import-CSV .\assetJobs.csv


# CONNECT THE THE REST API
connect-dmapi -Server $Server

$Csv | ForEach-Object {
    
    # GET ACTIVITIES BASED ON FILTERS
    $Filters = @(
        "classType eq `"JOB`"",
        "and category eq `"PROTECT`"",
        "and state in (`"RUNNING`",`"QUEUED`")",
        "and asset.name eq `"$($_.'Asset Name' -replace '\\','%5C%5C')`""
    )

    $activities = get-dmactivities -Filters $Filters -PageSize $PageSize

    if($activities.length -gt 0) {
        foreach($activity in $activities){
            <#
                CANCEL AN ACTIVITY
                IT MUST BE IN A RUNNING OR QUEUED STATE
            #>
            Write-Host "[$($Server)]: Canceling activity id: $($activity.id) for $($activity.asset.name)" -ForegroundColor Yellow
            stop-dmactivity -Id $activity.Id
               
        }
    } else {
        Write-Host "[$($Server)]: No RUNNING or QUEUED activity found for $($_.'Asset Name')" -ForegroundColor Red
    }

} # END FOREACH

# DISCONNECT FROM THE REST API
disconnect-dmapi
