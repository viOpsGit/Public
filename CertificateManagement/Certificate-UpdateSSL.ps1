Import-Module WebAdministration

##get all current site bindings
$Bindings=get-item IIS:\SslBindings\* | where {$_.port -eq 443}
$Certificate=Get-ChildItem Cert:\LocalMachine\My | Where {$_.FriendlyName -like "*2021*"}


ForEach($Binding in $Bindings){

$Binding | Remove-Item -Force

$certificate | New-Item -path "IIS:\SslBindings\$($binding.IPAddress)!$($binding.Port)" -Force

}