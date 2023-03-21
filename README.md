# PowerProtectDataManager
Dell PowerProtect Data Manager Backup Software
https://developer.dell.com/apis/4378/versions/19.12.0/docs/introduction.md

PowerShell7

Modules: 
- dell.ppdm.psm1 (API version 19.12)
    - PowerShell7 module that covers basic interaction with the PowerProtect Data Manager REST API
    - Functions
        - connect-ppdmapi: method to request a bearer token
        - disconnect-ppdmapi: method to destroy a bearer token
        - get-assets: method to query for assets based on filter
        - get-activities: method to query for activities based on filter
        - get-alerts: method to query for alerts based on filter
        - set-password: method of setting the ddboost user password, assigned to a protection policy, in PowerProtect Datamanager
        - get-policy: method to query for protection policies based on filter
        - set-policyassignment: method to batch assign, or unassign assets to a protection policy based on policy id, and assets id
    - Tasks
        - Task-01: example query for virtual machine assets
        - Task-02: example query for filesystem assets
        - Task-03: example query for mssql assets
        - Task-04: example query for protection job activities for the last x days
        - Task-05: example to showcase querying 3rd party IAM solution and subsequently setting that password for the defined ddboost user
        - Task-06: example query for unacknowledged alerts
        - Task-07: example query for system jobs
        - Task-08: example of moving all assets from a source to a target protection policy

- dell.utilities.psm1
    - PowerShell7 module that covers a basic IAM request
    - Functions
        - get-iamsecret: method to get a password, for a ddboost user, based on the default complexity requirements of PowerProtect Data Manager to show case password management from a 3rd party IAM solution such as CyberArc
    - Tasks
        - Task-05: Same as above
