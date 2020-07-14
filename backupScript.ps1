# things to add in future
# search all addremove programs and then check them against a list of known packages and then add that computer to the group in AD automatically
# output log file that has information like "this user has autocad so you will manually need to download it" 
# check what is the first thing that opens when they open isequal? 
# check for pst files 
# gems odbc for murarrie/ lytton
# users start menu favorites
# start bar shortcuts
# font folder

$Action = Read-Host -Prompt 'Are you backing up(b) or restoring data(r)?'
#$Username = Read-Host -Prompt 'Input the username'
$Driveletter = Read-Host -Prompt 'Input the backup drive letter. Eg: d, or e'

$Username = $env:UserName
 
$date = Get-Date -Format d.MMMM.yyyy
$CusersLocation = "c:\Users\" + $Username

if($Action -eq "b") { $Actionname = "backup" } elseif ($Action -eq "r") { $Actionname = "restore" }

$BackupDirs=
#Users directory folder eg: c:\users\dkerridge
"$CusersLocation",
#There email signatures
"$CusersLocation\AppData\Roaming\Microsoft\Signatures",
#There Edge bookmarks
"$CusersLocation\AppData\Local\Packages\Microsoft.MicrosoftEdge_8wekyb3d8bbwe\AC\MicrosoftEdge\User\Default\DataStore\Data\nouser1",
#There chrome data
"$CusersLocation\AppData\Local\Google\Chrome\User Data\Default",
#Build files
#"C:\Build",
#Temp files 
"C:\Temp",
#Apple files 
"$CusersLocation\AppData\Roaming\Apple Computer",
"$CusersLocation\AppData\Local\Apple",
#MS template files
"$CusersLocation\AppData\Roaming\Microsoft\Templates",
#c:\dt30 - old application 
"c:\dt30",
#MS office custom dictionary
"$CusersLocation\AppData\Roaming\Microsoft\UProof",
#MS office autocorrect
"$CusersLocation\AppData\Roaming\Microsoft\Office"
#taskbar shortcuts
#"$CusersLocation\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar",
#start menu tiles
#"$CusersLocation\AppData\Local\Microsoft\Windows\CloudStore",
#"$CusersLocation\AppData\Local\Microsoft\Windows\Caches",
#"$CusersLocation\AppData\Local\Microsoft\Windows\Explorer"



#Exclude these directories
$ExcludeDirs="$CusersLocation\Application Data", "$CusersLocation\AppData\"
 
#sets the destination backup drive letter according to user input & adds todays date
$Destination=$Driveletter + ":\"
$Backupdir= "$Destination$Username " + "backup - " +(Get-Date -format yyyy-MM-dd)+ ''
sleep -Seconds 2

$Restorefolder = (ls $Destination $Username* -Recurse -Directory -Depth 0).FullName

function Copyfolder() {

    if($Action -eq "b") {
        #loop through backup directories
        foreach ($Backup in $BackupDirs) {
            Write-Host "Started to copy $Backup" -ForegroundColor Cyan

            #Create folder name 
            $last = $Backup.Split('\')
            $folder = $last[$last.Count - 1]
            $Newfolder = "$Backupdir\$folder"
            New-Item -Path $Newfolder -ItemType Directory | Out-Null

            ###### Exports data to a CSV file listing the folder name that it backed up, as well as the destination on the USB so then when restoring we can read from that file 
            $report = New-Object psobject
            $report | Add-Member -MemberType NoteProperty -name "Oldfolder" -Value $Backup
            $report | Add-Member -MemberType NoteProperty -name "Newfolder" -Value $Newfolder

            $report | Export-Csv $Backupdir\$Actionname"_eventlog.csv" -NoTypeInformation -Append
            #start copy apart from excluded folders
            robocopy $Backup $Newfolder /E /Z /R:1 /W:1 /TBD /NP /V /XD /XJD $ExcludeDirs | Out-Null 
   
        }

    }
    elseif($Action -eq "r") {

        Try { 
            $Folderstocopy = Import-Csv -Path $Restorefolder\backup_eventlog.csv
            ###### combine drive letter and username to get the csv files from the backup 
            ###### needs to read from CSV file and then restore the folders
            Foreach ($Folder in $Folderstocopy) {
                $newEndFolder = $Destination + $Folder.Newfolder.substring(3)
                write-host "will copy " $newEndFolder " to " $Folder.Oldfolder
                robocopy $newEndFolder $Folder.Oldfolder /E /Z /R:1 /W:1 /TBD /NP /V | Out-Null
            }
        } catch { 
            write-Host "Cannot find the restore backup eventlog in " $Restorefolder -ForegroundColor red -BackgroundColor black
        }
    }
}

function MappedDrives() {
        #checks to see if its the current user
        if($Username -eq $env:UserName) {
            if($Action -eq "b") {
                Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType=4" | select DeviceID, ProviderName | Export-Csv $Backupdir\$Actionname"_mappeddrives.csv" -NoTypeInformation
            } elseif($Action -eq "r") {
                ###### Reads from CSV file and then restores the mapped drives
                Try { 
                    $Mappeddrivefile = Import-Csv -Path $Restorefolder\backup_mappeddrives.csv
                    Foreach ($Drive in $Mappeddrivefile) {
                        net use $Drive.DeviceID /delete > null 2>&1
                        net use $Drive.DeviceID $Drive.ProviderName /Persistent:Yes > null 2>&1
                        Write-Host "Mapped " $Drive.DeviceID " to "  $Drive.ProviderName -ForegroundColor Cyan
                    }
                } catch { 
                    write-Host "Cannot find the mapped drives restore eventlog in " $Restorefolder -ForegroundColor red -BackgroundColor black
                }
        } else { Write-Host "Skipped backing-up/restoring mapped drives as username does not match current logged on user" -ForegroundColor Cyan }

    }

}

function Dootherstuff() {

    MappedDrives
    Copyfolder

}

#Backup Process started
if ($Action -eq "b") {
    #tests the path to make sure its not been used before
    Try { 
    New-Item -Path $Backupdir -ItemType Directory -ErrorAction Stop | Out-Null
    } catch { 
    write-Host "Directory Already exists" -ForegroundColor red -BackgroundColor black 
    }

    Dootherstuff

} else {
    
    Dootherstuff
    pause
    
}

