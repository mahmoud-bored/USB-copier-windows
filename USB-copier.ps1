
# Gets all drives that are not related to the system
# Get-PSDrive -PSProvider FileSystem | 
# Where-Object {
#     $_.CurrentLocation -notmatch "Users\\*" -and 
#     $_.CurrentLocation -notmatch "users\\*"
# }

function ConfigureFile {
  Write-Host " "
  Write-Host "Your Connected Devices: "
  # Get-WmiObject Win32_DiskDrive | Select-Object Model, Name, SerialNumber
  $devicesList = [System.Collections.ArrayList]@()
  $devicesDataObject = @{}
  $localIterator = 0
  Get-WmiObject Win32_DiskDrive | 
    ForEach-Object {
        # Add the index property to each object
        $_ | Add-Member -MemberType NoteProperty -Name "ID" -Value $localIterator
        $devicesList += $localIterator
        $devicesDataObject.Add($localIterator, $_.SerialNumber)
        $localIterator++
        $_
    } |
    Select-Object ID, Model, Name, SerialNumber |
    Format-Table -AutoSize

    Write-Host "Choose Your Excluded Devices ID (eg. 0, 1 or 2), `nType `"all`" to select all `nType `"reset`" to reset, `nType `"done`" if you're done, `nType `"exit`" to cancel."



  $excludedDevicesIDs = @()
  for($true) {
    $userInput = Read-Host "=>"
    # Exit Program
    if($userInput -eq "exit") {
      exit
    # Reset Selection
    } elseif($userInput -eq "reset") {
      $excludedDevicesIDs = @()
      Write-Host "Resetted"
    # End Loop
    } elseif($userInput -eq "done") {
      if($excludedDevicesIDs.Length -eq 0) {
        Write-Host "Error: You have to select at least one device ID."
      } else {
        break
      }
    # Select All
    } elseif($userInput -eq 'all') {
      $excludedDevicesIDs = $devicesList
      break
    # Check user input
    } else {
      # Check if user Input is valid
      if($userInput -in $excludedDevicesIDs) {
        Write-Host "Error: Device Already Selected!"
      } elseif($userInput -in $devicesList -and $userInput) {
        $excludedDevicesIDs += $userInput
      } else {
        Write-Host "Error: Invalid Input!"
      }
    }
    Write-Host "Selected Devices: ($excludedDevicesIDs)"
  }
  Write-Host "Selected Devices: ($excludedDevicesIDs) `nDone."
  
  $excludedDevicesSerialNumbers = [System.Collections.ArrayList]@()
  foreach ($ID in $excludedDevicesIDs) {
    $excludedDevicesSerialNumbers += $devicesDataObject[[int]$ID]
  }
  # TODO: Remove in Production
  Write-Host "Serial Numbers: ($excludedDevicesSerialNumbers)"
  # $excludedDevicesSerialNumbers = $excludedDevicesSerialNumbers | ConvertTo-Json
  $configJson = @{}
  $configJson['excludedDevicesSerialNumbers'] = $excludedDevicesSerialNumbers
  $configJson['devices'] = @{}
  $configJson = $configJson | ConvertTo-Json
  $configJson | Out-File $configJsonFilePath

  Write-Host "---------------------Configuration Done.---------------------"
  Write-Host " "
}

function CheckFileConfiguration {
  $jsonObject = Get-Content $configJsonFilePath | Out-String | ConvertFrom-Json
  if($jsonObject.excludedDevicesSerialNumbers.Length -eq 0 -or !$jsonObject.PSObject.Properties['devices']) {
    Write-Host 'File Exists: Not Configured Properly!'
    ConfigureFile
  } else {
    Write-Host 'File Exists: Configured Properly.'
  }
}



$configJsonFilePath = './N138974314908GLS.json'
# Check if file Exists
if (!(Test-Path $configJsonFilePath -PathType Leaf)) {
  Write-Host 'Creating New File.'
  New-Item $configJsonFilePath
}
CheckFileConfiguration
# Check File Configuration



$jsonObject = Get-Content $configJsonFilePath | Out-String | ConvertFrom-Json

# do {
#   $devicesSerialNumbers = Get-Disk | Select-Object SerialNumber | ForEach-Object { $_.SerialNumber}
#   foreach($deviceSerialNumber in $devicesSerialNumbers) {
#     if($jsonObject.excludedDevicesSerialNumbers.Contains($deviceSerialNumber)) {
#       Write-Host "Excluded: ", $deviceSerialNumber
#     } else {
#       Write-Host "NotExcluded:" $deviceSerialNumber
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


  