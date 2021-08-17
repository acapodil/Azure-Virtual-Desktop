
Param(
  [string] $storageAccountName,
  [string] $ResourceGroupName,
  [string] $administratorAccountUsername,
  [string] $administratorAccountPassword,
  [string] $subscriptionID,
  [string] $installTeams
  )


#create directory for log file
New-Item -ItemType "directory" -Path C:\DeploymentLogs
sleep 5

#create Log File and error log file
New-Item C:\DeploymentLogs\log.txt
New-Item C:\DeploymentLogs\errorlog.txt
sleep 5

#create initial log
Add-Content C:\DeploymentLogs\log.txt "Starting Script. exit code is: $LASTEXITCODE"
sleep 5


#create share name
$shareName = $storageAccountName+'.file.core.windows.net'
$connectionString = '\\' + $storageAccountName + '.file.core.windows.net\userprofiles'

#Install Chocolatey
try{
    Add-Content C:\DeploymentLogs\log.txt "Installing chocolatey. exit code is: $LASTEXITCODE"
    sleep 5
    Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/apcapodilupo/WVD_2020/main/Scripts/install.ps1'))
}
catch{
     Add-Content C:\DeploymentLogs\log.txt "Error downloading chocolatey package manager.Check the error log. Retrying... exit code is: $LASTEXITCODE"
     sleep 5
     Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/apcapodilupo/WVD_2020/main/Scripts/install.ps1'))

}

#install fslogix apps
try{ 
    Add-Content C:\DeploymentLogs\log.txt "Installing FSLogix. exit code is: $LASTEXITCODE"
    choco install fslogix -yes --ignore-checksums
    sleep 5
}
catch{
    Add-Content C:\DeploymentLogs\log.txt "Error Installing FSLogix. Retrying... exit code is: $LASTEXITCODE"
    choco install fslogix -yes --ignore-checksums
    sleep 5


}

sleep 10

#configure fslogix profile containers

#create profiles key
New-Item 'HKLM:\Software\FSLogix\Profiles' -Force 
sleep 10

#create enabled value
New-ITEMPROPERTY 'HKLM:\Software\FSLogix\Profiles' -Name Enabled -Value 1
sleep 10


#removes any local profiles that are found
New-ITEMPROPERTY 'HKLM:\Software\FSLogix\Profiles' -Name DeleteLocalProfileWhenVHDShouldApply -Value 1
sleep 10

#flipflop username to front of profile name
New-ITEMPROPERTY 'HKLM:\Software\FSLogix\Profiles' -Name FlipFlopProfileDirectoryName -Value 1
sleep 10


#set  connection string
New-ITEMPROPERTY 'HKLM:\Software\FSLogix\Profiles' -Name VHDLocations -PropertyType String -Value $connectionString
sleep 10

#set to vhdx
New-ITEMPROPERTY 'HKLM:\Software\FSLogix\Profiles' -Name VolumeType -PropertyType String -Value "vhdx"

sleep 10


#Add Defender Exclusions for FSLogix
try{
    Add-Content C:\DeploymentLogs\log.txt "Setting Defender Exclusions for FSLogix. exit code is: $LASTEXITCODE"
    powershell -Command "Add-MpPreference -ExclusionPath 'C:\Program Files\FSLogix\Apps\frxdrv.sys’"
    powershell -Command "Add-MpPreference -ExclusionPath 'C:\Program Files\FSLogix\Apps\frxdrvvt.sys’"
    powershell -Command "Add-MpPreference -ExclusionPath 'C:\Program Files\FSLogix\Apps\frxccd.sys’"
    powershell -Command "Add-MpPreference -ExclusionExtension '%TEMP%\*.VHD’"
    powershell -Command "Add-MpPreference -ExclusionExtension '%TEMP%\*.VHDX’"
    powershell -Command "Add-MpPreference -ExclusionExtension '%Windir%\*.VHD’"
    powershell -Command "Add-MpPreference -ExclusionExtension '%Windir%\*.VHDX’"
    powershell -Command "Add-MpPreference -ExclusionExtension '\\gcrwvduserprofiles.file.core.windows.net\userprofiles\*\*.*.VHDX’"
    powershell -Command "Add-MpPreference -ExclusionExtension '\\gcrwvduserprofiles.file.core.windows.net\userprofiles\*\*.*.VHD’"
    powershell -Command "Add-MpPreference -ExclusionProcess '%Program Files%\FSLogix\Apps\frxccd.exe’"
    powershell -Command "Add-MpPreference -ExclusionProcess '%Program Files%\FSLogix\Apps\frxccds.exe’"
    powershell -Command "Add-MpPreference -ExclusionProcess '%Program Files%\FSLogix\Apps\frxsvc.exe’"

}
catch{
    Add-Content C:\DeploymentLogs\log.txt "Error setting defender exclusions. exit code is: $LASTEXITCODE"

}


