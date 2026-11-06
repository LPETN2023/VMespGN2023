@echo off
rem ==========================================================================
rem  COMPATIBILITE - ne pas renommer ni supprimer.
rem  Appele par les anciennes copies de Lancement_installation.bat (2023).
rem  Toute la logique d'installation est dans ESP.ps1.
rem ==========================================================================
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ESP.ps1" -Mode Installation
