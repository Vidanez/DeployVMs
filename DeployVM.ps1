<#
.SYNOPSIS
Deploy Multiple VMs to vCenter

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
#>

#requires -Version 3

#--------------------------------------------------------------------
# Parameters
param (
    [parameter(Mandatory=$false)]
    [string]$csvfile,
    [parameter(Mandatory=$false)]
    [string]$vcenter,
    [parameter(Mandatory=$false)]
    [switch]$auto,
    [parameter(Mandatory=$false)]
    [switch]$createcsv
    )

#--------------------------------------------------------------------
# User Defined Variables

#--------------------------------------------------------------------
# Static Variables

$scriptName = "DeployVM"
$scriptVer = "1.6"
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$starttime = Get-Date -uformat "%m-%d-%Y %I:%M:%S"
$logDir = $scriptDir + "\Logs\"
$logfile = $logDir + $scriptName + "_" + (Get-Date -uformat %m-%d-%Y_%I-%M-%S) + "_" + $env:username + ".txt"
$deployedDir = $scriptDir + "\Deployed\"
$deployedFile = $deployedDir + "DeployVM_" + (Get-Date -uformat %m-%d-%Y_%I-%M-%S) + "_" + $env:username  + ".csv"
$exportpath = $scriptDir + "\DeployVM.csv"
$headers = "" | Select-Object NameVM, Name, Boot, OSType, Template, Folder, ResourcePool, CPU, RAM, Disk2, Disk3, Disk4, SDRS, Datastore, DiskStorageFormat, NetType, Network, DHCP, IPAddress, SubnetMask, Gateway, pDNS, sDNS, Notes, Domain, OU
$taskTab = @{}
$credentials = @{}
$localAdminPassword = ""

#--------------------------------------------------------------------
# Load Snap-ins

# Add VMware snap-in if required
If ((Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) -eq $null) {add-pssnapin VMware.VimAutomation.Core} {add-pssnapin ActiveDirectory}

#--------------------------------------------------------------------
# Functions

Function Out-Log {
    Param(
        [Parameter(Mandatory=$true)][string]$LineValue,
        [Parameter(Mandatory=$false)][string]$fcolor = "White"
    )

    Add-Content -Path $logfile -Value $LineValue
    Write-Host $LineValue -ForegroundColor $fcolor
}

Function Read-OpenFileDialog([string]$WindowTitle, [string]$InitialDirectory, [string]$Filter = "All files (*.*)|*.*", [switch]$AllowMultiSelect)
{
    Add-Type -AssemblyName System.Windows.Forms
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Title = $WindowTitle
    if (![string]::IsNullOrWhiteSpace($InitialDirectory)) { $openFileDialog.InitialDirectory = $InitialDirectory }
    $openFileDialog.Filter = $Filter
    if ($AllowMultiSelect) { $openFileDialog.MultiSelect = $true }
    $openFileDialog.ShowHelp = $true    # Without this line the ShowDialog() function may hang depending on system configuration and running from console vs. ISE.
    $openFileDialog.ShowDialog() > $null
    if ($AllowMultiSelect) { return $openFileDialog.Filenames } else { return $openFileDialog.Filename }
}


#--------------------------------------------------------------------
# Main Procedures

# Start Logging
Clear-Host
If (!(Test-Path $logDir)) {New-Item -ItemType directory -Path $logDir | Out-Null}
Out-Log "**************************************************************************************"
Out-Log "$scriptName`tVer:$scriptVer`t`t`t`tStart Time:`t$starttime"
Out-Log "**************************************************************************************`n"

# If requested, create DeployVM.csv and exit
If ($createcsv) {
    If (Test-Path $exportpath) {
        Out-Log "`n$exportpath Already Exists!`n" "Red"
        Exit
    } Else {
        Out-Log "`nCreating $exportpath`n" "Yellow"
        $headers | Export-Csv $exportpath -NoTypeInformation
		Out-Log "Done!`n"
        Exit
    }
}

# Ensure PowerCLI is at least version 5.5 R2 (Build 1649237)
If ((Get-PowerCLIVersion).Build -lt 1649237) {
    Out-Log "Error: DeployVM script requires PowerCLI version 5.5 R2 (Build 1649237) or later" "Red"
	Out-Log "PowerCLI Version Detected: $((Get-PowerCLIVersion).UserFriendlyVersion)" "Red"
    Out-Log "Exiting...`n`n" "Red"
    Exit
}

