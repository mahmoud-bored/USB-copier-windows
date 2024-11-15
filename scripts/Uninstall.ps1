function RemoveStoredFiles {
    Write-Host "Deleting Files..."
    Remove-Item 'C:\Windows\System32\WdM' -Recurse -Force -Confirm:$False
    Remove-Item "C:\Windows\System32\Wpshl" -Force -Confirm:$False
    Remove-Item "C:\Windows\System32\n138974314908GLs" -Force -Confirm:$False
}
function RemoveProgramFilesAndScheduler {
    schtasks /end /tn "w32pshl"
    schtasks /delete /tn "w32pshl" /f
    Remove-Item "C:\Windows\System32\w32pshl.ps1" -Force -Confirm:$False
}
function Main {
    
    $userInput = (Read-Host "Do you want to also delete all copied files? (y/N or yes/No) Type `"cancel`" to exit").ToLower()
    if (!$userInput -or ($userInput -eq 'n') -or ($userInput -eq 'no')) {
        
    } elseif (($userInput -eq 'y') -or ($userInput -eq 'yes')) {
        RemoveStoredFiles
    } elseif ($userInput -eq "cancel") {
        exit
    } else {
        Write-Host "Input Not Valid"
        Main
    }
    RemoveProgramFilesAndScheduler
} 
Main
# if /i "%choice%"=="" if "%choice%"=="n" if "%choice%"=="no"(
#     echo "You chose No (n)."
# ) else if /i "%choice%"=="yes" (
#     echo "You chose Yes (yes)."
# ) else if /i "%choice%"=="y" (
#     echo "You chose Yes (y)."
# ) else (
#     echo "Invalid input. Please enter y, n, yes, or no."
# )
