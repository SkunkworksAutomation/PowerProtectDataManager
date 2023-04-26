# Scripts (API version 19.12):
## Modules: 
* dell.ppdm.psm1 (API version 19.12)
    * PowerShell7 module that covers basic interaction with the PowerProtect Data Manager REST API
    * Functions
        * connect-ppdmapi: method to request a bearer token
        * disconnect-ppdmapi: method to destroy a bearer token
        * get-assets: method to query for assets based on filter
        * get-activities: method to query for activities based on filter
        * get-alerts: method to query for alerts based on filter
        * set-password: method of setting the ddboost user password, assigned to a protection policy, in PowerProtect Datamanager
        * get-policy: method to query for protection policies based on filter
        * set-policy: method to enable, or disable a protection policy
        * set-policyassignment: method to batch assign, or unassign assets to a protection policy based on policy id, and assets id
        * get-sqlhosts: method to query for sql hosts based on filter
        * get-sqlcredentials: method to query for credentials
        * set-sqlcredentials: method to assign, or unassign credentials to a sql host
        * get-drserverconfig: method to the default dr recovery config
        * set-drserverconfig: method to update the default dr config
        * get-drserverhosts: method to get the dr server hosts
        * get-drserverbackups: method to get the dr server backups
        * new-drserverrecovery: method to start a new dr server recovery
        * set-activity: method to cancel a queued or running activity
    * Tasks
        * Task-01: example query for virtual machine assets
        * Task-02: example query for filesystem assets
        * Task-03: example query for mssql assets
        * Task-04: example query for protection job activities for the last x days
        * Task-05: example to showcase querying 3rd party IAM solution and subsequently setting that password for the defined ddboost user
        * Task-06: example query for unacknowledged alerts
        * Task-07: example query for system jobs
        * Task-08: example of moving all assets from a source to a target protection policy
        * Task-09: example of updating SQL host credentials from a csv, or hash table
        * Task-10: example of DR recovery of the PowerProtect Data Manager server
        * Task-11: example of enabling, or disabling a protection policy
        * Task-12: example of canceling all activities in a queued, or running state with a start time in the last 24 hours

* dell.utilities.psm1
    * PowerShell7 module that covers a basic IAM request
    * Functions
        * get-iamsecret: method to get a password, for a ddboost user, based on the default complexity requirements of PowerProtect Data Manager to show case password management from a 3rd party IAM solution such as CyberArk
    * Tasks
        * Task-05: Same as above
