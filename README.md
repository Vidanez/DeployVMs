DeployVMs
=========

Deploying multiple Linux VMs using PowerCli

.DESCRIPTION
VMs are deployed asynchronously based on a pre-configured csv file (DeployVM.csv)
Designed to run from Powershell ISE

.PARAMETER csvfile
Path to DeployVM.csv file with new VM info

.PARAMETER vCenter
vCenter Server FQDN or IP

.PARAMETER auto
Will allow script to run with no review or confirmation

.PARAMETER createcsv
Generates a blank csv file - DeployVM.csv

.EXAMPLE
.\DeployVM.ps1
Runs DeployVM

.EXAMPLE
.\DeployVM.ps1 -vcenter my.vcenter.address
Runs DeployVM specifying vCenter address

.EXAMPLE
.\DeployVM.ps1 -csvfile "E:\Scripts\Deploy\DeployVM.csv" -vcenter my.vcenter.address -auto
Runs DeployVM specifying path to csv file, vCenter address and no confirmation

.EXAMPLE
.\DeployVM.ps1 -createcsv
Creates a new/blank DeployVM.csv file in same directory as script

.NOTES
Author: Shawn Masterson
Created: May 2014
Version: 1.2

Author: JJ Vidanez
Created: Nov 2014
Version: 1.3
Add creation onthefly for customization Spec for linux systems
Ability to create machines names and guest hostname using different names
Added a value to find out the kind of disk because powercli bug for SDRS reported at https://communities.vmware.com/message/2442684#2442684
Remove the dependency for an already created OScustomization Spec

Author: JJ Vidanez
Created: Jul 2015
Version: 1.4
Adding domain credential request for Windows systems

Author : Simon Davies - Everything-Virtual.com
Created :  May 2016
Version: 1.5
Adding AD Computer Account Creation in specified OU's for VM's at start of deployment - Yes even Linux as that was a requirement
It's possible to restrict this to just Windows VM's by removing the comment at line #261

Author: JJ Vidanez & Robert Rowan
Created: Jun 2016
Version: 1.6
Fixed issue to deploy just one VM
Adding banner for each credential to show the domain where credentials are set
If OU parameter is defined at the OU create the object on AD where the machine is register Linux and Windows


REQUIREMENTS
PowerShell v3 or greater
vCenter (tested on 5.1/5.5)
PowerCLI 5.5 R2 or later
CSV File - VM info with the following headers
    NameVM, Name, Boot, OSType, Template, CustSpec, Folder, ResourcePool, CPU, RAM, Disk2, Disk3, Disk4, SDRS, Datastore, DiskStorageFormat, NetType, Network, DHCP, IPAddress, SubnetMask, Gateway, pDNS, sDNS, Notes, Domain, OU
    Must be named DeployVM.csv
    Can be created with -createcsv switch
CSV Field Definitions
    NameVM - Name of VM
	Name - Name of guest OS VM
	Boot - Determines whether or not to boot the VM - Must be 'true' or 'false'
	OSType - Must be 'Windows' or 'Linux'
	Template - Name of existing template to clone
	Folder - Folder in which to place VM in vCenter (optional)
	ResourcePool - VM placement - can be a reasource pool, host or a cluster
	CPU - Number of vCPU
	RAM - Amount of RAM in GB
	Disk2 - Size of additional disk to add (GB)(optional)
	Disk3 - Size of additional disk to add (GB)(optional)
	Disk4 - Size of additional disk to add (GB)(optional)
    SDRS - Mark to use a SDRS or not - Must be 'true' or 'false'
	Datastore - Datastore placement - Can be a datastore or datastore cluster
	DiskStorageFormat - Disk storage format - Must be 'Thin', 'Thick' or 'EagerZeroedThick' - Only funcional when SDRS = true
	NetType - vSwitch type - Must be 'vSS' or 'vDS'
	Network - Network/Port Group to connect NIC
	DHCP - Use DHCP - Must be 'true' or 'false'
	IPAddress - IP Address for NIC
	SubnetMask - Subnet Mask for NIC
	Gateway - Gateway for NIC
	pDNS - Primary DNS must be populated
	sDNS - Secondary NIC must be populated
	Notes - Description applied to the vCenter Notes field on VM
    Domain - DNS Domain must be populated
    OU - OU to create new computer accounts, must be the distinguished name eg "OU=TestOU1,OU=Servers,DC=my-homelab,DC=local"

CREDITS
Handling New-VM Async - LucD - @LucD22
http://www.lucd.info/2010/02/21/about-async-tasks-the-get-task-cmdlet-and-a-hash-table/
http://blog.smasterson.com/2014/05/21/deploying-multiple-vms-via-powercli-updated-v1-2/
http://blogs.vmware.com/PowerCLI/2014/05/working-customization-specifications-powercli-part-1.html
http://blogs.vmware.com/PowerCLI/2014/06/working-customization-specifications-powercli-part-2.html
http://blogs.vmware.com/PowerCLI/2014/06/working-customization-specifications-powercli-part-3.html

USE AT YOUR OWN RISK!

.LINK
http://blog.smasterson.com/2014/05/21/deploying-multiple-vms-via-powercli-updated-v1-2/
http://www.vidanez.com/2014/11/02/crear-multiples-linux-vms-de-un-fichero-csv-usando-powercli-deploying-multiple-linux-vms-using-powercli/
