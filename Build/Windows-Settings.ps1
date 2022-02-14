### Initialize Data disk and set to E - if dvd drive exists sets to A
$driveLetter = "E"
$label="Data"

If (Get-CimInstance -Query "SELECT * FROM Win32_Volume WHERE DriveType='5'"){
    Get-CimInstance -Query "SELECT * FROM Win32_Volume WHERE DriveType='5'" | Set-CimInstance -Arguments @{DriveLetter="A:"}
}

$disk = Get-Disk | Where partitionstyle -eq 'raw' | sort number
$disk |
Initialize-Disk -PartitionStyle MBR -PassThru |
New-Partition -UseMaximumSize -DriveLetter $driveLetter |
Format-Volume -FileSystem NTFS -NewFileSystemLabel $label -Confirm:$false -Force

### Create Temp Directory
New-Item -Path "C:\" -Name "Temp" -ItemType "directory"

## Copy all required install tools
Copy-Item -Path "Microsoft.PowerShell.Core\FileSystem::\\viopsc002\Installs\Auto\*" -Destination C:\Temp\

## Check that file exists and Install IIS
If (Test-Path -Path C:\Temp\IIS-DeploymentConfigTemplate.xml){
Install-WindowsFeature -ConfigurationFilePath C:\Temp\IIS-DeploymentConfigTemplate.xml
}
Else {
Write-Host "unable to find IIS config template"}

#Set TimeZone
Set-TimeZone -Id "Eastern Standard Time" -PassThru

#Set Remote Desktop
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -value 0
(Get-WmiObject -class "Win32_TSGeneralSetting" -Namespace root\cimv2\terminalservices -Filter "TerminalName='RDP-tcp'").SetUserAuthenticationRequired(0)

#Add Support Groups to Local Admin
##Removed from this copy

#Set Performance

<#need to figure out#>

#Set Custom page file size
$pagefileset = Gwmi win32_pagefilesetting | where{$_.caption -like 'D:*'}
$pagefileset.InitialSize = 2800
$pagefileset.MaximumSize = 2800
$pagefileset.Put() | Out-Null

#Disable Windows Defender
Set-MpPreference -DisableRealtimeMonitoring $true

#Disable ipv6

$ipv6name=Get-NetAdapterBinding -ComponentID ms_tcpip6
Disable-NetAdapterBinding -Name $ipv6name.name -ComponentID ms_tcpip6

#Rename Net Adapter

Rename-NetAdapter -Name (Get-NetAdapter).name -NewName "$env:computername"

Set-Location "C:\temp"

.\SophosSetup.exe --quiet

start-sleep 600

.\SSMS-Setup-ENU.exe /install /quiet /passive /norestart
