#enable RDP shortpath Registry keys for UDP transport
REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations" /v ICEControl /t REG_DWORD  /d 2 /f

#Add Defender Exclusions for FSLogix

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


#installs Teams for AVD
#creates Directory for install
New-Item -Path "c:\" -Name "Install" -ItemType "directory"

#creates custom reg key
reg add "HKLM\SOFTWARE\Microsoft\Teams" /v IsWVDEnvironment /t REG_DWORD /d 1 /f

#downloads redist package
invoke-WebRequest -Uri https://aka.ms/vs/16/release/vc_redist.x64.exe -OutFile "C:\Install\vc_redist.x64.exe"

#downloads redirector service
invoke-WebRequest -Uri https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RE4AQBt -OutFile "C:\Install\MsRdcWebRTCSvc_HostSetup_1.0.2006.11001_x64.msi"

#downloads the teams machine-wide installer
invoke-WebRequest -Uri https://statics.teams.cdn.office.net/production-windows-x64/1.3.00.13565/Teams_windows_x64.msi -OutFile "C:\Install\Teams_windows_x64.msi"

#Run Installs
Start-Process -FilePath C:\Install\vc_redist.x64.exe -ArgumentList '/q', '/norestart'
sleep 10
msiexec /i C:\Install\MsRdcWebRTCSvc_HostSetup_1.0.2006.11001_x64.msi /q /n
sleep 10

msiexec /i "C:\Install\Teams_windows_x64.msi" /l*v c:\Install\Teams.log ALLUSER=1 ALLUSERS=1

exit 0