# Test to ensure csv file is available
If ($csvfile -eq "" -or !(Test-Path $csvfile) -or !$csvfile.EndsWith("DeployVM.csv")) {
    Out-Log "Path to DeployVM.csv not specified...prompting`n" "Yellow"
    $csvfile = Read-OpenFileDialog "Locate DeployVM.csv" "C:\" "DeployVM.csv|DeployVM.csv"
}

If ($csvfile -eq "" -or !(Test-Path $csvfile) -or !$csvfile.EndsWith("DeployVM.csv")) {
    Out-Log "`nStill can't find it...I give up" "Red"
    Out-Log "Exiting..." "Red"
    Exit
}

Out-Log "Using $csvfile`n" "Yellow"
# Make copy of DeployVM.csv
If (!(Test-Path $deployedDir)) {New-Item -ItemType directory -Path $deployedDir | Out-Null}
Copy-Item $csvfile -Destination $deployedFile | Out-Null

# Import VMs from csv
$newVMs = Import-Csv $csvfile
$newVMs = $newVMs | Where {$_.Name -ne ""}
[INT]$totalVMs = @($newVMs).count
Out-Log "New VMs to create: $totalVMs" "Yellow"

# Check to ensure csv is populated
If ($totalVMs -lt 1) {
    Out-Log "`nError: No enough entries found in DeployVM.csv" "Red"
    Out-Log "Exiting...`n" "Red"
    Exit
}

# Show input and ask for confirmation, unless -auto was used
If (!$auto) {
    $newVMs | Out-GridView -Title "VMs to be Created"
    $continue = Read-Host "`nContinue (y/n)?"
    If ($continue -notmatch "y") {
        Out-Log "Exiting..." "Red"
        Exit
    }
}


# Reading VMs to deploy and if they are windows asking to load credentials per Domain
Foreach ($VM in $newVMs) {
    $Error.Clear()
    $credentialDomain =  $VM.Domain

    If ($VM.OSType -eq "Windows") {
        If ( !$credentials.ContainsKey($credentialDomain)) {
              $new_cred = Get-Credential -Message "Admin credentials for domain - $credentialDomain use format DOMAIN\USERNAME"
              $credentials.Add($VM.domain,$new_cred)
              $localAdminPassword = Read-Host "`r`n`r`nEnter a password for the Windows local 'Administrator' account:"
        }
    }
 }



# Connect to vCenter server
If ($vcenter -eq "") {$vcenter = Read-Host "`nEnter vCenter server FQDN or IP"}

    $credential = $credentials.Get_Item("ph.esl-asia.com")
    
    Try {
        Out-Log "`nConnecting to vCenter - $vcenter`n`n" "Yellow"
        Connect-VIServer $vcenter -EA Stop -Credential $credential | Out-Null
    } Catch {
        Out-Log "`r`n`r`nUnable to connect to $vcenter" "Red"
        Out-Log "Exiting...`r`n`r`n" "Red"
        Exit
}

