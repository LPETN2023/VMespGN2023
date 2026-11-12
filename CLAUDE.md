# CLAUDE.md — ESP (VMespGN2023)

Fichier de reprise pour Claude. À tenir à jour à chaque livraison.
**Dépôt PUBLIC** : jamais de clé de produit ni de secret.

## Projet
Environnement de travail OSINT déployé sur des VM Windows 11 (VirtualBox). Dépôt cloné sur chaque VM
dans `%USERPROFILE%\Desktop\ESP`. Distribution : `Lancement_installation.bat` (installe Git, clone,
lance l'installation) ; mises à jour par « Mise à jour du système.bat ».
Mainteneur francophone, non développeur : réponses en français, claires, sans jargon.
Exigences : simple et peu sujet aux bugs ; questions seulement au début ; une VM en retard rattrape
toutes les versions intermédiaires ; outils gratuits.

## Architecture (v2, version actuelle dans `VERSION`)
- Moteur unique `Fichiers_techniques/ESP.ps1` (Windows PowerShell 5.1), modes `Installation`,
  `MiseAJour`, `Reprise` (tâche planifiée après redémarrage, 2 redémarrages max).
- **Listes** `Fichiers_techniques/config/*.txt` réappliquées à chaque exécution ; **migrations**
  `migrations/NNNN_*.ps1` exécutées une fois par VM (numéro mémorisé dans `C:\ProgramData\ESP\etat.json`).
- Ordre : élévation → (MiseAJour : `git fetch` + `reset --hard origin/main`, relance) → questions
  (mot de passe Linux chiffré DPAPI ; O/N mise à jour Ubuntu) → fenêtre « Plus rien à faire » →
  activation Windows (sauf Reprise) → paramètres → logiciels winget (`--source` explicite ; msstore pour
  les ID de 12 caractères) + installateurs spéciaux dot-sourcés → dossier « Logiciels » (rangement des
  doublons du Bureau) → WSL + VirtualMachinePlatform (redémarrage) → Ubuntu-24.04 en WSL 1 + compte →
  migrations → outils Linux (apt, pipx dans /opt/pipx, Telepathy_VM) → (MiseAJour : winget upgrade --all,
  Terminal/AppInstaller mis à jour en différé) → résumé + fenêtre « Terminé ».
- Installateurs spéciaux : `installateurs/TorBrowser.ps1`, `HTTrack.ps1`, `SplitCam.ps1` (téléchargement
  officiel + **vérification de signature Authenticode**). Contrat : `return` si déjà présent, `throw` en cas d'erreur.
- `linux/esp_linux.sh` : actions `utilisateur <nom>`, `outils`, `maj` (exécuté en root via `wsl -u root`).
- Microsoft Office : **retiré** en 2.4.8 (code supprimé).

## Règles impératives
1. `.ps1` : UTF-8 **avec BOM** + CRLF. `.bat` : ASCII sans accents, CRLF. `.sh` : LF. `config/*.txt` : UTF-8.
   Dans le dépôt Git les fichiers sont stockés en LF ; Windows (autocrlf) les extrait en CRLF.
   Depuis un shell Linux, utiliser `git -c core.autocrlf=true …` sinon tout apparaît modifié.
   **Ne jamais ajouter de `.gitattributes`** (risque de réécriture de « Mise à jour du système.bat » pendant son exécution).
2. **Ne jamais modifier** `Mise à jour du système.bat`. Ne jamais renommer/supprimer les fichiers v1 :
   `Installation de logiciels.bat`, `Update.bat`, `Initialisation_globale.bat`, `Installation_logiciels.ps1`,
   `Installation_Apps_WSL.sh`.
3. Ne jamais modifier une migration publiée (en créer une nouvelle, idempotente). Ne jamais retirer une
   ligne de `logiciels_a_desinstaller.txt`.
4. `Fichiers_techniques/activation/activation_windows.ps1` appartient au mainteneur : **ne jamais le modifier,
   le livrer ni l'écraser**.
5. Chaque livraison : augmenter `VERSION`, ajouter `## x.y.z` en tête de `CHANGELOG.md`, mettre à jour
   `MAINTENANCE.md` et la documentation si le comportement visible change.
6. Vérifier avant livraison : `python3 .github/verifier.py <commit_précédent>` (BOM, ASCII, fichiers protégés,
   migrations, désinstallations, CHANGELOG, clés) et analyse syntaxique PowerShell (pwsh
   `[Parser]::ParseFile`) ; GitHub Actions refait ces contrôles à chaque push (`.github/workflows/verifications.yml`).
7. Livraison : le mainteneur préfère un zip à décompresser par-dessus son dossier GitHub (sans
   `activation_windows.ps1`), puis il pousse et teste sur une VM.

## Documentation
`Documentation/` : `Tutoriel_utilisateur_ESP_v<version>.pdf`, `Guide_mainteneur_ESP_v<version>.pdf` et leurs
sources `Documentation/sources/*.html` + `style.css` + `images/`. Génération :
`google-chrome --headless=new --no-pdf-header-footer --print-to-pdf=<sortie.pdf> file://<source.html>`
(police Carlito/Calibri, numéros de page par `@page`). `Site/` = « Système d'accompagnement utilisateur »
(ancien site généré, pages par outil).

## Points ouverts (au 12/11/2026)
- 2.4.7/2.4.8 à valider sur VM : disparition des raccourcis HTTrack et LibreOffice du Bureau, fenêtres
  « Plus rien à faire » et « Terminé ».
- Arrêt inexpliqué une fois pendant Notepad++ (10/11) ; relance réussie.
- Discord se réinscrit au démarrage (retiré à chaque mise à jour, sans gravité).
