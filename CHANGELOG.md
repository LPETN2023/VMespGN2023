# Historique des versions

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
