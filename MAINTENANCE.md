# ESP – Guide du mainteneur

## Le principe en une phrase

À chaque **installation** comme à chaque **mise à jour**, `Fichiers_techniques/ESP.ps1` récupère le dépôt GitHub puis amène la VM à l'état décrit dans le dépôt :

1. il **applique les listes** de `Fichiers_techniques/config/` : ce qui manque est installé, ce qui est en trop est retiré, ce qui est déjà là est ignoré ;
2. il **exécute les migrations** de `Fichiers_techniques/migrations/` qui n'ont pas encore tourné sur cette VM, dans l'ordre de leur numéro.

Une VM restée plusieurs versions en arrière rattrape donc tout en une seule mise à jour.

## Ce que vous aurez à faire

| Je veux… | Je fais… |
|---|---|
| Ajouter un logiciel Windows | Ajouter son ID dans `config/logiciels_windows.txt` (`winget search <nom>` pour le trouver), et une ligne dans `config/raccourcis_logiciels.txt` pour qu'il apparaisse dans le dossier « Logiciels » du Bureau |
| Installer un logiciel que winget gère mal | Écrire `installateurs/Nom.ps1` (modèle : `TorBrowser.ps1`) et mettre `script:Nom` dans `logiciels_windows.txt` |
| Retirer un logiciel Windows | Supprimer sa ligne de `logiciels_windows.txt` **et** l'ajouter dans `config/logiciels_a_desinstaller.txt` |
| Ajouter un paquet Ubuntu | Une ligne dans `config/paquets_apt.txt` |
| Ajouter un outil Python (OSINT…) | Le nom PyPI dans `config/outils_python.txt` |
| Empêcher un programme de démarrer avec Windows | Une ligne dans `config/demarrage_a_retirer.txt` |
| Faire un changement ponctuel (réglage, nettoyage, déplacement de fichier…) | Créer une **migration** (voir plus bas) |

Après chaque modification : augmentez `VERSION`, ajoutez une ligne dans `CHANGELOG.md`, puis faites un commit et un push. Les utilisateurs l'obtiendront à leur prochaine mise à jour.

## Écrire une migration

- Fichier : `Fichiers_techniques/migrations/NNNN_description.ps1`, avec un numéro **supérieur** au dernier existant (0002, 0003…).
- Elle s'exécute **une seule fois** par VM. Une installation neuve exécute toutes les migrations : écrivez-les pour qu'elles soient sans effet si le travail est déjà fait (par exemple « supprimer si présent »).
- En cas d'erreur, faites `throw "message"`. La migration sera retentée à la prochaine mise à jour, et les suivantes attendront.
- **Ne modifiez jamais une migration déjà publiée** : créez-en une nouvelle.
- **Ne retirez jamais une ligne de `logiciels_a_desinstaller.txt`** : une VM en retard de plusieurs versions en a encore besoin.
- Fonctions disponibles :
  - `Invoke-Linux 'commande bash'` exécute du bash en root dans Ubuntu et renvoie le code de retour ;
  - `Write-Info`, `Write-Ok`, `Write-Alerte` pour afficher des messages ;
  - `$script:RedemarrageDemande = $true` redémarre la VM après la migration ; l'exécution reprend toute seule.

Exemple – `0002_supprimer_ancien_dossier.ps1` :

```powershell
Remove-Item "$env:USERPROFILE\Desktop\AncienDossier" -Recurse -Force -ErrorAction SilentlyContinue
$code = Invoke-Linux 'rm -rf /home/*/sherlock'
if ($code -ne 0) { throw "nettoyage Linux en échec" }
```

## Où regarder en cas de problème (sur la VM)

- Journaux : `C:\ProgramData\ESP\journaux\` (les 20 derniers).
- État de la VM : `C:\ProgramData\ESP\etat.json` (version installée, dernière migration appliquée, nom de la distribution Linux).
- Pour rejouer toutes les migrations sur une VM : passer `derniere_migration` à `0` dans `etat.json`.

## Fichiers à NE PAS renommer ni supprimer (compatibilité version 1)

Les VM installées en 2023 utilisent encore ces chemins :

| Fichier | Pourquoi |
|---|---|
| `Mise à jour du système.bat` (racine) | **Ne pas le modifier non plus.** Il est en cours d'exécution pendant son propre `git pull` ; le changer peut casser la mise à jour. Il appelle `Update.bat`. |
| `Installation de logiciels.bat` (racine) | Raccourci utilisateur, appelle `Installation_logiciels.ps1`. |
| `Fichiers_techniques/Update.bat` | Relais vers `ESP.ps1 -Mode MiseAJour`. |
| `Fichiers_techniques/Initialisation_globale.bat` | Relais pour les anciennes copies de `Lancement_installation.bat`. |
| `Fichiers_techniques/Installation_logiciels.ps1` | Appelé par le `.bat` ci-dessus. |
| `Fichiers_techniques/Installation_Apps_WSL.sh` | Plus utilisé. Il a pu être modifié localement par l'ancien `sed -i` ; le supprimer pourrait bloquer le `git pull` des anciennes VM. |

Fichiers de la version 1 qui peuvent être supprimés : `Fichiers_techniques/Installation_WSL.bat` et `Fichiers_techniques/Texte_WSL.txt`.

## Règles techniques

- Les `.ps1` doivent être enregistrés en **UTF-8 avec BOM**. Sans BOM, Windows PowerShell 5.1 affiche mal les accents. Dans Notepad++ : *Encodage › UTF-8-BOM*.
- Pas d'accents dans les `.bat`.
- Les fins de ligne des `.sh` n'ont plus d'importance : `ESP.ps1` les convertit avant de les exécuter.
- Le dépôt est cloné dans `%USERPROFILE%\Desktop\ESP`. Si le Bureau est redirigé par OneDrive, un raccourci `ESP` est créé sur le vrai Bureau.
