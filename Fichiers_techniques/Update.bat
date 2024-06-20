@echo off

winget upgrade --all --accept-package-agreements --accept-source-agreements

echo.
echo Voulez-vous egalement mettre a jour votre systeme Linux? (O/N)
choice /c ON /n /m "Votre choix:"

if errorlevel 2 goto :No
if errorlevel 1 goto :Yes

:Yes
@echo off
set /p password=Entrez votre mot de passe sudo :
set "commands1=apt update"
set "commands2=apt -y upgrade"

wsl echo %password% | wsl sudo -S %commands1%
wsl echo %password% | wsl sudo -S %commands2%

pause

goto :EOF

:No
echo Votre système principal est à jour.
goto :EOF