if ($installTeams -eq 'Yes'){

    Add-Content C:\DeploymentLogs\log.txt "Installing Teams. exit code is: $LASTEXITCODE"


    #create Teams folder in C drive
    New-Item -Path "c:\" -Name "Install" -ItemType "directory"

    # Add registry Key
    reg add "HKLM\SOFTWARE\Microsoft\Teams" /v IsWVDEnvironment /t REG_DWORD /d 1 /f
    sleep 5

    #Download C++ Runtime
    try{
        Add-Content C:\DeploymentLogs\log.txt "Downloading C++ Runtime. exit code is: $LASTEXITCODE"
        invoke-WebRequest -Uri https://aka.ms/vs/16/release/vc_redist.x64.exe -OutFile "C:\Install\vc_redist.x64.exe"
        sleep 5
    }
    catch{
        Add-Content C:\DeploymentLogs\log.txt "Error. Check the error log. Retrying... exit code is: $LASTEXITCODE"
        invoke-WebRequest -Uri https://aka.ms/vs/16/release/vc_redist.x64.exe -OutFile "C:\Install\vc_redist.x64.exe"
        sleep 5
    }

    #Download RDCWEBRTCSvc
    try{
        Add-Content C:\DeploymentLogs\log.txt "Downloading WebRTC Redirector Service. exit code is: $LASTEXITCODE"
        invoke-WebRequest -Uri https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RE4AQBt -OutFile "C:\Install\MsRdcWebRTCSvc_HostSetup_1.0.2006.11001_x64.msi"
        sleep 5
    }
    catch{
        Add-Content C:\DeploymentLogs\log.txt "Error. Check the error log. Retrying... exit code is: $LASTEXITCODE"
        invoke-WebRequest -Uri https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RE4AQBt -OutFile "C:\Install\MsRdcWebRTCSvc_HostSetup_1.0.2006.11001_x64.msi"
        sleep 5
    }

    #Download Teams
    try{ 
        Add-Content C:\DeploymentLogs\log.txt "Downloading Teams Machine-Wide Installer. exit code is: $LASTEXITCODE"
        invoke-WebRequest -Uri https://statics.teams.cdn.office.net/production-windows-x64/1.3.00.13565/Teams_windows_x64.msi -OutFile "C:\Install\Teams_windows_x64.msi"
        sleep 5
    }
    catch{
        Add-Content C:\DeploymentLogs\log.txt "Error. Check the error log. Retrying... exit code is: $LASTEXITCODE"
        invoke-WebRequest -Uri https://statics.teams.cdn.office.net/production-windows-x64/1.3.00.13565/Teams_windows_x64.msi -OutFile "C:\Install\Teams_windows_x64.msi"
        sleep 5
    }

    #Install C++ runtime
    try{ 
        Add-Content C:\DeploymentLogs\log.txt "Installing C++ Runtime. exit code is: $LASTEXITCODE"
        Start-Process -FilePath C:\Install\vc_redist.x64.exe -ArgumentList '/q', '/norestart'
        sleep 5
    }
    catch{
        Add-Content C:\DeploymentLogs\log.txt "Error. Check the error log. Retrying... exit code is: $LASTEXITCODE"
        Start-Process -FilePath C:\Install\vc_redist.x64.exe -ArgumentList '/q', '/norestart'
        sleep 5
    }

    #Install Web Socket Redirector Service
    try{ 
        Add-Content C:\DeploymentLogs\log.txt "Installing Redirector Service. exit code is: $LASTEXITCODE"
        msiexec /i C:\Install\MsRdcWebRTCSvc_HostSetup_1.0.2006.11001_x64.msi /q /n
        sleep 5
    }
    catch{
        Add-Content C:\DeploymentLogs\log.txt "Error. Check the error log. Retrying... exit code is: $LASTEXITCODE"
        msiexec /i C:\Install\MsRdcWebRTCSvc_HostSetup_1.0.2006.11001_x64.msi /q /n
        sleep 5
    }

    # Install Teams
    try{
        Add-Content C:\DeploymentLogs\log.txt "Installing Teams. exit code is: $LASTEXITCODE"
        msiexec /i "C:\Install\Teams_windows_x64.msi" /l*v c:\Install\Teams.log ALLUSER=1 ALLUSERS=1 
        sleep 5
    }
    catch{
        Add-Content C:\DeploymentLogs\log.txt "Error. Check the error log. Retrying... exit code is: $LASTEXITCODE"
        msiexec /i "C:\Install\Teams_windows_x64.msi" /l*v c:\Install\Teams.log ALLUSER=1 ALLUSERS=1 
        sleep 5
    }
}

if($LASTEXITCODE -ne 0){

    Add-Content C:\DeploymentLogs\log.txt "Execution finished with non-zero exit code of: $LASTEXITCODE. Please check the error log."
    Add-Content C:\DeploymentLogs\errorlog.txt $Error
    exit 0
}

Add-Content C:\DeploymentLogs\log.txt "Execution complete. Final exit code is: $LASTEXITCODE"
Add-Content C:\DeploymentLogs\errorlog.txt $Error
exit 0


