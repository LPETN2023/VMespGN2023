@echo off
cd /d %USERPROFILE%\Desktop\ESP
git pull origin main
powershell.exe -Command "& {Start-Process '%USERPROFILE%\Desktop\ESP\Fichiers_techniques\Update.bat' -Verb RunAs}"