function LogMessage{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$logMessage
    )
    
    $dateFormat = "dd/MM/yyyy HH:mm:ss"
    $currentDate = "[$(Get-Date -format $dateFormat)]: $logMessage"
    


    $isWritten = $false
    $numberOfRetries = 0
    do {
        try {
            $numberOfRetries++
            $currentDate | Add-content -Path $logFilePath -ErrorAction Stop
            $isWritten = $true
        } catch { }
    } until ( $isWritten -or ($numberOfRetries -gt 5) )
}
function LogTable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        $table
    )
    $table | Add-content -Path $logFilePath 
}
function CheckLogFile {
    if(!(Test-Path $logFilePath -PathType Leaf)) {
        New-Item $logFilePath | Out-Null
        LogMessage "[ERROR]: Log file Not found, Creating new Log file..."
        LogMessage "[NEW]: Log file Created!"
    }
}
function CheckNecessaryModules {
    # Check for NuGet
    try {
        Get-PackageProvider -Name "NuGet" -ForceBootstrap | Format-Table -AutoSize
        LogMessage "[INFO]: NuGet Bootstrapped."
    }
    catch {
        LogMessage $_
        LogMessage "[ERROR]: Couldn't Install NuGet, Exiting..."
        exit
    }
    # Check for PSSQLite
    if(!(Get-Module -ListAvailable -Name "PSSQLite")) {
        LogMessage "[ERROR]: Module PSSQLite Doesn't Exist."
        LogMessage "[PROCESS]: Installing PSSQLite..."
        try {
            Install-Module PSSQLite -Force
            LogMessage "[NEW]: PSSQLite Installed Successfully!"
        } catch {
            $_ | Add-Content -Path $logFilePath
            LogMessage "[ERROR]: Couldn't install PSSQLite, Exiting..."
            exit
        }
    }
}
function CheckDbConfig {
    # Import PSSQLite
    try {
        Import-Module PSSQLite
    } catch {
        LogMessage $_
        LogMessage "[ERROR]: Couldn't Access PSSQLite module, Exiting..."
        exit
    }

    # Check Database File
    if(!(Test-Path $dbPath -PathType Leaf)) {
        LogMessage "[ERROR]: Database Doesn't Exist."
        LogMessage "[PROCESS]: Creating Database File..."
        try {
            New-Item $dbPath | Out-Null
            LogMessage "[NEW]: Database Created!"
        } catch {
            LogMessage $_
            LogMessage "[ERROR]: Couldn't Create Database, Exiting..."
            exit
        }
    } 
    $dbTablesCreationQueries = @{
        device = "CREATE TABLE device (
            device_id INTEGER PRIMARY KEY NOT NULL,
            device_name TEXT,
            serial_number TEXT NOT NULL,
            last_full_backup_date INTEGER NOT NULL DEFAULT 0,
            last_live_date INTEGER NOT NULL DEFAULT 0,
            backup_path TEXT,
            is_device_excluded INTEGER NOT NULL DEFAULT 0,
            author TEXT
        )"
        volume = "CREATE TABLE volume (
            volume_id INTEGER PRIMARY KEY NOT NULL,
            volume_unique_id TEXT NOT NULL,
            volume_backup_path TEXT NOT NULL,
            last_full_backup_date INTEGER NOT NULL DEFAULT 0,
            last_live_date INTEGER NOT NULL DEFAULT 0,
            volume_size TEXT NOT NULL,
            volume_remaining_size TEXT NOT NULL,
            volume_filesystem_type TEXT NOT NULL,
            device_id INTEGER NOT NULL,
            FOREIGN KEY(device_id) REFERENCES device(device_id)
        )"
        directory = "CREATE TABLE directory (
            directory_id INTEGER PRIMARY KEY NOT NULL,
            directory_path TEXT NOT NULL,
            directory_name TEXT NOT NULL,
            parent_directory INTEGER NOT NULL,
            volume_id INTEGER NOT NULL,
            FOREIGN KEY(parent_directory) REFERENCES directory(directory_id),
            FOREIGN KEY(volume_id) REFERENCES volume(volume_id)
        )"
        file = "CREATE TABLE file (
            file_id INTEGER PRIMARY KEY NOT NULL,
            file_path TEXT NOT NULL,
            file_name TEXT NOT NULL,
            file_extension TEXT NOT NULL,
            file_size INTEGER NOT NULL, 
            directory_id INTEGER NOT NULL,
            volume_id INTEGER NOT NULL,
            last_write_time_utc INTEGER,
            last_backup_time_utc INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(directory_id) REFERENCES directory(directory_id),
            FOREIGN KEY(volume_id) REFERENCES volume(volume_id)
        )"
    }
    foreach($dbTableName in $dbTablesCreationQueries.Keys) {
        if(!(Invoke-SqliteQuery -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='$dbTableName';" -DataSource $dbPath)) {
            LogMessage "[ERROR]: Table `"$dbTableName`" Doesn't Exist."
            try {
                LogMessage "[PROCESS]: Creating `"$dbTableName`" Table..."
                Invoke-SqliteQuery -Query $dbTablesCreationQueries.$dbTableName -DataSource $dbPath
                LogMessage "[NEW]: Table `"$dbTableName`" was Created Successfully!"
            }
            catch {
                LogMessage  $_
                LogMessage "[ERROR]: Couldn't create `"$dbTableName`" Table, Exiting..."
                exit
            }
        }
    }
    
}