# Start provisioning VMs
$v = 0
Out-Log "Deploying VMs`n" "Yellow"
Foreach ($VM in $newVMs) {
    $Error.Clear()
	$vmName = $VM.Name
    $v++
	$vmStatus = "[{0} of {1}] {2}" -f $v, $newVMs.count, $vmName
	Write-Progress -Activity "Deploying VMs" -Status $vmStatus -PercentComplete (100*$v/($newVMs.count + 1))
    # Create custom OS Custumization spec
   If ($vm.DHCP -match "TRUE") {
        If ($VM.OSType -eq "Windows") {
            $credential = $credentials.Get_Item($VM.domain)
            $fullname = "ESL-ASIA"
            $orgname = "ESL-ASIA"
            $tempSpec = New-OSCustomizationSpec -Name temp$vmName -NamingScheme fixed `
            -NamingPrefix $VM.Name -Domain $VM.domain  -FullName $fullname -OrgName $orgname `
            -DomainCredentials $credential -TimeZone 085 -ChangeSid -OSType Windows -AdminPassword $localAdminPassword
	        $tempSpec | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping `
	        -IpMode UseDhcp | Out-Null
            If ( !$VM.OU -eq "") {
                New-ADComputer -Name $VM.Name-Path  $VM.OU -credential $credential -server $VM.pDNS
            }
	    } ElseIF ($VM.OSType -eq "Linux") {
            $tempSpec = New-OSCustomizationSpec -Name temp$vmName -NamingScheme fixed `
            -NamingPrefix $VM.Name -Domain $VM.domain -OSType Linux -DnsServer $VM.pDNS,$VM.sDNS
            $tempSpec | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping `
            -IpMode UseDhcp | Out-Null
            If ( !$VM.OU -eq "") {
                New-ADComputer -Name $VM.Name-Path  $VM.OU -credential $credential -server $VM.pDNS
            }
          }
	} Else {
		If ($VM.OSType -eq "Windows") {
            $credential = $credentials.Get_Item($VM.domain)
            $fullname = "ESL-ASIA"
            $orgname = "ESL-ASIA"
            $tempSpec = New-OSCustomizationSpec -Name temp$vmName -NamingScheme fixed `
            -NamingPrefix $VM.Name -Domain $VM.domain -FullName $fullname -OrgName $orgname `
            -DomainCredentials $credential -TimeZone 085 -ChangeSid -OSType Windows -AdminPassword $localAdminPassword
            $tempSpec | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping `
	        -IpMode UseStaticIP -IpAddress $VM.IPAddress -SubnetMask $VM.SubnetMask `
	        -Dns $VM.pDNS,$VM.sDNS -DefaultGateway $VM.Gateway | Out-Null
            If ( !$VM.OU -eq "") {
                New-ADComputer -Name $VM.Name-Path  $VM.OU -credential $credential -server $VM.pDNS
            }
        } ElseIF ($VM.OSType -eq "Linux") {
            $tempSpec = New-OSCustomizationSpec -Name temp$vmName -NamingScheme fixed `
            -NamingPrefix $VM.Name -Domain $VM.domain -OSType Linux -DnsServer $VM.pDNS,$VM.sDNS
            $tempSpec | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping `
            -IpMode UseStaticIP -IpAddress $VM.IPAddress -SubnetMask $VM.SubnetMask -DefaultGateway $VM.Gateway | Out-Null
            If ( !$VM.OU -eq "") {
                New-ADComputer -Name $VM.Name-Path  $VM.OU -credential $credential -server $VM.pDNS
            }
          }
	}

    # Create VM depeding on the parameter SDRS true or false
    Out-Log "Deploying $vmName"
    If ($VM.SDRS -match "TRUE") {
        Out-Log "SDRS Cluster disk on $vmName - removing DiskStorageFormat parameter " "Yellow"
        $taskTab[(New-VM -Name $VM.NameVM -ResourcePool $VM.ResourcePool -Location $VM.Folder -Datastore $VM.Datastore `
    -Notes $VM.Notes -Template $VM.Template -OSCustomizationSpec temp$vmName -RunAsync -EA SilentlyContinue).Id] = $VM.Name
      } Else {
       Out-Log "NON SDRS Cluster disk on $vmName - using DiskStorageFormat parameter " "Yellow"
        $taskTab[(New-VM -Name $VM.NameVM -ResourcePool $VM.ResourcePool -Location $VM.Folder -Datastore $VM.Datastore `
        -DiskStorageFormat $VM.DiskStorageFormat -Notes $VM.Notes -Template $VM.Template -OSCustomizationSpec temp$vmName -RunAsync -EA SilentlyContinue).Id] = $VM.Name
    }
    # Remove temp OS Custumization spec
    Remove-OSCustomizationSpec -OSCustomizationSpec temp$vmName -Confirm:$false
    # Log errors
    If ($Error.Count -ne 0) {
        If ($Error.Count -eq 1 -and $Error.Exception -match "'Location' expects a single value") {
            $vmLocation = $VM.Folder
            Out-Log "Unable to place $vmName in desired location, multiple $vmLocation folders exist, check root folder" "Red"
        } Else {
            Out-Log "`n$vmName failed to deploy!" "Red"
            Foreach ($err in $Error) {
                Out-Log "$err" "Red"
            }
            $failDeploy += @($vmName)
        }
    }
}

Out-Log "`n`nAll Deployment Tasks Created" "Yellow"
Out-Log "`n`nMonitoring Task Processing" "Yellow"

