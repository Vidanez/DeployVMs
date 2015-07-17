<#'-----------------------------------------------------------------------------
'Script Name : redeploy.ps1
'Author      : Matthew Beattie
'Email       : mbeattie@netapp.com
'Created     : 17/12/13
'Description : This script invokes the "redeployVMs" method of the VSC API.
'            : It redeploys all virtual machines provisioned from a specifed
'            : template to the source templates origional disk state. This
'            : has the potential for data loss in all virtual machines
'            : deployed from the template. Use at your own risk.
'            :
'Disclaimer  : (c) 2013 NetApp Inc., All Rights Reserved
'            :
'            : NetApp disclaims all warranties, excepting NetApp shall provide
'            : support of unmodified software pursuant to a valid, separate,
'            : purchased support agreement. No distribution or modification of
'            : this software is permitted by NetApp, except under separate
'            : written agreement, which may be withheld at NetApp's sole
'            : discretion.
'            :
'            : THIS SOFTWARE IS PROVIDED BY NETAPP "AS IS" AND ANY EXPRESS OR
'            : IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
'            : WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
'            : PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL NETAPP BE LIABLE FOR ANY
'            : DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
'            : DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
'            : GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
'            : INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
'            : WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
'            : NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
'            : THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
'-----------------------------------------------------------------------------#>
[String]$vscIPAddress      = "<IP Address>"
[String]$vscHostName       = "<VSC Host>"
[Int]$portNumber           = 8143
[String]$username          = "<Domain>\<Username>"
[String]$vmServiceCredFile = "<Path to text file containing encrypted password for above user>"
[String]$templateName      = "<Template VM Name>"
[String]$dataCenterName    = "<Datacenter Name>"
[String]$vFilerHostName    = "<NetApp HostNAme>"
[String]$vFilerIPAddress   = "<NetApp Host IP>"
[String]$customizationName = "<Name of customization file to use>"
#'------------------------------------------------------------------------------
#'Prompt for VSC credentials.
#'------------------------------------------------------------------------------
[String]$username = "<Domain>\<Username>"
$vmServiceCreds = get-content $vmServiceCredFile | convertto-securestring
[System.Management.Automation.PSCredential]$vscCredentials = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $vmServiceCreds
#'------------------------------------------------------------------------------
#'Connect to the VSC using the web service API.
#'------------------------------------------------------------------------------
[System.Net.ServicePointManager]:Smiley FrustratederverCertificateValidationCallback = {$True}
[String]$uri = "https://$vscIPAddress`:$portNumber/kamino/public/api?wsdl"
Try{
   [System.Web.Services.Protocols.SoapHttpClientProtocol]$connection = New-WebServiceProxy -uri $uri -Credential $vscCredentials -ErrorAction Stop
   Write-Host "Connected to VSC on IPAddress ""$vscipAddress"" on Port ""$portNumber"""
}Catch{
   Write-Host ("Error """ + $Error[0] + """ Connecting to ""$uri""")
   Break;
}
#'------------------------------------------------------------------------------
#'Create a namespace object from the connection object
#'------------------------------------------------------------------------------
[System.Object]$namespace = $connection.GetType().Namespace
#'------------------------------------------------------------------------------
#'Create a requestspec Object from the NameSpace object
#'------------------------------------------------------------------------------
[System.Object]$requestSpecType = ($namespace + '.requestSpec')
[System.Object]$requestSpec     = New-Object ($requestSpecType)
#'------------------------------------------------------------------------------
#'Convert Encrypted Password to Plain Text and Assign to Variable - ss
#'------------------------------------------------------------------------------
$EncrpytedPassword = get-content $vmServiceCredFile | convertto-securestring
   # Get the plain text version of the password
    $password = [Runtime.InteropServices.Marshal]:Smiley TonguetrToStringAuto([Runtime.InteropServices.Marshal]:Smiley FrustratedecureStringToBSTR($EncrpytedPassword))
