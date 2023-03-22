# Deploy PowerProtect DM, PowerProtect DDVE, joined to together with vCenter
### MISC VARIABLES
ad_domain: vcorp.local <br/>
artifact_path: /var/lib/awx/projects/common <br/>

### POWERPROTECT DD VARIABLES
ddve_host: ddve-01 <br/>
ddve_acct: sysadmin <br/>
ddve_old_pwd: changeme <br/>
ddve_ip: 192.168.3.110 <br/>
ddve_netmask: 255.255.252.0 <br/>
ddve_gateway: 192.168.1.250 <br/>
ddve_dns1: 192.168.1.11 <br/>
ddve_dns2: 192.168.1.11 <br/>
ddve_ova: ddve-7.7.0.0-1003850.ova <br/>
ddve_disk_size: 500 <br/>
ddve_disk_type: thin <br/>

### POWERPROTECT DATA MANAGER VARIABLES
ppdm_host: ppdm-01 <br/>
ppdm_old_pwd: admin <br/>
ppdm_ip: 192.168.3.107 <br/>
ppdm_netmask: 255.255.252.0 <br/>
ppdm_gateway: 192.168.1.250 <br/>
ppdm_dns: 192.168.1.11 <br/>
ppdm_ntp: 192.168.1.11 <br/>
ppdm_timezone: "US/Central - Central Standard Time" <br/>
ppdm_ova: dellemc-ppdm-sw-19.11.0-14.ova <br/>

### VCENTER VARIABLES
vcenter_host: vc-01.vcorp.local <br/>
vcenter_esx: esx-physical-01.vcorp.local <br/>
vcenter_dc: DC01-VC01 <br/>
vcenter_ds: Unity-DS1 <br/>
vcenter_folder: "/{{vcenter_dc}}/vm/Deploy/" <br/>
vcenter_network: VM Network <br/>