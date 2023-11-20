reg add HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce /v "Installation_WSL.bat" /t REG_SZ /d "%~dp0Installation_WSL.bat" /f
@echo off

rem Vérifier l'état de la fonctionnalité WSL
dism.exe /online /get-featureinfo /featurename:Microsoft-Windows-Subsystem-Linux | find "État : Activé" >nul

rem La variable d'environnement %errorlevel% contient le code de retour
if not %errorlevel% == 0 (
    echo La fonctionnalité WSL n'est pas activée. Activation en cours...
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
) else (
    echo La fonctionnalité WSL est déjà activée.
)
@echo off
Winget install 9P9TQF7MRM4R -h --accept-package-agreements --accept-source-agreements
Winget install 7zip.7zip -h --accept-package-agreements --accept-source-agreements
Winget install OBSProject.OBSStudio -h --accept-package-agreements --accept-source-agreements
Winget install GnuPG.Gpg4win -h --accept-package-agreements --accept-source-agreements
Winget install IDRIX.VeraCrypt -h --accept-package-agreements --accept-source-agreements
Winget install VideoLAN.VLC -h --accept-package-agreements --accept-source-agreements
Winget install WiresharkFoundation.Wireshark -h --accept-package-agreements --accept-source-agreements
Winget install XnSoft.XnViewMP -h --accept-package-agreements --accept-source-agreements
Winget install 9WZDNCRFJFCV -h --accept-package-agreements --accept-source-agreements
Winget install BinaryFortress.HashTools -h --accept-package-agreements --accept-source-agreements
Winget install OliverBetz.ExifTool -h --accept-package-agreements --accept-source-agreements
Winget install XavierRoche.HTTrack -h --accept-package-agreements --accept-source-agreements
Winget install TheDocumentFoundation.LibreOffice -h --accept-package-agreements --accept-source-agreements
Winget install Notepad++.Notepad++ -h --accept-package-agreements --accept-source-agreements
Winget install ProtonTechnologies.ProtonVPN -h --accept-package-agreements --accept-source-agreements
Winget install SplitCam.SplitCam -h --accept-package-agreements --accept-source-agreements
Winget install Mozilla.Firefox -h --accept-package-agreements --accept-source-agreements
Winget install Google.Chrome -h --accept-package-agreements --accept-source-agreements
Winget install Brave.Brave -h --accept-package-agreements --accept-source-agreements
Winget install TorProject.TorBrowser -h --accept-package-agreements --accept-source-agreements
Winget install Discord.Discord -h --accept-package-agreements --accept-source-agreements
Winget install WhatsApp.WhatsApp -h --accept-package-agreements --accept-source-agreements
Winget install OpenWhisperSystems.Signal -h --accept-package-agreements --accept-source-agreements
Winget install Telegram.TelegramDesktop -h --accept-package-agreements --accept-source-agreements
Winget install Microsoft.Skype -h --accept-package-agreements --accept-source-agreements
@echo off
setlocal
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "Discord" /f
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "OneDrive" /f
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "Skype for Desktop" /f
endlocal
@echo off
assoc .ps1=PowerShellScript
ftype PowerShellScript=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File "%1" %*
@echo off
setlocal
set "cible=%userprofile%\Desktop\ESP\Site\index.html"
set "nom_raccourci=Systeme d'accompagnement utilisateur"
set "emplacement=%userprofile%\Desktop"
echo Set objWS = WScript.CreateObject("WScript.Shell") > "%temp%\CreateShortcut.vbs"
echo strDesktop = objWS.SpecialFolders("Desktop") >> "%temp%\CreateShortcut.vbs"
echo Set objLink = objWS.CreateShortcut(strDesktop ^& "\%nom_raccourci%.lnk") >> "%temp%\CreateShortcut.vbs"
echo objLink.TargetPath = "%cible%" >> "%temp%\CreateShortcut.vbs"
echo objLink.Save >> "%temp%\CreateShortcut.vbs"
cscript //nologo "%temp%\CreateShortcut.vbs"
del "%temp%\CreateShortcut.vbs"
endlocal
@echo off
for /f %%A in ('powershell Get-ExecutionPolicy') do (
    if "%%A"=="Restricted" (
        echo
		echo La politique d'execution est Restreinte. Modification en cours... 
		echo Le systeme va ensuite redemarrer.
        powershell Set-ExecutionPolicy RemoteSigned
    ) else (
        echo
		echo La politique d'execution n'est pas Restreinte. Aucune modification necessaire. 
		echo Le système va redemarrer.
    )
)
shutdown /r /t 5
