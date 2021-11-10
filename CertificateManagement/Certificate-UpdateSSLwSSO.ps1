<#
Authors: Holly Williams, Abdalla Al Sharif
Version: 1.1
Date: 10/29/2021

Objective: To automate SSO updates when a new SSL certificate is installed

Actions:
Adds permissions to certificate for "IIS_IUSRS" group
Updates the "LocalCertificateSerialNumber" attribute in web.config files that exist under E:\Sites
Updates all SSL web bindings to use the new certificate
Updates 509 certiicate data for federationmetadata.xml files that exist under E:\Sites
Outputs details to a log file

Pre-requisites: 
viGlobal wildcard certificate for 2022 must already be installed
Run as an administrator
#>

Import-Module WebAdministration

#Set log file
$logfile = "E:\Sites\CertificateUpdate-2022.txt"

#Get Certificate details
$Certificate = Get-ChildItem Cert:\LocalMachine\My | Where { $_.FriendlyName -like "Wil*2022*" }

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
			#Write-Host "Found key: '$key' in XML, updating value to $($Dictionary[$key])"
			$addKey.SetAttribute('value',$Dictionary[$key])

            $logmessage = "Web Config files completed successfully for $($file.fullname) and $key" 
            $logmessage >> $logfile
            $_ >> $logfile
		}
							
		####save changes
		$xml.Save($file.FullName)
	}					
}

###
###Get and replace all site bindings with the new certificate
###

Try{
    $Bindings = get-item IIS:\SslBindings\* | where { $_.port -eq 443 }

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

###Update ADFS MetaData

$metalocs = @( Get-ChildItem -recurse -filter "federationmetadata.xml" -Path "E:\Sites\")

$xcer=new-object System.Text.StringBuilder
$xcer.AppendLine([System.Convert]::ToBase64String($Certificate.RawData))
$cer=$xcer.ToString().Trim()

ForEach ($meta in $metalocs) {
	#### grab as plaintext
	(Get-Content $meta.FullName -raw) -replace "(?<=<X509Certificate>)(.*)(?=<\/X509Certificate>)","$cer" | Set-Content -Path $meta.FullName -Force						
	
   <# $logmessage = "Updating metadata file at $($meta.fullname)"
	$logmessage >> $logfile
	$_ >> $logfile	#>			
}