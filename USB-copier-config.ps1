function GetExcludedDevices {
    $global:excludedDevicesSerialNumbers = @()
    # Get & Exclude System Storage Device
    $systemDeviceSerialNumber = Get-Disk | Where-Object {$_.IsSystem -eq $True} | Select-Object SerialNumber | ForEach-Object { $_.SerialNumber }
    foreach($serialNumber in $systemDeviceSerialNumber) {
        $global:excludedDevicesSerialNumbers += $serialNumber
    }

    # Prompt User with Devices to Exclude
    Write-Host "----------------Setting Excluded Storage Devices----------------"
    Write-Host "Please connect your USB devices then Press any key to continue." -ForegroundColor Cyan
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

    # TODO: Add the ability to disconnect devices to add more than the available ports on a laptop
    Write-Host "Choose Your Excluded Devices ID (eg. 0, 1 or 2)"
    Write-Host "Type `"all`" to select All devices" -ForegroundColor Cyan
    Write-Host "Type `"reset`" to Reset your Selection" -ForegroundColor DarkYellow
    Write-Host "Type `"done`" if you're Done" -ForegroundColor Green
    Write-Host "Type `"exit`" to Cancel" -ForegroundColor Red

    for ($true) {
        $userInput = Read-Host "=>"
        # Exit Program
        if ($userInput -eq "exit") {
            exit
        # Reset Selection
        } elseif ($userInput -eq "reset") {
            $excludedDevicesIDs = @()
            Write-Host "Resetted"
            # End Loop
        } elseif ($userInput -eq "done") {
            break
        # Select All
        } elseif ($userInput -eq 'all') {
            $excludedDevicesIDs = $devicesList
            break
            # Check user input
        }
        else {
            # Check if user Input is valid
            if ($userInput -in $excludedDevicesIDs) {
                Write-Host "Error: Device Already Selected!"
            }
            elseif ($userInput -in $devicesList -and $userInput) {
                $excludedDevicesIDs += $userInput
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
    # TODO: Remove in Production
    Write-Host "Serial Numbers: ($global:excludedDevicesSerialNumbers)"
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
$dbTablesCreationQueries = @{
    device = "CREATE TABLE device (
        deviceID INTEGER PRIMARY KEY NOT NULL,
        serialNumber TEXT NOT NULL,
        lastFullBackup INTEGER NOT NULL DEFAULT 0,
        backupPath TEXT,
        isDeviceExcluded INTEGER NOT NULL DEFAULT 0,
        author TEXT
    )"
    directory = "CREATE TABLE directory (
        folderID INTEGER PRIMARY KEY NOT NULL,
        folderPath TEXT NOT NULL,
        folderName TEXT NOT NULL,
        parentFolder TEXT NOT NULL,
        deviceID INTEGER NOT NULL,
        FOREIGN KEY(deviceID) REFERENCES device(deviceID)
    )"
    file = "CREATE TABLE file (
        fileID INTEGER PRIMARY KEY NOT NULL,
        filePath TEXT NOT NULL,
        fileName TEXT NOT NULL,
        fileExtension TEXT NOT NULL,
        parentFolder TEXT NOT NULL,
        lastWriteTimeUtc INTEGER,
        lastBackupTimeUtc INTEGER DEFAULT 0,
        deviceID INTEGER NOT NULL,
        FOREIGN KEY(deviceID) REFERENCES device(deviceID)
        )"
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

    $global:dbPath = $workDir + '\Wpshl'
    # Create Database File
    if(!(Test-Path $global:dbPath -PathType Leaf)) {
        Write-Host "[INFO]: Database Doesn't Exist."
        Write-Host "[PROCESS]: Creating Database File..."
        try {
            New-Item $global:dbPath
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
    Write-Host "Checking Database Tables..."
    # Check & Create device Table
    if(Invoke-SqliteQuery -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='device';" -DataSource $global:dbPath) {
        Write-Host "[INFO]: Table `"device`" Exists!"
    } else {
        Write-Host "[INFO]: Table `"device`" Doesn't Exist."
        try {
            Write-Host "[PROCESS]: Creating `"device`" Table..."
            Invoke-SqliteQuery -Query $dbTablesCreationQueries['device'] -DataSource $global:dbPath
        }
        catch {
            Write-Host $_
            Write-Host "[ERROR]: Couldn't create `"device`" Table, Exiting..." -ForegroundColor Red
            Start-Sleep -Seconds 5
            exit
        }
        Write-Host '[NEW]: Table `"device`" was Created Successfully!' -ForegroundColor Green
    }
    # Check & Create directory Table
    if(Invoke-SqliteQuery -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='directory';" -DataSource $global:dbPath) {
        Write-Host "[INFO]: Table `"directory`" Exists!"
    } else {
        Write-Host "[INFO]: Table `"directory`" Doesn't Exist."
        try {
            Write-Host "[PROCESS]: Creating `"directory`" Table..."
            Invoke-SqliteQuery -Query $dbTablesCreationQueries['directory'] -DataSource $global:dbPath
        }
        catch {
            Write-Host $_
            Write-Host "[ERROR]: Couldn't create `"directory`" Table, Exiting..." -ForegroundColor Red
            Start-Sleep -Seconds 5
            exit
        }
        Write-Host '[NEW]: Table `"directory`" Created Successfully!' -ForegroundColor Green
    }
    # Check & Create file Table
    if(Invoke-SqliteQuery -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='file';" -DataSource $global:dbPath) {
        Write-Host "[INFO]: Table `"file`" Exists!"
    } else {
        Write-Host "[INFO]: Table `"file`" Doesn't Exist."
        try {
            Write-Host "[PROCESS]: Creating `"file`" Table..."
            Invoke-SqliteQuery -Query $dbTablesCreationQueries['file'] -DataSource $global:dbPath
        }
        catch {
            Write-Host $_
            Write-Host "[ERROR]: Couldn't create `"file`" Table, Exiting..." -ForegroundColor Red
            Start-Sleep -Seconds 5
            exit
        }
        Write-Host '[NEW]: Table `"file`" Created Successfully!' -ForegroundColor Green
    }
}

function SetExcludedDevicesInDb {
    Write-Host "Excluded Devices $global:excludedDevicesSerialNumbers"
    foreach($deviceSerialNumber in $global:excludedDevicesSerialNumbers) {
        $query = Invoke-SqliteQuery -DataSource 'C:\Windows\System32\Wpshl' -Query "SELECT deviceID FROM device WHERE serialNumber='$deviceSerialNumber'" 
        if($query.deviceID){
            Write-Host "[INFO]: Device Exists, Updating $deviceSerialNumber"
            Invoke-SqliteQuery -DataSource $global:dbPath "
                UPDATE device SET isDeviceExcluded = 1 WHERE deviceID = '$($query.deviceID)'
            "
        } else {
            Write-Host "[NEW]: Regestering new device"
            Invoke-SqliteQuery -DataSource $global:dbPath "
                INSERT INTO device (serialNumber, isDeviceExcluded)
                VALUES ('$deviceSerialNumber', 1)
            "
        }
    }
}
$workDir = 'C:\Windows\System32'
function Main {
    # Check for Adminstrator Access
    if(!(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
        Write-Host "[ERROR]: User Is Not An Administrator, Exiting..." -ForegroundColor Red
        Start-Sleep -Seconds 5
        exit
    }
    GetExcludedDevices
    CheckNecessaryModules
    CheckDbConfig
    SetExcludedDevicesInDb
}
Main

  