#'------------------------------------------------------------------------------
#'Enumerate the username and password from the credential object.
#'------------------------------------------------------------------------------
[String]$domain    = "<Domain>"
[String]$user      = "<Username>"
[String]$username  = "$domain\$user"
#'------------------------------------------------------------------------------
#'Set the properties of the RequestSpec object.
#'------------------------------------------------------------------------------
$requestSpec.serviceUrl = "https://" + $vscHostName + "/sdk"
$requestSpec.vcUser     = $username
$requestSpec.vcPassword = $password
#'------------------------------------------------------------------------------
#'Enumerate the Managed Object Reference of the VMWare Template.
#'------------------------------------------------------------------------------
[System.Object]$templateMoref = $connection.getMoref($templateName, "VirtualMachine", $requestSpec)
# Write-Host "Enumerated Managed Object Reference for ""$templateName"" as ""$templateMoref"""
#'------------------------------------------------------------------------------
#'Enumerate the Managed Object Reference of the VMWare Datacenter.
#'------------------------------------------------------------------------------
[System.Object]$dataCenterMoref = $connection.getMoref($dataCenterName, "Datacenter", $requestSpec)
# Write-Host "Enumerated Managed Object Reference for ""$dataCenterName"" as ""$dataCenterMoref"""
#'------------------------------------------------------------------------------
#'Enumerate the Managed Object Reference of the Datastore.
#'------------------------------------------------------------------------------
[System.Object]$dataStoreMoref = $connection.getMoref($dataStoreName, "Datastore", $requestSpec)
# Write-Host "Enumerated Managed Object Reference for ""$dataStoreName"" as ""$dataStoreMoref"""
#'------------------------------------------------------------------------------
#'Enumerate the VMWare template files.
#'------------------------------------------------------------------------------
# Write-Host "Enumerating files for Virtual Machine Template ""$templateMoref"""
Try{
   $files = $connection.getVMFiles($templateMoref, $requestSpec)
}Catch{
  # Write-Host ("Error """ + $Error[0] + """ Enumerating Virtual Machine Files for ""$templateMoref""")
   Break;
}
#'------------------------------------------------------------------------------
#'Enumerate the VMWare template files.
#'------------------------------------------------------------------------------
Write-Host "Enumerating Virtual Machines deployed from Template ""$templateMoref"""
Try{
   $virtualMachines = $connection.getVMs($templateMoref, $requestSpec)
}Catch{
  # Write-Host ("Error """ + $Error[0] + """ Enumerating Virtual Machines ""$templateMoref""")
   Break;
}
#'------------------------------------------------------------------------------
#'
#'------------------------------------------------------------------------------
[Array]$vms = @()
ForEach($virtualMachine In $virtualMachines){
   [Array]$vms += $virtualMachine.vmMoref
   Write-Host $virtualMachine.vmMoref
}
#'---------------------------------------------------------------------------
#'Create a controllerSpec Object from the NameSpace object and set properties.
#'---------------------------------------------------------------------------
[System.Object]$controllerType                    = ($namespace + '.controllerspec')
[System.Object]$controllerSpec                    = New-Object ($controllerType)
[System.Object]$controllerSpec.username           = $username
[System.Object]$controllerSpec.password           = $password
#'------------------------------------------------------------------------------
#'Set controller IP address (Ensure DNS A & PTR records exist)
#'------------------------------------------------------------------------------
[System.Object]$controllerSpec.ipAddress          = $vFilerIPAddress
[System.Object]$controllerSpec.passthroughContext = $vFilerHostName
[System.Object]$controllerSpec.ssl                = $True
#'------------------------------------------------------------------------------
#'Set the destination controller and datastore for each file.
#'------------------------------------------------------------------------------
ForEach($file In $files){
   $file.destDatastoreSpec.controller = $controllerSpec;
}
#'------------------------------------------------------------------------------
#'Create a "cloneSpec" object from the NameSpace object and set properties.
#'------------------------------------------------------------------------------
[System.Object]$cloneSpecType            = ($namespace + '.clonespec')
[System.Object]$cloneSpec                = New-Object ($cloneSpecType)
[System.Object]$cloneSpec.templateMoref  = $templateMoref
[System.Object]$cloneSpec.containerMoref = $dataCenterMoref
#'------------------------------------------------------------------------------
#'Create objects for each clone and set their properties.
#'------------------------------------------------------------------------------
[Array]$clones = @()
For($i = 0; $i -le ($vms.Count -1); $i++){
   #'---------------------------------------------------------------------------
   #'Create a vmSpec Object from the NameSpace object and set properties.
   #'---------------------------------------------------------------------------
   [System.Object]$vmSpecType         = ($namespace + '.vmSpec')
   [System.Object]$vmSpec             = New-Object ($vmSpecType)
   #'---------------------------------------------------------------------------
   #'Create a cloneSpecEntry Object from the NameSpace object and set properties.
   #'---------------------------------------------------------------------------
   [System.Object]$cloneSpecEntryType = ($namespace + '.cloneSpecEntry')
   [System.Object]$cloneSpecEntry     = New-Object ($cloneSpecEntryType)
   #'---------------------------------------------------------------------------
   #'Create a guestCustomizationSpecType Object from the NameSpace object and set properties.
   #'---------------------------------------------------------------------------
   [System.Object]$guestCustomizationSpecType  = ($namespace + '.guestCustomizationSpec')
   [System.Object]$guestCustomizationSpec      = New-Object ($guestCustomizationSpecType)
   [System.Object]$guestCustomizationSpec.Name = $customizationName
   [System.Object]$vmSpec.powerOn              = $powerOn
   [System.Object]$vmSpec.custSpec             = $guestCustomizationSpec
   [System.Object]$vmSpec.vmMoref              = $vms[$i]
   [System.Object]$cloneSpecEntry.key          = $vms[$i]
   [System.Object]$cloneSpecEntry.Value        = $vmSpec
   [Array]$clones                             += $cloneSpecEntry
   #'---------------------------------------------------------------------------
   #'Set the destination controller and datastore for the files.
   #'---------------------------------------------------------------------------
   ForEach($file In $files){
      $file.destDatastoreSpec.controller = $controllerSpec;
      $file.destDatastoreSpec.mor        = $dataStoreMoref;
   }
}
#'------------------------------------------------------------------------------
#'Set the properties of the cloneSpec Object.
#'------------------------------------------------------------------------------
[System.Object]$cloneSpec.files       = $files
[System.Object]$cloneSpec.clones      = $clones
[System.Object]$requestSpec.cloneSpec = $cloneSpec
#'------------------------------------------------------------------------------
#'Initiate the Rapid clone task for the Even Numbered Clones.
#'------------------------------------------------------------------------------
Try{
   [String]$taskId = $connection.redeployVMs($requestSpec, $controllerSpec)
   [String]$taskId = $taskId.SubString($taskId.LastIndexOf(" ") + 1)
  # Write-Host "Initiated VSC Redeploy. VCenter TaskID ""$taskId"""
}Catch{
   Write-Host "Failed Initiating VSC Redeploy"
   Break;
}
#'------------------------------------------------------------------------------
ApplyCustomization Script
[String]$vscIPAddress      = "<VSC IP Address>"
[String]$vscHostName       = "<VSC Hostname>"
[Int]$portNumber           = 8143
[String]$username          = "<Domain>\<username>"
[String]$vmServiceCredFile = "<Path and filename to text file containing encrypted password for above user>"
[String]$templateName      = "<Template VM Name>"
[String]$dataCenterName    = "<Datacentr Name>"
[String]$vFilerHostName    = "<NetApp Hostname>"
[String]$vFilerIPAddress   = "<NetApp IP Address>"
[String]$customizationName = "<Guest Customization to use>"
[String]$vCenterName       = "<FQDN of vCenter Server>"
[String]$protocol          = "https"
[String]$snapInName        = "VMware.VimAutomation.Core"
#'------------------------------------------------------------------------------
#'Provide VSC credentials from an encrypted string in text file.
#'------------------------------------------------------------------------------
[String]$username = "<domain>\<username>"
$vmServiceCreds = get-content $vmServiceCredFile | convertto-securestring
[System.Management.Automation.PSCredential]$vscCredentials = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $vmServiceCreds
#'------------------------------------------------------------------------------
#'Connect to the VSC using the web service API.
#'------------------------------------------------------------------------------
[System.Net.ServicePointManager]:Smiley FrustratederverCertificateValidationCallback = {$True}
[String]$uri = "https://$vscIPAddress`:$portNumber/kamino/public/api?wsdl"
Try{
   [System.Web.Services.Protocols.SoapHttpClientProtocol]$connection = New-WebServiceProxy -uri $uri -Credential $vscCredentials -ErrorAction Stop
   Write-Host "Connected to VSC on IPAddress ""$vscipAddress"" on Port ""$portNumber"""
}Catch{
   Write-Host ("Error """ + $Error[0] + """ Connecting to ""$uri""")
   Break;
}
#'------------------------------------------------------------------------------
#'Create a namespace object from the connection object
#'------------------------------------------------------------------------------
[System.Object]$namespace = $connection.GetType().Namespace
#'------------------------------------------------------------------------------
#'Create a requestspec Object from the NameSpace object
#'------------------------------------------------------------------------------
[System.Object]$requestSpecType = ($namespace + '.requestSpec')
[System.Object]$requestSpec     = New-Object ($requestSpecType)
#'------------------------------------------------------------------------------
#'Convert Encrypted Password to Plain Text and Assign to Variable
#'------------------------------------------------------------------------------
$EncrpytedPassword = get-content $vmServiceCredFile | convertto-securestring
    # Get the plain text version of the password
    $password = [Runtime.InteropServices.Marshal]:Smiley TonguetrToStringAuto([Runtime.InteropServices.Marshal]:Smiley FrustratedecureStringToBSTR($EncrpytedPassword))
