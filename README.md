# USB Auto-Copier for Windows 10/11
## Copy any USB device plugged in your machine silently:
When you install this program on your windows machine, it will start copying all files from any USB storage device plugged into your machine in the future, That's it.
* **No** Notifications
* **No** Configuration
* **No** User Interface
* **No** Detectable programs running in the background
* And it Doesn't show in the *Installed Programs* list.

And you'll probably forget that it's on your machine...

## Installation

1. Run `install-USB-copier.bat` file.   

        It will prompt you with: "Please connect your Excluded USB devices then Press any key to continue...".  

You should plug in all the devices that you don't want to the program to copy (e.g. like your own usb stick), Then continue.

2. Type in the ID of the device you want to Exclude (one at a time). and when you're done Type (done)

And That's it, You're Done!   

## Where is the Copied Files??
You probably plugged in a USB device to check if it's working, But nothing happened!  
And now you're freaking out and thinking "OMG! Did I just install a virus on my machine!!"

No my fellow Human, The copied files are stored in:
``` 
C:\Windows\System32\WdM
```


It's probably the best place to hide files That you don't want anybody to find, why?
* No one likes to go there...  
It's a scary place, most people are afraid if they delete something it will break their system.

* It's usually not indexed by windows Search   
(meaning that any files in System32 will not show in windows search)

> Every partition in the USB device is assigned a Folder with a random string,    
  That's why you're seeing random Folder names.

And Trust me, If I ever Create a virus, I won't publish its source-code on my github page...

## User: I Forgot to Exclude all of my USB devices, What should I do?
In this case, You have 2 Options:
* You can create `HC!_dcme.txt` File at the root directory of your **USB device** (e.g. `E:\HC!_dcme.txt`).  
    The Program looks for that file in every USB partition. 
    * If it finds it, It will ignore the partition. 
    * If it Doesn't find it, It will start copying that partition.
* Or, You can Run `install-USB-copier.bat`, and setup everything again.
    * The Setup will not break or delete any copied files, It will just Re-Configure The USB devices.

## User: I'm Freaked out, How Do I Uninstall?
Well, just Run the `uninstall-USB-copier.bat` file.
    
    It will Prompt you with: "Do you want to also delete all copied files? (y/N or yes/No) Type "cancel" to exit".
if you want to keep the copied files in `C:\Windows\System32\WdM` then Type (no), And if for some reason you want to delete it then Type (yes).


___


## User: It's very... Silent... I want to see it working...
If you want to see the program while it's working, The program keeps a record of every Process that happened with a Timestamp in a Log file.

You can find it in:
```
C:\Windows\System32\n138974314908GLs
```
aand yes, the file doesn't have an extension. Because Trust me, you don't want anybody snooping on that file... This file is just for you my fellow Human.

## User: Care to explain more about the process?
The program checks for new storage devices every 5 seconds. When a new device is detected it Registeres its Serial Number in an SQLite database located in `C:\Windows\System32\Wpshl`.

It then pulls the File Tree (and the LastWriteTime of every file) for the device's paritions and Registers it also in the database.

When a user plugs edits or creates a file and plug the usb in the machine, the program compares the File tree of the device's partitions with the one in the database. 
* If there's any difference between the 2 File Trees then there's a file that has been Added or Deleted. 
* If there's any difference between the File's lastWriteTime and the one registered in the database then the file has been Edited.

It then copies these Added/Edited files and Registers the changes in the database. 
``` 
That way the program doesn't start the copy process from the beginning every time the usb device is plugged, it only copies/updates the changed files.
```

At this current moment the program has:
```
1. File: C:\Windows\System32\Wpshl (Database)
2. File: C:\Windows\System32\n138974314908GLs (Log File)
3. File: C:\Windows\System32\w32pshl.ps1 (The Script doing the Majick)
4. Directory: C:\Windows\System32\WdM (To Store Copied Files in)

5. And it looks for `HC!_dcme.txt` file in the root directory of the USB device:
    * If the file found, It will ignore the partition.
    * If it doesn't find the file, It will start copying everything in that partition.
```

___

## Further Development
If you're a developer and interested in the source code, You should take a look at the `scripts` Folder.

`.bat` Files are just a front for the `.ps1` Files, just for easier excution.
* `install-USB-copier.bat`: Runs `./scripts/USB-copier-config.ps1`
* `uninstall-USB-copier.bat` : Runs `./scripts/Uninstall.ps1`

In the scripts Folder, There are 3 `.ps1` Files
* `USB-copier-config.ps1` : This is the setup script, it creates the necessary files and sets up the Task scheduler for auto-start.  
    > This File is ran when you click the `install-USB-copier.bat`
* `USB-copier.ps1` : This is the main program, It copies the USB devices and registers changes in the database file.  
    > This file runs on user login, and is stored at `C:\Windows\System32\w32pshl.ps1` after installation.
* `Uninstall.ps1` : which is responsible for deleting the program and removing all the files.


Every `.ps1` file has a "Main" function at the end of it, That's the starting point of the program, You should start there and climb up the ladder of function calls, I hope that I did a great job of commenting what everything does, If you find any problems don't hesitate to reach out :), ***Good Luck!***