#STORED CREDENTIAL CODE
$AdminName = Read-Host "Enter your Admin AD username"
$CredsFile = "C:\usercredentials.txt"
$FileExists = Test-Path $CredsFile
if  ($FileExists -eq $false) {
    Write-Host 'Credential file not found. Enter your password:' -ForegroundColor Red
    Read-Host -AsSecureString | ConvertFrom-SecureString | Out-File $CredsFile
    $password = get-content $CredsFile | convertto-securestring
    $Cred = new-object -typename System.Management.Automation.PSCredential -argumentlist domain\$AdminName,$password}
else
    {Write-Host 'Using your stored credential file' -ForegroundColor Green
    $password = get-content $CredsFile | convertto-securestring
    $Cred = new-object -typename System.Management.Automation.PSCredential -argumentlist domain\$AdminName,$password}
#END OF STORED CREDENTIAL CODE
