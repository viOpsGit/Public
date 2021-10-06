Import-Module WebAdministration

#Set log file
$logfile = "E:\Sites\CertificateUpdate-2021.txt"

#Get Certificate details
$Certificate = Get-ChildItem Cert:\LocalMachine\My | Where { $_.FriendlyName -like "Wildcard*2021*" }

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

###
### Abdalla - Update thumbprint in web.config file
###

####set variables here
$webconfigname = "Web.config"

<##### File location needs to searched

Something like $filelocs=@( Get-ChildItem -recurse -filter $webconfigname -Path "E:\Sites\")
Then a ForEach ($file in $filelocs) {Run the script and replace the thumbprint}

###>

#####Start Loop
do {
		#Write-Host -NoNewline " `n`nChecking Folder "
		#Write-Host -NoNewline " `n`nWhere is webconfig located?  "
		#$filloc = Read-Host "Please enter the folder where webconfig is located"
		
		#### check that the folder does exist, if so set it and find web config
		$pathexists =  ( $(Try { Test-Path $filloc.trim() } Catch { $false }) )

		#### folder path exists
		if ($pathexists -eq ($true)){
				
				#### path ok find the webconfig
				#write-host "Path OK"
				$filexists = ( $(Try { Test-Path ($filloc.trim() + "\" +$webconfigname.trim()) } Catch { $false }) ) 
					
					#### File found
					if ($filexists -eq $true) {
						#write-host "File Found"
						
						###set the file 
						$file = ($filloc.trim() + "\" +$webconfigname.trim())
						
						#### grab as xml
						## $xml = Get-Content $filexists -as [Xml]  ###another way of writting it bellow
						$xml = [xml](Get-Content $file)
												
						###create array with what to look for and what to change to 
						$Dictionary = @{
							"LocalCertificateSerialNumber"    = $Certificate.Thumbprint
			
						}

						foreach($key in $Dictionary.Keys)
						{
							#Write-Host "Locating key: '$key' in XML"
							######Use XPath to find the appropriate node
							if(($addKey = $xml.SelectSingleNode("//appSettings/add[@key = '$key']")))
							{
								#Write-Host "Found key: '$key' in XML, updating value to $($Dictionary[$key])"
								$addKey.SetAttribute('value',$Dictionary[$key])
							}
							
							####save changes
							$xml.Save($file)
						}
						
						####Everything complete exit 
						#Write-Host "`nComplete!"
						#Read-Host "(Press any key to exit)"
                        $logmessage = "Web Config files completed successfully" 
                        $logmessage >> $logfile
                        $_ >> $logfile
						Exit
					}
				
				#### path ok but file not found
				ELSE {
					#Write-Host "File Not Found "  ($filloc.trim() + "\" +$webconfigname.trim()) 
					#Read-Host "(Press any key to exit)"
                    $logmessage = "File Not Found " + ($filloc.trim() + "\" +$webconfigname.trim()) 
                    $logmessage >> $logfile
                    $_ >> $logfile
					Exit
				}
		}
		

	#### path not found
	Else {
	   #write-host "Path not found"
       $logmessage = "Path not found"
       $logmessage >> $logfile
       $_ >> $logfile
		}
}

###end Loop
While($pathexists -eq $false)