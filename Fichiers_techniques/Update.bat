@echo off
rem ==========================================================================
rem  COMPATIBILITE - ne pas renommer ni supprimer.
rem  Appele par "Mise a jour du systeme.bat" (fichier d'origine, inchange).
rem  Toute la logique de mise a jour est dans ESP.ps1.
rem ==========================================================================
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ESP.ps1" -Mode MiseAJour
