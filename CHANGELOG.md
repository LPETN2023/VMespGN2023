# Historique des versions

## 2.4.7
- Correction : le raccourci « HTTrack Website Copier » restait sur le Bureau. Le mot « Website » faisait ignorer
  le raccourci du menu Démarrer de HTTrack. Le rangement du Bureau fonctionne maintenant quelle que soit la façon
  dont le logiciel a été trouvé (menu Démarrer, chemin direct ou application du Store).

## 2.4.6
- Toutes les questions (mot de passe Linux, mise à jour d'Ubuntu) sont posées en premier. Une fenêtre prévient
  ensuite l'utilisateur qu'il n'a plus rien à faire, et une autre l'avertit à la fin.
- La vérification de l'activation de Windows a lieu juste après les questions, et non plus avant.
- Microsoft Office n'est plus installé (trop long). Ligne désactivée dans `logiciels_windows.txt`, réactivable.
- Les raccourcis posés sur le Bureau par les installeurs (LibreOffice, HTTrack...) sont reconnus aussi par le
  programme qu'ils lancent, et rangés dans le dossier « Logiciels ».
- Correction : plus de message d'erreur sur la stratégie d'exécution PowerShell lors de la première installation.

## 2.4.5
- Correction (VM neuve) : Ubuntu ne s'installait pas après le premier redémarrage, car `wsl --install` exigeait
  en plus la fonctionnalité « Plateforme de machine virtuelle ». Elle est maintenant activée en même temps que WSL
  (un seul redémarrage). Si WSL demande malgré tout un redémarrage, le script redémarre et réessaie tout seul.
- Correction : la migration 0001 échouait sur une machine sans Linux ; elle ne fait plus rien côté Linux dans ce cas.
- Correction : fausse erreur « stratégie d'exécution remplacée » lors de la première installation.
- HTTrack est installé depuis httrack.com (le paquet winget est défectueux : erreur 0x8A150011) et passe à la
  dernière version. Il est épinglé dans winget pour que la mise à jour générale ne bute plus dessus.
- SplitCam est installé depuis splitcam.com (le paquet a été retiré de winget : erreur 0x8A150014).

## 2.4.4
- Correction : la mise à jour de Windows Terminal fermait la fenêtre du script et interrompait la mise à jour générale.
  Windows Terminal et App Installer (winget) sont désormais mis à jour en arrière-plan, après la fermeture de la fenêtre
  (journal `*_composants.log`).
- Les versions préliminaires de WSL (`Microsoft.WSL.PreRelease`) ne sont plus installées.

## 2.4.3
- Correction : la mise à jour générale des logiciels (`winget upgrade --all`) n'utilise plus que la source winget ; une boutique Microsoft injoignable ne la bloque plus. Un échec est désormais signalé dans le résumé.

## 2.4.2
- Correction : Microsoft Office est installé avec l'outil officiel de Microsoft (setup.exe téléchargé chez Microsoft, signature vérifiée) au lieu du paquet winget, dont l'empreinte n'était plus à jour (erreur 0x8A150011).

## 2.4.1
- Correction : la source winget (winget ou msstore) est désormais précisée pour chaque logiciel. Une boutique Microsoft injoignable ne bloque plus l'installation d'Office ni des autres logiciels.

## 2.4.0
- Installation de Microsoft Office (Microsoft 365 Apps, en français, 64 bits) via winget, avec la configuration `config/office.xml`.
- Raccourcis Word, Excel, PowerPoint, Outlook et OneNote dans le dossier « Logiciels ».

## 2.3.0
- La vérification de l'activation de Windows a aussi lieu au début de l'installation initiale.

## 2.2.0
- Mise à jour : vérification de l'activation de Windows en tout premier. Si Windows n'est pas activé
  définitivement (essai, évaluation, non activé), la commande de `Fichiers_techniques/activation/activation_windows.ps1` est exécutée.

## 2.1.0
- Correction : les migrations échouaient avec « Impossible d'appeler une méthode dans une expression Null ».
- Proton VPN : nouvel identifiant winget (`Proton.ProtonVPN`).
- Tor Browser : installé depuis torproject.org (`installateurs/TorBrowser.ps1`) au lieu de winget.
- Mise à jour : la mise à jour d'Ubuntu est proposée (O/N) au début.
- Raccourcis « Mise à jour du système » et « Installation de logiciels » sur le Bureau.
- Nouveau dossier « Logiciels » sur le Bureau (`config/raccourcis_logiciels.txt`).

## 2.0.0
- Nouveau moteur unique `Fichiers_techniques/ESP.ps1` pour l'installation et la mise à jour.
- Listes de logiciels et d'outils dans `Fichiers_techniques/config/` : appliquées à chaque mise à jour.
- Système de migrations (`Fichiers_techniques/migrations/`) pour les changements ponctuels.
- Une seule question pendant l'installation (mot de passe Linux), reprise automatique après redémarrage.
- Mise à jour d'Ubuntu sans mot de passe (exécution en root via WSL).
- Outils Python installés avec pipx (compatible Ubuntu 24.04).
- Skype retiré (service arrêté par Microsoft).
- Recherche de logiciels corrigée pour les noms contenant des espaces.
- Migration 0001 : nettoyage des éléments de la version 1.

## 1.x (2023)
- Version d'origine.
