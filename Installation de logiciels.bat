@echo off
set "powershellScriptPath=%USERPROFILE%\Desktop\ESP\Fichiers_techniques\Installation_logiciels.ps1"
powershell -Command "& {Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%powershellScriptPath%""' -Verb RunAs}"
