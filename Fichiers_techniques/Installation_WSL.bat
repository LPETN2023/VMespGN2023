@echo off
type %USERPROFILE%\Desktop\ESP\Fichiers_techniques\Texte_WSL.txt | clip
wsl --set-default-version 1
wsl --install Ubuntu
ubuntu