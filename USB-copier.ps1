
function AutoConfig {
    
}


$query = Invoke-SqliteQuery -DataSource 'C:\Windows\System32\Wpshl' -Query "SELECT * FROM device" 
$query
Write-Host($query.deviceID)
if($query.deviceID) {
    Write-Host 'value exists in device table'
} else {
    Write-Host 'value doesn`t exist in device table'
}
# $jsonObject = Get-Content $configJsonFilePath | Out-String | ConvertFrom-Json

# do {
#   $devicesSerialNumbers = Get-Disk | Select-Object SerialNumber | ForEach-Object { $_.SerialNumber}
#   foreach($deviceSerialNumber in $devicesSerialNumbers) {
#     if($jsonObject.excludedDevicesSerialNumbers.Contains($deviceSerialNumber)) {
#       Write-Host "Excluded: ", $deviceSerialNumber
#     } else {
#       # Write-Host "NotExcluded:" $deviceSerialNumber
#       # Choose your file copying approach
#     }
#   }
#   Start-Sleep -Seconds 5
# } while ($true)


# Get-Disk | Where-Object { $_.SerialNumber -eq "0000_0000_0100_0000_E4D2_5CDE_338F_5101." } | Get-Partition | Select-Object DriveLetter | foreach { $_.DriveLetter } | Where-Object { $_ }

# Get-WmiObject Win32_DiskDrive | Where-Object {$_.SerialNumber -eq "F93211052700202"} | Select-Object DeviceID
# Get Device Serial Number
# Option 1
# Get-WmiObject Win32_DiskDrive | Select-Object Model, Name, SerialNumber

# # Option 2
# $diskdrive = Get-WmiObject win32_diskdrive
# foreach($drive in $diskdrive)
#   {
#   out-host -InputObject "`nDevice: $($drive.deviceid.substring(4))`n  Model: $($drive.model)"
#   # partition
#   $partitions = Get-WmiObject -Query "ASSOCIATORS OF {Win32_DiskDrive.DeviceID=`"$($drive.DeviceID.replace('\','\\'))`"} WHERE AssocClass = Win32_DiskDriveToDiskPartition"
#   foreach($part in $partitions)
#     {
#     Out-Host -InputObject "  Partition: $($part.name)"
#     $vols = Get-WmiObject -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID=`"$($part.DeviceID)`"} WHERE AssocClass = Win32_LogicalDiskToPartition"
#     foreach($vol in $vols)
#       {
#       out-host -InputObject "  Volume: $($vol.name)"
#       $serial = Get-WmiObject -Class Win32_Volume | where { $_.Name -eq "$($vol.name)\" } | select SerialNumber
#       out-host -InputObject "  Serial Number: $($serial.serialnumber)"
#       }
#     } 
#   }


  