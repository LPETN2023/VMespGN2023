#!/usr/bin/env python3
# =============================================================================
#  Vérifications automatiques du dépôt ESP (lancées par GitHub à chaque push).
#  Reprend la liste de contrôle de MAINTENANCE.md.
#  Usage : python3 .github/verifier.py [commit_de_reference]
#    commit_de_reference : version précédente (pour vérifier les migrations
#    publiées et la liste des désinstallations). Absent : ces contrôles sont sautés.
# =============================================================================
import os, re, subprocess, sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(RACINE)
ERREURS, AVERTISSEMENTS = [], []

def erreur(msg): ERREURS.append(msg)
def avert(msg): AVERTISSEMENTS.append(msg)

def git(*args):
    return subprocess.run(['git', '-c', 'core.quotepath=off', *args], capture_output=True, text=True, encoding='utf-8')

def fichiers_suivis():
    r = git('ls-files')
    return [f for f in r.stdout.splitlines() if f and os.path.isfile(f)]

def lire(f): return open(f, 'rb').read()

TOUS = fichiers_suivis()
HORS_SITE = [f for f in TOUS if not f.startswith('Site/')]

# 1. Fichiers de compatibilité v1 : présents ; « Mise à jour du système.bat » inchangé
COMPAT = ['Mise à jour du système.bat', 'Installation de logiciels.bat', 'Lancement_installation.bat',
          'Fichiers_techniques/Update.bat', 'Fichiers_techniques/Initialisation_globale.bat',
          'Fichiers_techniques/Installation_logiciels.ps1', 'Fichiers_techniques/Installation_Apps_WSL.sh',
          'Fichiers_techniques/ESP.ps1']
for f in COMPAT:
    if f not in TOUS: erreur(f'Fichier de compatibilité supprimé ou renommé : {f}')
BLOB_MAJ = '09cdb090c8f80db74a1d2ec83b7898f6d4ce8f6f'
r = git('rev-parse', 'HEAD:Mise à jour du système.bat')
if r.returncode == 0 and r.stdout.strip() != BLOB_MAJ:
    erreur('« Mise à jour du système.bat » a été modifié : il ne doit JAMAIS changer.')

# 2. .ps1 : UTF-8 avec BOM, texte valide
for f in [f for f in TOUS if f.lower().endswith('.ps1')]:
    b = lire(f)
    if not b.startswith(b'\xef\xbb\xbf'):
        erreur(f'{f} : pas de BOM UTF-8 (les accents seront cassés sous PowerShell 5.1). Réenregistrer en « UTF-8-BOM ».')
    try: b.decode('utf-8')
    except UnicodeDecodeError: erreur(f'{f} : n\'est pas en UTF-8.')

# 3. .bat : ASCII uniquement (pas d'accents)
for f in [f for f in TOUS if f.lower().endswith('.bat')]:
    b = lire(f)
    bad = [i for i, c in enumerate(b) if c > 127]
    if bad:
        ligne = b[:bad[0]].count(b'\n') + 1
        erreur(f'{f} : caractère non ASCII (accent ?) ligne {ligne}.')

# 4. config/*.txt : UTF-8
for f in [f for f in TOUS if f.startswith('Fichiers_techniques/config/') and f.endswith('.txt')]:
    try: lire(f).decode('utf-8')
    except UnicodeDecodeError: erreur(f'{f} : n\'est pas en UTF-8.')

# 5. Lignes « script:Nom » : l'installateur existe
liste = 'Fichiers_techniques/config/logiciels_windows.txt'
if os.path.exists(liste):
    for n, l in enumerate(lire(liste).decode('utf-8-sig').splitlines(), 1):
        v = l.split('#', 1)[0].strip()
        if v.lower().startswith('script:'):
            nom = v.split(':', 1)[1].strip()
            if not os.path.exists(f'Fichiers_techniques/installateurs/{nom}.ps1'):
                erreur(f'{liste} ligne {n} : installateur introuvable installateurs/{nom}.ps1')