# When finsihed deploying, reconfigure new VMs
$totalTasks = $taskTab.Count
$runningTasks = $totalTasks
while($runningTasks -gt 0){
    $vmStatus = "[{0} of {1}] {2}" -f $runningTasks, $totalTasks, "Tasks Remaining"
	Write-Progress -Activity "Monitoring Task Processing" -Status $vmStatus -PercentComplete (100*($totalTasks-$runningTasks)/$totalTasks)
	Get-Task | % {
    if($taskTab.ContainsKey($_.Id) -and $_.State -eq "Success"){
      #Deployment completed
      $Error.Clear()
      $vmName = $taskTab[$_.Id]
      Out-Log "`n`nReconfiguring $vmName" "Yellow"
      $VM = Get-VM $vmName
      $VMconfig = $newVMs | Where {$_.Name -eq $vmName}

	  # Set CPU and RAM
      Out-Log "Setting vCPU(s) and RAM on $vmName" "Yellow"
      $VM | Set-VM -NumCpu $VMconfig.CPU -MemoryGB $VMconfig.RAM -Confirm:$false | Out-Null

	  # Set port group on virtual adapter
      Out-Log "Setting Port Group on $vmName" "Yellow"
      If ($VMconfig.NetType -match "vSS") {
		  $network = @{
			  'NetworkName' = $VMconfig.network
			  'Confirm' = $false
		  }
	  } Else {
		  $network = @{
			  'Portgroup' = $VMconfig.network
			  'Confirm' = $false
		  }
	  }
	  $VM | Get-NetworkAdapter | Set-NetworkAdapter @network | Out-Null

	  # Add additional disks if needed
      If ($VMConfig.Disk2 -gt 1) {
        Out-Log "Adding additional disk on $vmName - don't forget to format within the OS" "Yellow"
        $VM | New-HardDisk -CapacityGB $VMConfig.Disk2 -StorageFormat $VMConfig.DiskStorageFormat -Persistence persistent | Out-Null
      }
      If ($VMConfig.Disk3 -gt 1) {
        Out-Log "Adding additional disk on $vmName - don't forget to format within the OS" "Yellow"
        $VM | New-HardDisk -CapacityGB $VMConfig.Disk3 -StorageFormat $VMConfig.DiskStorageFormat -Persistence persistent | Out-Null
      }
      If ($VMConfig.Disk4 -gt 1) {
        Out-Log "Adding additional disk on $vmName - don't forget to format within the OS" "Yellow"
        $VM | New-HardDisk -CapacityGB $VMConfig.Disk4 -StorageFormat $VMConfig.DiskStorageFormat -Persistence persistent | Out-Null
      }


	  # Boot VM
	  If ($VMconfig.Boot -match "true") {
      	Out-Log "Booting $vmName" "Yellow"
      	$VM | Start-VM -EA SilentlyContinue | Out-Null
	  }
      $taskTab.Remove($_.Id)
      $runningTasks--
      If ($Error.Count -ne 0) {
        Out-Log "$vmName completed with errors" "Red"
        Foreach ($err in $Error) {
            Out-Log "$Err" "Red"
        }
        $failReconfig += @($vmName)
      } Else {
        Out-Log "$vmName is Complete" "Green"
        $successVMs += @($vmName)
      }
    }
    elseif($taskTab.ContainsKey($_.Id) -and $_.State -eq "Error"){
      # Deployment failed
      $failed = $taskTab[$_.Id]
      Out-Log "`n$failed failed to deploy!`n" "Red"
      $taskTab.Remove($_.Id)
      $runningTasks--
      $failDeploy += @($failed)
    }
  }
  Start-Sleep -Seconds 10
}

#--------------------------------------------------------------------
# Close Connections

Disconnect-VIServer -Server $vcenter -Force -Confirm:$false

#--------------------------------------------------------------------
# Outputs

Out-Log "`n**************************************************************************************"
Out-Log "Processing Complete" "Yellow"

If ($successVMs -ne $null) {
    Out-Log "`nThe following VMs were successfully created:" "Yellow"
    Foreach ($success in $successVMs) {Out-Log "$success" "Green"}
}
If ($failReconfig -ne $null) {
    Out-Log "`nThe following VMs failed to reconfigure properly:" "Yellow"
    Foreach ($reconfig in $failReconfig) {Out-Log "$reconfig" "Red"}
}
If ($failDeploy -ne $null) {
    Out-Log "`nThe following VMs failed to deploy:" "Yellow"
    Foreach ($deploy in $failDeploy) {Out-Log "$deploy" "Red"}
}

$finishtime = Get-Date -uformat "%m-%d-%Y %I:%M:%S"
Out-Log "`n`n"
Out-Log "**************************************************************************************"
Out-Log "$scriptName`t`t`t`t`tFinish Time:`t$finishtime"
Out-Log "**************************************************************************************"
