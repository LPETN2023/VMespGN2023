# Historique des versions

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