#'------------------------------------------------------------------------------
#'Enumerate the username and password from the credential object.
#'------------------------------------------------------------------------------
[String]$domain    = "<Domain>"
[String]$user      = "<Username>"
[String]$username  = "$domain\$user"
#'------------------------------------------------------------------------------
#'Set the properties of the RequestSpec object.
#'------------------------------------------------------------------------------
$requestSpec.serviceUrl = "https://" + $vscHostName + "/sdk"
$requestSpec.vcUser     = $username
$requestSpec.vcPassword = $password
#'------------------------------------------------------------------------------
#'Enumerate the Managed Object Reference of the VMWare Template.
#'------------------------------------------------------------------------------
[System.Object]$templateMoref = $connection.getMoref($templateName, "VirtualMachine", $requestSpec)
# Write-Host "Enumerated Managed Object Reference for ""$templateName"" as ""$templateMoref"""
#'------------------------------------------------------------------------------
#'Enumerate the Managed Object Reference of the VMWare Datacenter.
#'------------------------------------------------------------------------------
[System.Object]$dataCenterMoref = $connection.getMoref($dataCenterName, "Datacenter", $requestSpec)
# Write-Host "Enumerated Managed Object Reference for ""$dataCenterName"" as ""$dataCenterMoref"""
#'------------------------------------------------------------------------------
#'Enumerate the Managed Object Reference of the Datastore.
#'------------------------------------------------------------------------------
[System.Object]$dataStoreMoref = $connection.getMoref($dataStoreName, "Datastore", $requestSpec)
# Write-Host "Enumerated Managed Object Reference for ""$dataStoreName"" as ""$dataStoreMoref"""
#'------------------------------------------------------------------------------
#'Enumerate the VMWare template files.
#'------------------------------------------------------------------------------
# Write-Host "Enumerating files for Virtual Machine Template ""$templateMoref"""
Try{
   $files = $connection.getVMFiles($templateMoref, $requestSpec)
}Catch{
  # Write-Host ("Error """ + $Error[0] + """ Enumerating Virtual Machine Files for ""$templateMoref""")
   Break;
}
#'------------------------------------------------------------------------------
#'Enumerate the VMWare template files.
#'------------------------------------------------------------------------------
Write-Host "Enumerating Virtual Machines deployed from Template ""$templateMoref"""
Try{
   $virtualMachines = $connection.getVMs($templateMoref, $requestSpec)
}Catch{
  # Write-Host ("Error """ + $Error[0] + """ Enumerating Virtual Machines ""$templateMoref""")
   Break;
}
[Array]$vms = @()
ForEach($virtualMachine In $virtualMachines){
   [Array]$vms += $virtualMachine.vmMoref
   # Write-Host $virtualMachine.vmMoref
   }
