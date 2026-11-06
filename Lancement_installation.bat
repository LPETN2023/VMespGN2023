@echo off
setlocal
rem ==========================================================================
rem  Lancement_installation.bat
rem  A executer UNE fois par double-clic (PAS en "executer en tant qu'admin").
rem  Prerequis : winget installe (voir le tutoriel).
rem  Peut etre relance sans risque si l'installation a ete interrompue.
rem ==========================================================================
set "DEPOT=https://github.com/LPETN2023/VMespGN2023.git"
set "ESP=%USERPROFILE%\Desktop\ESP"

echo.
echo [1/3] Installation de Git...
where git >nul 2>&1
if not errorlevel 1 goto git_ok
winget install --id Git.Git -e -h --accept-package-agreements --accept-source-agreements
set "PATH=%PATH%;%ProgramFiles%\Git\cmd"
:git_ok
where git >nul 2>&1
if errorlevel 1 goto erreur_git

echo.
echo [2/3] Telechargement du projet...
if exist "%ESP%\.git" goto depot_existant
git clone "%DEPOT%" "%ESP%"
goto depot_ok
:depot_existant
git -C "%ESP%" fetch origin main
git -C "%ESP%" reset --hard origin/main
:depot_ok
if not exist "%ESP%\Fichiers_techniques\ESP.ps1" goto erreur_depot

echo.
echo [3/3] Lancement de l'installation.
echo       Acceptez la demande d'autorisation administrateur,
echo       puis choisissez le mot de passe Linux. C'est tout.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ESP%\Fichiers_techniques\ESP.ps1" -Mode Installation
exit /b 0

:erreur_git
echo.
echo Git est introuvable. Verifiez que winget fonctionne, puis relancez ce fichier.
pause
exit /b 1

:erreur_depot
echo.
echo Le projet n'a pas pu etre telecharge.
echo Verifiez la connexion Internet. Si un dossier ESP existe deja sur le Bureau
echo sans etre complet, supprimez-le puis relancez ce fichier.
pause
exit /b 1
