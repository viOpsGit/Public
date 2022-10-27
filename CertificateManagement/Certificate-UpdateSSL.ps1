Import-Module WebAdministration

#Set log file
$logfile = "E:\Sites\CertificateUpdate-2023.txt"

#Get Certificate details
$Certificate = Get-ChildItem Cert:\LocalMachine\My | Where { $_.FriendlyName -like "*viglobalcloud-2023" }

##Add Permissions to Private Key for built in group IIS_IUSRs
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

##Get and replace all site bindings with the new certificate

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
    $logmessage = "Unable to update SSL bindings"
    $logmessage >> $logfile
    $_ >> $logfile
}