# ***********************************************************
# ********  Apply Customization to Redeployed VMs     ********
# ***********************************************************
#'Get credentials for vCenter Login.
#'------------------------------------------------------------------------------
$vmServiceCreds = get-content $vmServiceCredFile | convertto-securestring
[System.Management.Automation.PSCredential]$credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $vmServiceCreds
#'------------------------------------------------------------------------------
#'Ensure the VMware PowerShell SnapIn is added.
#'------------------------------------------------------------------------------
Try{
   Add-PSSnapin -Name $snapInName -ErrorAction SilentlyContinue
}Catch{
   Write-Host "The SnapIn ""$snapInName"" is added"
}
#'------------------------------------------------------------------------------
#'Connect to Virtual Center.
#'------------------------------------------------------------------------------
       #'---------------------------------------------------------------------------
       #'Bypass SSL certificate confirmation
       #'---------------------------------------------------------------------------
       [System.Net.ServicePointManager]:Smiley FrustratederverCertificateValidationCallback = {$True}
Try{
   Connect-VIServer -Server $vCenterName -Protocol $protocol -Credential $credentials -Force -ErrorAction Stop | Out-Null
   Write-Host "Connected to Virtual Center ""$vCenterName"""
}Catch{
   Write-Host "Error Connecting to ""$vCenterName"""
   Break;
}
#'------------------------------------------------------------------------------
#'Get the VMWare Guest Customization.
#'------------------------------------------------------------------------------
Try{
   $customSpec = Get-OSCustomizationSpec -Name $customizationName -ErrorAction Stop
   Write-Host "Enumerated Guest Customization ""$customizationName"""
}Catch{
   Write-Host "Failed Enumerating Guest Customization ""$customizationName"""
   Break;
}
#'------------------------------------------------------------------------------
#'Set the template for each VM (replace ":" with "-"). VSC and vSphere return different ID formats.
#'------------------------------------------------------------------------------
ForEach($vm In $vms){
   $vmId = $vm -Replace(":", "-")
   Do{
      #'------------------------------------------------------------------------
      #'Connect to the Virtual Machine by ID.
      #'------------------------------------------------------------------------
      Try{
         $virtualMachine = Get-VM -Id $vmId -ErrorAction Stop
         Write-Host "Connect to Virtual Machine ""$virtualMachine"""
      }Catch{
         Write-Host "Failed Connecting to Virtual Machine ""$vmId"""
         Break;
      }
      #'------------------------------------------------------------------------
      #'Set the guest customization for the virtual machine.
      #'------------------------------------------------------------------------
      Try{
         Set-VM -VM $virtualMachine -OSCustomizationSpec $customSpec -Confirm:$False -ErrorAction Stop
         Write-Host "Applied Guest Customization ""$customizationName"" to ""$virtualMachine"""
         Get-VM $virtualMachine | Start-VM
         Write-Host "Power on Virtual Machine: ""$virtualMachine"""
      }Catch{
         Write-Host "Failed Applying Guest Customization ""$customizationName"" to ""$virtualMachine"""
         Break;
      }
   }Until($True)
}
Write-Host "Done"
#'------------------------------------------------------------------------------
