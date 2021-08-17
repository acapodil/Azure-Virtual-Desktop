param([switch]$Elevated)

function Test-Admin {
  $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
  $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if ((Test-Admin) -eq $false)  {
    if ($elevated) 
    {
        # tried to elevate, did not work, aborting
    } 
    else {
        Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -noexit -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
}

exit
}




Write-Output "This script will join your recently provisioned storage account to you Active Directory Domain. This must be completed before using your AVD Deployment." 
Write-Output "Please ensure your domain admin has MFA disabled and Security defaults is disabled on your tenant."


$administratorAccountUsername = Read-Host -Prompt "Enter an Azure AD Global Admin username: "
$Password = Read-Host  -Prompt "Enter your AD DS admin password: " -AsSecureString
$ResourceGroupName = Read-Host -Prompt "Enter the Resource Group Name for your AVD Deployment: "
$StorageAccountName = Read-Host -Prompt "Enter the Storage Account name from your AVD deployment: "
$SubscriptionID = Read-Host -Prompt "Enter your SubscriptionID: "

#converts to string for input
$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
$administratorAccountPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)

#install az modules
Install-Module -Name Az -force -AllowClobber 
   
$TenantAdminPassword = ConvertTo-SecureString -String $administratorAccountPassword -AsPlainText -Force #pull from arm

$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $administratorAccountUsername, $TenantAdminPassword 
  
$login = Connect-AzAccount -Credential $Credential -Subscription $SubscriptionID

Write-Output $login

$Url = 'https://github.com/Azure-Samples/azure-files-samples/releases/download/v0.2.0/AzFilesHybrid.zip'
Invoke-WebRequest -Uri $Url -OutFile "C:\AzFilesHybrid.zip"
Expand-Archive -Path "C:\AzFilesHybrid.zip" -DestinationPath "C:\Windows\System32\AzFilesHybrid" -Force
cd "C:\Windows\System32\AzFilesHybrid"
.\CopyToPSPath.ps1 
Import-Module -Name AzFilesHybrid -Verbose -Force

Join-AzStorageAccountForAuth -verbose `
   -ResourceGroupName $ResourceGroupName `
   -StorageAccountName $StorageAccountName `
   -DomainAccountType "ComputerAccount" `
   -OrganizationalUnitName "Storage Accounts" # If you don't provide the OU name as an input parameter, the AD identity that represents the storage account is created under the root directory.


Write-Output "Done."
   