# 6. Migrations : numéros à 4 chiffres, uniques, sans trou
mig = sorted(os.path.basename(f) for f in TOUS if f.startswith('Fichiers_techniques/migrations/') and f.endswith('.ps1'))
nums = []
for m in mig:
    if not re.match(r'^\d{4}_[\w\-]+\.ps1$', m):
        erreur(f'Migration mal nommée : {m} (attendu NNNN_description.ps1)')
    else:
        nums.append(int(m[:4]))
if len(nums) != len(set(nums)): erreur('Deux migrations portent le même numéro.')
if nums and sorted(nums) != list(range(1, len(nums) + 1)):
    erreur(f'Numérotation des migrations incomplète : {sorted(nums)} (attendu 1, 2, 3…).')

# 7. VERSION et CHANGELOG
version = lire('VERSION').decode('utf-8-sig').strip() if os.path.exists('VERSION') else ''
if not re.match(r'^\d+\.\d+\.\d+$', version): erreur(f'VERSION invalide : « {version} »')
elif f'## {version}' not in lire('CHANGELOG.md').decode('utf-8-sig'):
    erreur(f'CHANGELOG.md ne contient pas d\'entrée « ## {version} ».')

# 8. Dépôt public : pas de clé de produit en clair
cle = re.compile(r'\b[A-Z0-9]{5}(?:-[A-Z0-9]{5}){4}\b')
for f in HORS_SITE:
    if f.endswith(('.png', '.jpg', '.mp4', '.ico', '.pdf', '.zip', '.exe')): continue
    try: txt = lire(f).decode('utf-8-sig')
    except UnicodeDecodeError: continue
    for n, l in enumerate(txt.splitlines(), 1):
        code = l.split('#', 1)[0] if f.endswith(('.ps1', '.txt', '.sh')) else l
        for m in cle.findall(code):
            if m != 'XXXXX-XXXXX-XXXXX-XXXXX-XXXXX':
                erreur(f'{f} ligne {n} : ressemble à une clé de produit (dépôt PUBLIC !).')

# 9. Comparaison avec la version précédente
ref = sys.argv[1] if len(sys.argv) > 1 else ''
if ref and not re.fullmatch(r'0+', ref) and git('cat-file', '-e', ref).returncode == 0:
    r = git('diff', '--name-status', '--no-renames', ref, 'HEAD', '--', 'Fichiers_techniques/migrations')
    for l in r.stdout.splitlines():
        st, f = l.split('\t', 1)
        if st != 'A': erreur(f'Migration publiée modifiée ou supprimée : {f} (créez-en une nouvelle à la place).')
    ancien = git('show', f'{ref}:Fichiers_techniques/config/logiciels_a_desinstaller.txt')
    if ancien.returncode == 0:
        nouveau = lire('Fichiers_techniques/config/logiciels_a_desinstaller.txt').decode('utf-8-sig')
        val = lambda t: {l.split('#', 1)[0].strip() for l in t.splitlines()} - {''}
        for manquant in sorted(val(ancien.stdout) - val(nouveau)):
            erreur(f'logiciels_a_desinstaller.txt : la ligne « {manquant} » a été retirée (interdit).')
    change = git('diff', '--name-only', ref, 'HEAD').stdout.split()
    if change and 'VERSION' not in change:
        avert('VERSION n\'a pas été augmentée depuis la version précédente.')
else:
    avert('Pas de version précédente fournie : contrôles des migrations et désinstallations sautés.')

for a in AVERTISSEMENTS: print(f'[ATTENTION] {a}')
for e in ERREURS: print(f'[ERREUR] {e}')
if ERREURS:
    print(f'\n{len(ERREURS)} erreur(s) : corrigez avant de laisser les VM se mettre à jour.')
    sys.exit(1)
print(f'\nTout est en ordre (version {version}).')