function CheckExcludedDevices{
    # Set excluded devices if they don't exist in database
    $excludedDevicesIDs = Invoke-SqliteQuery -DataSource 'C:\Windows\System32\Wpshl' -Query "SELECT device_id FROM device" 
    if(!$excludedDevicesIDs) {
        LogMessage "[ERROR]: No excluded devices found!"
        LogMessage "[PROCESS]: Setting excluded devices"
        $devicesSerialNumbers = Get-Disk | Select-Object SerialNumber | ForEach-Object { $_.SerialNumber }
        foreach($deviceSerialNumber in $devicesSerialNumbers) {
            $deviceName = Get-Disk | Where-Object { $_.SerialNumber -eq $deviceSerialNumber } | Select-Object FriendlyName | ForEach-Object { $_.FriendlyName }
            Write-Host "[NEW]: Regestering new device <$deviceName::$deviceSerialNumber>"
            Invoke-SqliteQuery -DataSource $dbPath "
                INSERT INTO device (device_name, serial_number, is_device_excluded)
                VALUES ('$deviceName', '$deviceSerialNumber', 1)
            "
        }
    }

}
function CheckBackupDirectory {
    if(!(Test-Path -Path $backupDirectoryPath)) {
        LogMessage "[ERROR]: Main Backup directory not found!"
        LogMessage "[PROCESS]: Creating New Main Backup directory..."
        New-Item -path $backupDirectoryPath -ItemType Directory | Out-Null
        LogMessage "[NEW]: Backup directory Created!"
    }
}
$workDir = 'C:\Windows\System32'
$dbPath = $workDir + '\Wpshl'
$logFilePath = $workDir + '\n138974314908GLs'
$backupDirectoryPath = $workDir + '\WdM'
function AutoConfig {
    CheckLogFile
    CheckNecessaryModules
    CheckDbConfig
    CheckBackupDirectory
    CheckExcludedDevices
}
function GenerateRandomString {
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$True)]
        [int]$letterCount
    )
    $TokenSet = @{
        U = [Char[]]'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        L = [Char[]]'abcdefghijklmnopqrstuvwxyz'
        N = [Char[]]'0123456789'
    }    
    $Upper = Get-Random -Count 5 -InputObject $TokenSet.U
    $Lower = Get-Random -Count 5 -InputObject $TokenSet.L
    $Number = Get-Random -Count 5 -InputObject $TokenSet.N
    $StringSet = $Upper + $Lower + $Number
    
    return (Get-Random -Count $letterCount -InputObject $StringSet) -join ''
}
function GenerateNewDeviceBackupPath {
    $newStr = GenerateRandomString 15
    $newDirPath = $backupDirectoryPath + '\' + $newStr
    LogMessage "[PROCESS]: Generating new device backup folder name <$newStr>"
    if(Test-Path -Path $newDirPath) {
        LogMessage "[INFO]: Device Backup folder name is not Valid. Generating New name..."
        GenerateNewDeviceBackupPath
    } else {
        LogMessage "[INFO]: Device Backup folder name is Valid!"
        try {
            LogMessage "[PROCESS]: Creating Device Backup folder."
            New-Item -Path $newDirPath -ItemType Directory | Out-Null
            return $newDirPath
        } catch {
            LogMessage $_
            LogMessage "[ERROR]: Couldn`'t create Device Backup Folder!"
        }
    }
}
function RegisterNewDevice {
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$True)]
        [string]$serialNumber,
        [string]$deviceName
    )
    $newBackupPath = GenerateNewDeviceBackupPath
    LogMessage "Created New Backup Path at: `n$newBackupPath `nDevice: <$deviceName::$serialNumber>"
    $query = "
        INSERT INTO device (device_name, serial_number, backup_path)
                    VALUES ('$deviceName', '$serialNumber', '$newBackupPath')
    "
    try {
        LogMessage "[PROCESS]: Adding new device to database. `n<$deviceName::$serialNumber>"
        Invoke-SqliteQuery -DataSource $dbPath -Query $query
        LogMessage "[NEW]: New device Registered! `n<$deviceName::$serialNumber>"
    } catch {
        LogMessage $_
        LogMessage "[ERROR]: Couldn`'t Register device to database."
    }
}
function GenerateNewVolumeBackupPath {
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$True)]
        [string]$basePath
    )
    $newStr = GenerateRandomString 20
    $newDirPath = $basePath + '\' + $newStr
    LogMessage "[PROCESS]: Generating new volume backup folder name <$newStr>"
    if(Test-Path -Path $newDirPath) {
        LogMessage "[INFO]: Volume Backup folder name is not Valid. Generating New name..."
        GenerateNewDeviceBackupPath
    } else {
        LogMessage "[INFO]: Volume Backup folder name is Valid!"
        try {
            LogMessage "[PROCESS]: Creating Volume Backup folder."
            New-Item -Path $newDirPath -ItemType Directory | Out-Null
            return $newDirPath
        } catch {
            LogMessage $_
            LogMessage "[ERROR]: Couldn`'t create Volume Backup Folder!"
        }
    }
}
function CreateVolumeRootDirectory {
    [CmdletBinding()]
    param (
        [parameter(Mandatory=$True)]
        [string]$volumeUniqueId,
        [string]$volumeBackupPath
    ) 
    try {
        LogMessage "[PROCESS]: Creating Volume Root Directory."
        $volumeID = (Invoke-SqliteQuery -DataSource $dbPath -Query "SELECT volume_id FROM volume WHERE volume_unique_id = `"$volumeUniqueId`"").volume_id
        # Create Volume Root directory
        $query = "INSERT INTO directory (directory_path, directory_name, parent_directory, volume_id)
            VALUES ('\', 'root', 0, `"$volumeID`")
        "
        Invoke-SqliteQuery -DataSource $dbPath -Query $query
        LogMessage "[NEW]: Volume Root Directory Created!"
    } catch {
        LogMessage $_
        LogMessage "[ERROR]: Couldn`'t Create Volume Root Directory."
    }
}
function RegisterNewVolume {
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$True)]
        [string]$deviceSerialNumber,
        [string]$deviceBackupPath,
        [Object[]]$volumeData
    )
    LogMessage "Registering New Volume."
    $deviceID = Invoke-SqliteQuery -DataSource $dbPath -Query "SELECT device_id FROM device WHERE serial_number = `"$deviceSerialNumber`"" | ForEach-Object { $_.device_id }
    $volumeBackupPath = GenerateNewVolumeBackupPath $deviceBackupPath
    try {
        $query = "
            INSERT INTO volume (volume_unique_id, volume_backup_path, last_live_date, volume_size, volume_remaining_size, volume_filesystem_type, device_id)
                        VALUES (@volumeUniqueId, @volumeBackupPath, @currentTime, @volumeSize, @volumeRemainingSize, @volumeFileSystem, @deviceID)
        "
        $queryParams = @{
            volumeUniqueId = $volumeData.UniqueId
            volumeBackupPath = $volumeBackupPath
            currentTime = [uint64](Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss')
            volumeSize = [string][math]::Round($volumeData.Size/1073741824, 2) + ' GiB'
            volumeRemainingSize = [string][math]::Round($volumeData.SizeRemaining/1073741824, 2) + ' GiB'
            volumeFileSystem = $volumeData.FileSystem
            deviceID = $deviceID
        }
        Invoke-SqliteQuery -DataSource $dbPath -Query $query -SqlParameters $queryParams

        CreateVolumeRootDirectory $volumeData.UniqueId $volumeBackupPath
        LogMessage "New $($volumeData.FileSystem) Volume Registered <$($volumeData.UniqueId)> at <$volumeBackupPath> with <$([string][math]::Round($volumeData.Size/1073741824, 2) + ' GiB')> Capacity."
    } catch {
        LogMessage $_
        LogMessage "[ERROR]: Couldn`'t Register New Volume."
    }
}
function GetDeviceBackupPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True)]
        [string]$deviceSerialNumber
    )
    $query = "SELECT backup_path FROM device WHERE serial_number = `"$deviceSerialNumber`""
    $backupPath = Invoke-SqliteQuery -DataSource $dbPath -Query $query | ForEach-Object { $_.backup_path }
    return $backupPath
}
function UpdateDeviceData {
    param (
        [Parameter(Mandatory=$true)]
        [string]$deviceSerialNumber
    )
    try {
        $query = "
            UPDATE device
            SET
                last_live_date = @currentTime
            WHERE
                serial_number = @serialNumber
        "
        $queryParams = @{
            currentTime = [uint64](Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss')
            serialNumber = $deviceSerialNumber
        }
        LogMessage "Updating Device <$deviceSerialNumber> Data."
        Invoke-SqliteQuery -DataSource $dbPath -Query $query -SqlParameters $queryParams
    }
    catch {
        LogMessage $_
        LogMessage "[ERROR]: Couldn`'t Update Device Data."
    }
}
function CheckDeviceVolumes {
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$True)]
        [string]$deviceSerialNumber,
        [Object[]]$diskVolumes
    )
    $deviceBackupPath = GetDeviceBackupPath $deviceSerialNumber
    $deviceID = (Invoke-SqliteQuery -DataSource $dbPath "SELECT device_id FROM device WHERE serial_number = `"$deviceSerialNumber`"").device_id
    $registeredDeviceVolumes = Invoke-SqliteQuery -DataSource $dbPath -Query "SELECT volume_unique_id, volume_backup_path FROM volume WHERE device_id = $deviceID"

    LogMessage "Checking <$deviceSerialNumber> Device Volumes..."
    foreach($diskVolumeData in $diskVolumes) {
        Write-Host "Checking Volume <$($diskVolumeData.UniqueId)>"
        LogMessage "Checking Volume <$($diskVolumeData.UniqueId)>"
        # Check if volume exists in database
        $isVolumeRegistered = $registeredDeviceVolumes | Where-Object { $_.volume_unique_id -eq $diskVolumeData.UniqueId } 
        if($isVolumeRegistered) {
            # Volume Already Exists
            Write-Host "Volume is Already Registered."
            Write-Host "Updating Volume <$($diskVolumeData.UniqueId)> Data."
            LogMessage "[INFO]: Volume is Already Registered."
            if(!(Test-Path -Path $isVolumeRegistered.volume_backup_path)) {
                New-Item -Path $isVolumeRegistered.volume_backup_path -Type Directory
            }
            try {
                LogMessage "Updating Volume <$($diskVolumeData.UniqueId)> Data."
                $query = "
                    UPDATE volume
                    SET 
                        last_live_date = @currentTime,
                        volume_size = @volumeSize,
                        volume_remaining_size = @volumeRemainingSize
                    WHERE
                        volume_unique_id = @volumeUniqueId
                "
                $queryParams = @{
                    currentTime = [uint64](Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss')
                    volumeSize = [string][math]::Round($diskVolumeData.Size/1073741824, 2) + ' GiB'
                    volumeRemainingSize = [string][math]::Round($diskVolumeData.SizeRemaining/1073741824, 2) + ' GiB'
                    volumeUniqueId = $diskVolumeData.UniqueId
                }

                Invoke-SqliteQuery -DataSource $dbPath -Query $query -SqlParameters $queryParams
                LogMessage "Volume Data Updated!"
            } catch {
                LogMessage $_
                LogMessage "[ERROR]: Couldn`'t Update Volume Data."
            }
        } else {
            # Volume Doesn't Exist, Setup New Volume 
            Write-Host "Volume <$($diskVolumeData.UniqueId)> not Registered."
            LogMessage "Volume <$($diskVolumeData.UniqueId)> is not Registered."

            RegisterNewVolume $deviceSerialNumber $deviceBackupPath $diskVolumeData 
        }
    }
}
function RegisterAndCreateDirectories {
    [CmdletBinding()]
    param (
        [parameter(Mandatory=$True)]
        [string]$volumeDriveLetter,
        [string]$volumeID
    )
    $volumeBackupPath = (Invoke-SqliteQuery -DataSource $dbPath -Query "SELECT volume_backup_path FROM volume WHERE volume_id = $volumeID").volume_backup_path  
    Get-ChildItem -Recurse -Directory "$($volumeDriveLetter)://" | Select-Object FullName, Name | ForEach-Object {
        $directoryPath = $_.FullName.Replace("$($volumeDriveLetter):", "")
        $isDirectoryRegistered = (Invoke-SqliteQuery -DataSource $dbPath -Query "SELECT directory_id FROM directory WHERE directory_path = `"$($directoryPath + '\')`"").directory_id
        if(!$isDirectoryRegistered) {
            LogMessage "[INFO]: Directory <$($_.FullName)> is Not Registered."
            try {
                LogMessage "[PROCESS]: Registering New Directory."
                New-Item -ItemType Directory -Force -Path $($volumeBackupPath + $directoryPath) | Out-Null
                LogMessage "[NEW]: Created new Folder at <$($volumeBackupPath + $directoryPath)>."
                LogMessage "Directory Path: $directoryPath"
                LogMessage "Directory Name: $($_.Name)"
                LogMessage "Parent Directory: $($directoryPath.Substring(0, ($directoryPath.Length - $_.Name.Length)))"
                $query = "INSERT INTO directory (directory_path, directory_name, parent_directory, volume_id)
                                        VALUES (@directoryPath, @directoryName, @parentDirectory, $volumeID)"
                $queryParams = @{
                    directoryPath = $directoryPath + '\'
                    directoryName = $_.Name
                    parentDirectory = (Invoke-SqliteQuery -DataSource $dbPath -Query "SELECT directory_id FROM directory WHERE directory_path = `"$($directoryPath.Substring(0, ($directoryPath.Length - $_.Name.Length)))`"").directory_id
                }
                Invoke-SqliteQuery -DataSource $dbPath -Query $query -SqlParameters $queryParams
                LogMessage "[NEW]: Directory <$($_.FullName)> was Registered Successfully."
            } catch {
                LogMessage $_
                LogMessage "[ERROR]: Couldn't Register <$($_.FullName)> Directory."
            }
        } else {
            LogMessage "[INFO]: Directory <$($_.FullName)> is Already Registered."
        }
        Write-Host "$($_.Name): $($_.FullName)"
    }
}
function StartBackupForFileExtension {
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$True)]
        [string]$volumeDriveLetter,
        [string]$volumeID,
        [string]$volumeBackupPath,
        [string]$fileExtensionFilter,
        [string[]]$fileExtensionExceptions
    )
    $volumeDrivePath = "$($volumeDriveLetter)://"
    LogMessage "[PROCESS]: Backing Up Files with Extension <$fileExtensionFilter>"
    Get-ChildItem -Recurse -File $volumeDrivePath -Filter $fileExtensionFilter | 
        Where-Object { $_.Extension -notin $fileExtensionExceptions } |
        ForEach-Object {
            Write-Host "$($_.Name): $($_.FullName)"
            $directoryPath = $_.FullName.Replace("$($volumeDriveLetter):", "")
            $directoryID = (Invoke-SqliteQuery -DataSource $dbPath -Query "SELECT directory_id FROM directory WHERE directory_path = `"$($directoryPath.Substring(0,$directoryPath.Length - $_.Name.Length))`"").directory_id
            $lastWriteTimeUtc = [uint64]$_.LastWriteTimeUtc.ToUniversalTime().ToString('yyyyMMddHHmmss')
            $fileSize = [uint64]$_.Length
            $fileDataFromDb = Invoke-SqliteQuery -DataSource $dbPath -Query "SELECT file_id, last_write_time_utc, file_size FROM file WHERE file_path = `"$directoryPath`""
            if($fileDataFromDb.file_id) {
                Write-Host "File is Already Registered."
                # Update Registered File in Database 
                if(($lastWriteTimeUtc -gt $fileDataFromDb.last_write_time_utc) -or ($fileSize -ne $fileDataFromDb.file_size)) {
                    # File content has changed
                    LogMessage "[CHANGE::PROCESS]: File Contents has Changed at <$directoryPath>, Backing up Changes."
                    Copy-Item $_.FullName -Destination "$($volumeBackupPath + $directoryPath)"
                    LogMessage "[CHANGE::NEW]: File Changes has been backed up."
                    Invoke-SqliteQuery -DataSource $dbPath -Query "
                        UPDATE file
                        SET last_backup_time_utc = $([uint64](Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss')),
                            last_write_time_utc = $lastWriteTimeUtc,
                            file_size = $fileSize
                        WHERE file_id = $($fileDataFromDb.file_id)
                    "
                } else {
                    # File content didn't change
                    Invoke-SqliteQuery -DataSource $dbPath -Query "
                        UPDATE file
                        SET last_backup_time_utc = $([uint64](Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss'))
                        WHERE file_id = $($fileDataFromDb.file_id)
                    "
                }
            } else {
                try {
                    Write-Host "File is Not Registered."
                    # Register & Copy New File in Database
                    LogMessage "[CHANGE::PROCESS]: New File Detected at <$directoryPath>, Registering New File."
                    Copy-Item $_.FullName -Destination "$($volumeBackupPath + $directoryPath)"
                    LogMessage "[CHANGE::NEW]: File has been Backed up."
                    $query = "INSERT INTO file (file_path, file_name, file_extension, file_size, directory_id, volume_id, last_write_time_utc, last_backup_time_utc)
                                        VALUES (@filePath, @fileName, @fileExtension, @fileSize, @directoryId, @volumeId, @lastWriteTimeUtc, @lastBackupTimeUtc)
                    "
                    $queryParams = @{
                        filePath = $directoryPath
                        fileName = $_.Name
                        fileExtension = $_.Extension
                        fileSize = $fileSize
                        directoryId = $directoryID
                        volumeId = $volumeID
                        lastWriteTimeUtc = $lastWriteTimeUtc
                        lastBackupTimeUtc = [uint64](Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss')
                    } 
                    Invoke-SqliteQuery -DataSource $dbPath -Query $query -SqlParameters $queryParams
                    LogMessage "[CHANGE::NEW]: File has been Registered"
                } catch {
                    LogMessage $_
                    LogMessage "[ERROR]: Couldn't Copy & Register New file."
                }
            }
        }
}
function RegisterAndCopyFiles {
    [CmdletBinding()]
    param (
        [parameter(Mandatory=$True)]
        [string]$volumeDriveLetter,
        [string]$volumeID
    )
    $volumeBackupPath = (Invoke-SqliteQuery -DataSource $dbPath -Query "SELECT volume_backup_path FROM volume WHERE volume_id = $volumeID").volume_backup_path
    
    $backupPriorityExtensions = @(
        # Microsoft Word
        ".doc", ".docx", ".docm", ".dot", ".dotx", ".dotm", ".odt", ".ott", ".rtf", ".wps", ".pages", ".wpd"
        # Microsoft Excel
        ".xls", ".xlsx", ".xlsm", ".xlsb", ".xlt", ".xltx", ".xltm", ".ods", ".ots", ".csv", 
        # Microsoft PowerPoint
        ".ppt", ".pptx", ".pptm", ".pot", ".potx", ".potm", ".pps", ".ppsx", ".ppsm", ".odp", ".otp", 
        # Microsoft OneNote
        ".one", ".onepkg", ".onetoc2", 
        # PDF
        ".pdf", ".fdf", ".xfdf", ".xdp", ".pdx", ".pdfa", ".pdfx", ".pdfe", ".pdfm"
        # Publisher
        ".pub", ".odg", ".epub", ".mobi", ".azw3", ".fb2"
        # Other
        ".xps", '.txt', '.text', '.md', '.tex', '.readme', '.nfo',
        # Images
        ".jpg", ".jpeg", ".png", ".gif", ".webp", ".psd", ".bmp", ".ico", ".tiff", ".tif", ".exr",
        # Recovery Files
        ".asd", ".wbk", ".xlk", ".pptx.tmp", ".~docx", ".~xlsx", ".~pptx", ".doc~", ".xls~", ".ppt~", ".bak", ".save", ".sw", ".tmp", ".old", ".lock"
    )
    foreach($fileExtension in $backupPriorityExtensions) {
        # Backup Priority File Extensions first
        StartBackupForFileExtension $volumeDriveLetter $volumeID $volumeBackupPath "*$($fileExtension)" @()
    }
    # Backup The rest of the File Extensions
    StartBackupForFileExtension $volumeDriveLetter $volumeID $volumeBackupPath "*.*" $backupPriorityExtensions
}
function InitiateVolumeBackup {
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$True)]
        [string]$volumeUniqueId,
        [string]$volumeDriveLetter
    )
    $volumeID = (Invoke-SqliteQuery -DataSource $dbPath -Query "SELECT volume_id FROM volume WHERE volume_unique_id = `"$volumeUniqueId`"").volume_id

    LogMessage "Backing up <$volumeUniqueId> at <$volumeDriveLetter>"
    RegisterAndCreateDirectories $volumeDriveLetter $volumeID
    RegisterAndCopyFiles $volumeDriveLetter $volumeID    

    # Update Volume Last Full Backup Date
    try {
        Invoke-SqliteQuery -DataSource $dbPath -Query "
            UPDATE volume
            SET last_full_backup_date = $([uint64](Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss'))
            WHERE volume_id = $volumeID
        "
        LogMessage '[NEW]: Volume last_full_backup_date Updated Successfully.'
    } catch {
        LogMessage $_
        LogMessage "[ERROR]: Couldn`'t Update Volume last_full_backup_date."
    }
}
function InitiateDeviceBackup {
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$True)]
        [string]$deviceSerialNumber
    )
    LogMessage "[PROCESS]: Initiating Backup <$deviceSerialNumber>"
    $diskVolumes = Get-Disk | Where-Object { $_.SerialNumber -eq $deviceSerialNumber } | Get-Partition | Get-Volume | Where-Object { $_.DriveLetter } | Select-Object DriveLetter, UniqueId, FileSystem, Size, SizeRemaining
    
    # Check if Device Backup Folder Exists
    $deviceBackupPath = (Invoke-SqliteQuery -DataSource $dbPath -Query "SELECT backup_path FROM device WHERE serial_number = `"$deviceSerialNumber`"").backup_path
    if(!(Test-Path -Path $deviceBackupPath)) {
        LogMessage "[PROCESS]: Device backup folder Not Found! Creating New Backup Folder."
        try {
            New-Item -Path $deviceBackupPath -ItemType Directory
        } catch {
            LogMessage $_
            LogMessage "[ERROR]: Couldn`'t Create Device backup Folder."
        }
    }

    UpdateDeviceData $deviceSerialNumber
    CheckDeviceVolumes $deviceSerialNumber $diskVolumes
    foreach($diskVolumeData in $diskVolumes) {
        InitiateVolumeBackup $diskVolumeData.UniqueId $diskVolumeData.DriveLetter
    }
    LogMessage "[PROCESS::END]: Device <$deviceSerialNumber> Backup Successful."
    try {
        Invoke-SqliteQuery -DataSource $dbPath -Query "
            UPDATE device
            SET last_full_backup_date = $([uint64](Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss'))
            WHERE serial_number = `"$deviceSerialNumber`"
        "
        LogMessage '[DONE]: Device last_full_backup_date Updated Successfully.'
    } catch {
        LogMessage $_
        LogMessage "[ERROR]: Couldn`'t Update Device last_full_backup_date."
    }
}
function Main {
    AutoConfig
    $attachedDevicesSerialNumbers = @()
    do {
        # Detect Changes in attached devices
        $currentAttachedDevicesData = Get-Disk | Select-Object FriendlyName, SerialNumber
        $currentAttachedDevicesSerialNumbers =  $currentAttachedDevicesData.SerialNumber
        $attachedDevicesChanges = Compare-Object -ReferenceObject $attachedDevicesSerialNumbers -DifferenceObject $currentAttachedDevicesSerialNumbers -PassThru
        if($attachedDevicesChanges) {
            $registeredDevices = Invoke-SqliteQuery -DataSource $dbPath -Query "SELECT device_name, serial_number, is_device_excluded FROM device"
            foreach($deviceSerialNumber in $attachedDevicesChanges) {
                # Check if the change is Attachment or Detachement
                $changeIsAttachement = $deviceSerialNumber -in $currentAttachedDevicesSerialNumbers 
                if($changeIsAttachement) {
                    Get-Disk | Where-Object { $_.SerialNumber -eq $deviceSerialNumber } | Select-Object FriendlyName | ForEach-Object { $_.FriendlyName }
                    $deviceName = $currentAttachedDevicesData | Where-Object { $_.SerialNumber -eq $deviceSerialNumber } | ForEach-Object { $_.FriendlyName }
                    # Check if the device is Registered in the database
                    $isDeviceRegistered = $deviceSerialNumber -in $registeredDevices.serial_number
                    if($isDeviceRegistered) {
                        # Check if device is Excluded
                        $isDeviceExcluded = $registeredDevices | Where-Object { $_.serial_number -eq $deviceSerialNumber } | ForEach-Object { $_.is_device_excluded }
                        if($isDeviceExcluded) {
                            Write-Host "New Excluded Device was Attached: <$deviceName::$deviceSerialNumber>"
                            LogMessage "New Excluded Device was Attached: <$deviceName::$deviceSerialNumber>"
                        } else {
                            Write-Host "New Device was Attached: <$deviceName::$deviceSerialNumber>"
                            LogMessage "New Device was Attached: <$deviceName::$deviceSerialNumber>"

                            InitiateDeviceBackup $deviceSerialNumber
                        }
                    } else {
                        # Device is not Registered
                        Write-Host "New Unregistered Device was Attached: <$deviceName::$deviceSerialNumber>"
                        LogMessage "New Unregistered Device was Attached: <$deviceName::$deviceSerialNumber>"
                        # Register the new device
                        RegisterNewDevice $deviceSerialNumber $deviceName
                        InitiateDeviceBackup $deviceSerialNumber
                    }
                } else {
                    Write-Host "Device Detached: $deviceSerialNumber"
                    LogMessage "Device Detached: $deviceSerialNumber"
                }
                
                $attachedDevicesSerialNumbers = $currentAttachedDevicesSerialNumbers
            }
        } else {
            Write-Host 'No Changes Yet'
        }
        Start-Sleep -Seconds 5
    } while ($True)
}
Main






# $registeredDevices = Invoke-SqliteQuery -DataSource $dbPath -Query "SELECT serial_number FROM device" | ForEach-Object { $_.serial_number }
# $devicesSerialNumbers = Get-Disk | Select-Object SerialNumber | ForEach-Object { $_.SerialNumber }

# foreach($deviceSerialNumber in $devicesSerialNumbers) {
#     if($deviceSerialNumber -in $registeredDevices) {
#         Write-Host "Device Already Registed: ", $deviceSerialNumber
#     } else {
#         $registeredDevices = Invoke-SqliteQuery -DataSource $dbPath -Query "SELECT serial_number FROM device" | ForEach-Object { $_.serial_number }
#         if(!($deviceSerialNumber -in $registeredDevices)) {
#             $newDeviceName = Get-Disk | Where-Object { $_.SerialNumber -eq $deviceSerialNumber } | Select-Object FriendlyName | ForEach-Object { $_.FriendlyName }
#             LogMessage "[NEW]: New device Detected. `nDevice Name: $newDeviceName `nSerial Number: $deviceSerialNumber"
#             $newDeviceData = Get-WmiObject -Class Win32_LogicalDisk | Select-Object *
#             LogTable $newDeviceData
#             RegisterNewDevice $deviceSerialNumber
#         }
#     }
#     if()
# }



# Get-Disk | Where-Object { $_.SerialNumber -eq "0000_0000_0100_0000_E4D2_5CDE_338F_5101." } | Get-Partition | Select-Object DriveLetter | foreach { $_.DriveLetter } | Where-Object { $_ }

# Get-WmiObject Win32_DiskDrive | Where-Object {$_.SerialNumber -eq "F93211052700202"} | Select-Object DeviceID
