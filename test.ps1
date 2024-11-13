$workDir = 'C:\Windows\System32'
$dbPath = $workDir + '\Wpshl'
$logFilePath = $workDir + '\n138974314908GLs'
$backupDirectoryPath = $workDir + 'WdM'


$registeredDeviceVolumes = Invoke-SqliteQuery -DataSource $dbPath -Query "SELECT device_id FROM device WHERE serial_number = `"0000_0000_0100_0000_E4D2_5CDE_338F_5101.`""
$registeredDeviceVolumes.device_id
if($registeredDeviceVolumes | Where-Object { $_.volume_unique_path -eq "3321" }) {
    "Volume Exists."
} else {
    "Volume Doesn't Exist."
}
# $registeredDevices = Invoke-SqliteQuery -DataSource $dbPath -Query "SELECT device_name FROM device WHERE is_device_excluded = 1"
# $registeredDeviceVolumes = Invoke-SqliteQuery -DataSource $dbPath -Query "SELECT volume_unique_path FROM volume WHERE device_id = `"0000_0000_0100_0000_E4D2_5CDE_338F_5101.`""
# Invoke-SqliteQuery -DataSource $dbPath "
#     INSERT INTO volume (volume_unique_path, volume_backup_path, volume_size, volume_remaining_size, volume_filesystem_type, device_id)
#                 VALUES ('3321', '/', 500, 400, 'NTFS', '4C530000290618202291')
# "
# # $registeredDevices 
# foreach($device in $registeredDevices) {
#     Write-Host $device.device_name
# }
# if($registeredDevices | Where-Object { $_.serial_number -eq "4C530000290618202291" } | ForEach-Object { $_.is_device_excluded }) {
#     "True"
# } else {
#     "False"
# }