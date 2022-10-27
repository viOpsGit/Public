<#
Authors: Holly Williams, Abdalla Al Sharif
Version: 1.2
Date: 10/26/2022

Objective: To automate SSO updates when a new SSL certificate is installed

Actions:
Adds permissions to certificate for "IIS_IUSRS" group
Backups up web.configs with "LocalCertificateSerialNumber" attribute in web.config files that exist under E:\Sites
Updates files with new serial number
Updates all SSL web bindings to use the new certificate
Outputs details to a log file

Pre-requisites: 
viGlobal wildcard certificate for 2023 must already be installed
Run as an administrator
#>
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
  # Relaunch as an elevated process:
  Start-Process powershell.exe "-File",('"{0}"' -f $MyInvocation.MyCommand.Path) -Verb RunAs
  exit
}
# Now running elevated so launch the script:

Import-Module WebAdministration

#Set log file
$logfile = "E:\Sites\CertificateUpdate-2023.txt"

#Get Certificate details
$Certificate = Get-ChildItem Cert:\LocalMachine\My | Where { $_.FriendlyName -like "wildcard-viglobalcloud-2023" } -ErrorAction SilentlyContinue

if ($Certificate){

    $logmessage = "Certificate found - beginning adding permissions"
    $logmessage >> $logfile
}
else {
    $logmessage = "Unable to find certificate"
    $logmessage >> $logfile
    exit 404
}

###
### Add Permissions to Private Key for built in group IIS_IUSRs
###
Try {

    $rsaCert = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
    $fileName = $rsaCert.key.UniqueName

    If (Test-Path -Path "$env:ALLUSERSPROFILE\Microsoft\Crypto\RSA\MachineKeys\$fileName") {
        $path = "$env:ALLUSERSPROFILE\Microsoft\Crypto\RSA\MachineKeys\$fileName"
    }
    else {
        $path = Get-ChildItem -recurse -filter $filename -Path "$env:ALLUSERSPROFILE\Microsoft\Crypto\"
        $path = $path.FullName
    }

    $permissions = Get-Acl -Path $path
    $access_rule = New-Object System.Security.AccessControl.FileSystemAccessRule("IIS_IUSRS", 'Read', 'None', 'None', 'Allow')
    $permissions.AddAccessRule($access_rule)
    Set-Acl -Path $path -AclObject $permissions

    $logmessage = "Successfully added read permissions to private key for IIS_IUSRS"
    $logmessage >> $logfile

}
Catch {

    $logmessage = "Unable to add read permissions to private key for IIS_IUSRS"
    $logmessage >> $logfile
    $_ >> $logfile
}

###Update Certificate serial number

$filelocs=@( Get-ChildItem -recurse -filter "web.config" -Path "E:\Sites\")

	###create array with what to look for and what to change to 
	$Dictionary = @{
		"LocalCertificateSerialNumber"    = $Certificate.SerialNumber
			
	}

ForEach ($file in $filelocs) {

    #### grab as xml
    $xml = [xml](Get-Content $file.FullName)									

    foreach($key in $Dictionary.Keys)
    {
        ######Use XPath to find the appropriate node
        if(($addKey = $xml.SelectSingleNode("//appSettings/add[@key = '$key']")))
        {

            $logmessage = "Found serial in $file, updating value to $($Dictionary[$key])" 
            $logmessage >> $logfile

            Copy-Item $file.fullname -Destination "$($file)-2023.bak" -Force
            $addKey.SetAttribute('value',$Dictionary[$key])

            $logmessage = "Web Config files completed successfully for $($file.fullname) and $key" 
            $logmessage >> $logfile
            $_ >> $logfile
        ####save changes
        $xml.Save($file.FullName)
        }
    }			
}

###
###Get and replace all site bindings with the new certificate
###

Try{
    $Bindings = get-item IIS:\SslBindings\* | where { $_.host -like "*viglobalcloud*" }

ForEach ($Binding in $Bindings) {

    $Binding | Remove-Item -Force
    $certificate | New-Item -path "IIS:\SslBindings\$($binding.IPAddress)!$($binding.Port)" -Force

    $logmessage = "Updated SSL bindings with new certificate thumbprint"
    $logmessage >> $logfile
}
}
Catch{
    $logmessage = "Unable to add read permissions to private key for IIS_IUSRS"
    $logmessage >> $logfile
    $_ >> $logfile
}