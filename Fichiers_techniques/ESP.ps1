<#
================================================================================
 ESP.ps1 - Moteur unique d'installation ET de mise à jour de l'environnement ESP
================================================================================
 Modes :
   Installation : première installation (lancé par Lancement_installation.bat)
   MiseAJour    : mise à jour (lancé par "Mise à jour du système.bat" -> Update.bat)
   Reprise      : reprise automatique après redémarrage (tâche planifiée, interne)

 Principe : chaque exécution amène la machine à l'état décrit dans le dépôt.
   1. Les listes du dossier config\ sont appliquées à CHAQUE exécution :
      ce qui manque est installé, ce qui est déjà là est ignoré.
   2. Les scripts du dossier migrations\ (changements ponctuels) sont exécutés
      UNE SEULE FOIS chacun, dans l'ordre de leur numéro. Le numéro de la
      dernière migration appliquée est mémorisé dans C:\ProgramData\ESP\etat.json.

 Une installation neuve et une mise à jour suivent donc exactement le même
 chemin : une machine restée en version 1 rattrape tout en une seule fois.

 Mode d'emploi pour le mainteneur : voir MAINTENANCE.md à la racine du dépôt.
 Ce fichier doit rester enregistré en UTF-8 AVEC BOM (sinon les accents cassent
 sous Windows PowerShell 5.1).
#>
[CmdletBinding()]
param(
    [ValidateSet('Installation', 'MiseAJour', 'Reprise')]
    [string]$Mode = 'MiseAJour',

    # Interne : indique que le dépôt vient d'être synchronisé avec GitHub.
    [switch]$DepotSynchronise
)

$ErrorActionPreference = 'Continue'

# =============================================================== CONSTANTES
$Tech            = $PSScriptRoot                      # ...\ESP\Fichiers_techniques
$Racine          = Split-Path $Tech -Parent           # ...\ESP
$DossierConfig   = Join-Path $Tech 'config'
$DossierMigr     = Join-Path $Tech 'migrations'
$DossierLinux    = Join-Path $Tech 'linux'
$DossierEtat     = Join-Path $env:ProgramData 'ESP'
$DossierTmp      = Join-Path $DossierEtat 'tmp'
$DossierJournaux = Join-Path $DossierEtat 'journaux'
$FichierEtat     = Join-Path $DossierEtat 'etat.json'
$FichierSecret   = Join-Path $DossierEtat 'linux.secret'
$NomTache        = 'ESP - Reprise apres redemarrage'
$Branche         = 'main'
$DistroNouvelle  = 'Ubuntu-24.04'                     # distribution des nouvelles installations
$Utf8SansBom     = New-Object System.Text.UTF8Encoding $false

$script:Alertes  = New-Object System.Collections.Generic.List[string]
$script:Distro   = $null
$script:RedemarrageDemande = $false   # une migration peut le passer à $true

# =============================================================== AFFICHAGE
function Write-Etape([string]$Texte) {
    Write-Host ''
    Write-Host "=== $Texte ===" -ForegroundColor Cyan
}
function Write-Ok([string]$Texte)   { Write-Host "  [OK] $Texte" -ForegroundColor Green }
function Write-Info([string]$Texte) { Write-Host "  $Texte" }
function Write-Alerte([string]$Texte) {
    Write-Host "  [!] $Texte" -ForegroundColor Yellow
    $script:Alertes.Add($Texte) | Out-Null
}

# =============================================================== OUTILS
function Read-Liste([string]$Nom) {
    # Lit un fichier de config\ : une valeur par ligne, '#' = commentaire.
    $chemin = Join-Path $DossierConfig $Nom
    if (-not (Test-Path $chemin)) { return @() }
    @(Get-Content $chemin -Encoding UTF8 |
        ForEach-Object { ($_ -split '#')[0].Trim() } |
        Where-Object { $_ })
}

function Read-Etat {
    $etat = [ordered]@{
        derniere_migration = 0
        version            = ''
        reprise            = ''
        redemarrages       = 0
        distribution       = ''
        maj_ubuntu         = $false
    }
    if (Test-Path $FichierEtat) {
        try {
            $lu = Get-Content $FichierEtat -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($p in $lu.PSObject.Properties) { $etat[$p.Name] = $p.Value }
        } catch {
            Write-Alerte 'etat.json illisible : il sera recréé.'
        }
    }
    return [pscustomobject]$etat
}

function Save-Etat {
    $script:Etat | ConvertTo-Json | Set-Content -Path $FichierEtat -Encoding UTF8
}

function ConvertTo-TexteClair([Security.SecureString]$Secure) {
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

function New-Raccourci([string]$Lnk, [string]$Cible, [string]$Arguments = '') {
    $shell = New-Object -ComObject WScript.Shell
    $r = $shell.CreateShortcut($Lnk)
    $r.TargetPath = $Cible
    if ($Arguments) { $r.Arguments = $Arguments }
    else { $r.WorkingDirectory = Split-Path $Cible -Parent }
    $r.Save()
}

function Read-OuiNon([string]$Question) {
    while ($true) {
        $r = ("$(Read-Host "$Question (O/N)")").Trim().ToUpper()
        if ($r -eq 'O' -or $r -eq 'OUI') { return $true }
        if ($r -eq 'N' -or $r -eq 'NON') { return $false }
    }
}

# =============================================================== GIT
function Sync-Depot {
    # Aligne le dossier ESP sur GitHub. "reset --hard" plutôt que "pull" :
    # aucune modification locale ne peut bloquer la mise à jour.
    if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
        Write-Host '  [!] Git introuvable : le projet n''a pas été mis à jour.' -ForegroundColor Yellow
        return
    }
    & git.exe -c safe.directory=* -C $Racine fetch --quiet origin $Branche
    if ($LASTEXITCODE -ne 0) {
        Write-Host '  [!] GitHub injoignable : on continue avec la version locale.' -ForegroundColor Yellow
        return
    }
    & git.exe -c safe.directory=* -C $Racine reset --quiet --hard "origin/$Branche"
    if ($LASTEXITCODE -eq 0) { Write-Host '  [OK] Projet à jour.' -ForegroundColor Green }
}

function Set-GitConfiance {
    # Évite l'erreur "dubious ownership" si le dossier a été créé en admin.
    if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) { return }
    $chemin = $Racine -replace '\\', '/'
    $connus = @(& git.exe config --global --get-all safe.directory)
    if ($connus -notcontains $chemin) { & git.exe config --global --add safe.directory $chemin }
}

# =============================================================== WINDOWS
function Set-ParametresWindows {
    Write-Etape 'Paramètres Windows'

    try {
        $pol = Get-ExecutionPolicy -Scope LocalMachine
        if ($pol -eq 'Restricted' -or $pol -eq 'Undefined') {
            Set-ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -ErrorAction Stop
            Write-Ok 'Politique d''exécution PowerShell : RemoteSigned.'
        } else {
            Write-Ok "Politique d'exécution PowerShell : $pol."
        }
    } catch {
        Write-Info "Politique d'exécution non modifiée ($($_.Exception.Message))"
    }

    $cleRun = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    foreach ($nom in Read-Liste 'demarrage_a_retirer.txt') {
        if (Get-ItemProperty -Path $cleRun -Name $nom -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $cleRun -Name $nom -ErrorAction SilentlyContinue
            Write-Ok "Démarrage automatique retiré : $nom"
        }
    }

    # Raccourcis sur le VRAI Bureau (gère le cas OneDrive)
    $bureau = [Environment]::GetFolderPath('Desktop')
    $site = Join-Path $Racine 'Site\index.html'
    if (Test-Path $site) {
        New-Raccourci (Join-Path $bureau "Systeme d'accompagnement utilisateur.lnk") $site
    }
    if ((Split-Path $Racine -Parent) -ne $bureau) {
        # Le dossier ESP n'est pas visible sur le Bureau (Bureau redirigé par OneDrive)
        New-Raccourci (Join-Path $bureau 'ESP.lnk') $Racine
    }

    # Lanceurs de la solution (cherchés par motif : le nom exact peut varier)
    $lanceurs = @(
        @{ Motif = 'Mise*jour*.bat';              Nom = 'Mise à jour du système.lnk' },
        @{ Motif = 'Installation*logiciels*.bat'; Nom = 'Installation de logiciels.lnk' }
    )
    foreach ($l in $lanceurs) {
        $bat = Get-ChildItem -Path $Racine -Filter $l.Motif -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($bat) { New-Raccourci (Join-Path $bureau $l.Nom) $bat.FullName }
        else { Write-Alerte "Lanceur introuvable à la racine du dossier ESP : $($l.Motif)" }
    }
    Write-Ok 'Raccourcis du Bureau à jour.'
}

function Get-SourceWinget([string]$Id) {
    # Les identifiants du Microsoft Store sont des codes de 12 caractères (ex. 9NKSQGP7F2NH).
    # Préciser la source évite que winget s'arrête quand l'autre source est injoignable.
    if ($Id -cmatch '^[0-9A-Z]{12}$') { return 'msstore' }
    return 'winget'
}

function Test-WingetInstalle([string]$Id) {
    $null = & winget.exe list --id $Id -e --source (Get-SourceWinget $Id) --accept-source-agreements --disable-interactivity
    return ($LASTEXITCODE -eq 0)
}

function Update-LogicielsWindows {
    Write-Etape 'Logiciels Windows (winget)'
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        Write-Alerte 'winget est introuvable : installez-le (voir le tutoriel) puis relancez la mise à jour.'
        return
    }
    $options = @('-e', '-h', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')

    # Codes de retour winget considérés comme un succès :
    #   0 ; 3010/1641 = succès, redémarrage conseillé ;
    #   -1978335189 (0x8A15002B) = aucune mise à jour applicable ;
    #   -1978335135 (0x8A150061) / -1978334963 (0x8A15010D) = déjà installé.
    $succes = @(0, 3010, 1641, -1978335189, -1978335135, -1978334963)

    foreach ($id in Read-Liste 'logiciels_a_desinstaller.txt') {
        if (Test-WingetInstalle $id) {
            Write-Info "Désinstallation de $id..."
            & winget.exe uninstall --id $id -e -h --source (Get-SourceWinget $id) --accept-source-agreements --disable-interactivity | Out-Host
            if ($LASTEXITCODE -eq 0) { Write-Ok "$id désinstallé." }
            else { Write-Alerte "Désinstallation de $id impossible (code $LASTEXITCODE)." }
        }
    }

    foreach ($id in Read-Liste 'logiciels_windows.txt') {
        if ($id -like 'script:*') { Invoke-InstallateurSpecial $id.Substring(7).Trim(); continue }
        if (Test-WingetInstalle $id) { Write-Ok "$id déjà présent."; continue }
        Write-Info "Installation de $id..."
        & winget.exe install --id $id --source (Get-SourceWinget $id) @options | Out-Host
        if ($succes -contains $LASTEXITCODE) { Write-Ok "$id installé." }
        else { Write-Alerte ("Installation de {0} échouée (code 0x{1:X8})." -f $id, $LASTEXITCODE) }
    }
}

function Invoke-InstallateurSpecial([string]$Nom) {
    # Logiciels que winget installe mal : script dédié dans installateurs\<Nom>.ps1
    $fichier = Join-Path $Tech "installateurs\$Nom.ps1"
    if (-not (Test-Path $fichier)) { Write-Alerte "Installateur introuvable : installateurs\$Nom.ps1"; return }
    try {
        $ErrorActionPreference = 'Stop'
        . $fichier
    } catch {
        Write-Alerte "Installation de $Nom échouée : $($_.Exception.Message)"
    } finally {
        $ErrorActionPreference = 'Continue'
    }
}

function Update-DossierLogiciels {
    Write-Etape 'Dossier "Logiciels" du Bureau'
    $bureau  = [Environment]::GetFolderPath('Desktop')
    $public  = [Environment]::GetFolderPath('CommonDesktopDirectory')
    $dossier = Join-Path $bureau 'Logiciels'
    New-Item -ItemType Directory -Force -Path $dossier | Out-Null

    $menus = @("$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
               "$env:APPDATA\Microsoft\Windows\Start Menu\Programs")
    $exclus = 'uninstall|d[ée]sinstall|readme|lisez|website|site web|help|aide|manual|documentation|license|licence'
    $lnkMenu = @(Get-ChildItem -Path $menus -Recurse -Filter '*.lnk' -ErrorAction SilentlyContinue |
        Where-Object { $_.BaseName -notmatch $exclus })
    $applis = $null
    $faits = 0
    $absents = @()

    foreach ($ligne in Read-Liste 'raccourcis_logiciels.txt') {
        $morceaux = $ligne -split '=', 2
        $nom = $morceaux[0].Trim()
        $recherches = @($nom)
        if ($morceaux.Count -eq 2) { $recherches = @($morceaux[1] -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
        $lnk = Join-Path $dossier "$nom.lnk"
        $trouve = $false

        foreach ($r in $recherches) {
            if ($r -match '\\') {
                # Chemin direct vers un programme
                $cible = [Environment]::ExpandEnvironmentVariables($r)
                if (Test-Path $cible) { New-Raccourci $lnk $cible; $trouve = $true; break }
                continue
            }
            # Raccourci du menu Démarrer
            $m = $lnkMenu | Where-Object { $_.BaseName -like $r } | Sort-Object { $_.BaseName.Length } | Select-Object -First 1
            if ($m) {
                Copy-Item -Path $m.FullName -Destination $lnk -Force
                # Rangement : on retire le doublon déposé sur le Bureau par l'installeur
                Get-ChildItem -Path $bureau, $public -Filter '*.lnk' -ErrorAction SilentlyContinue |
                    Where-Object { $_.BaseName -like $r } | Remove-Item -Force -ErrorAction SilentlyContinue
                $trouve = $true; break
            }
            # Applications du Microsoft Store (WhatsApp...)
            if ($null -eq $applis) { $applis = @(Get-StartApps -ErrorAction SilentlyContinue) }
            $a = $applis | Where-Object { $_.Name -like $r } | Select-Object -First 1
            if ($a) { New-Raccourci $lnk "$env:WINDIR\explorer.exe" "shell:AppsFolder\$($a.AppID)"; $trouve = $true; break }
        }
        if ($trouve) { $faits++ } else { $absents += $nom }
    }
    Write-Ok "$faits raccourci(s) dans le dossier Logiciels."
    if ($absents.Count -gt 0) { Write-Info "Non trouvés (logiciel absent ou nom différent) : $($absents -join ', ')" }
}

# =============================================================== ACTIVATION
function Get-EtatActivationWindows {
    <#
      Lit l'état de la licence Windows (classe WMI SoftwareLicensingProduct).
      LicenseStatus : 0 non activé, 1 activé, 2 à 6 = périodes de grâce
      (essai des premiers jours, changement de matériel, notification...).
      "Définitif" = activé (1) et pas une édition d'évaluation limitée dans le temps.
    #>
    $idWindows = '55c92734-d682-4d71-983e-d6ec3f16059f'   # identifiant de Windows dans le service de licences
    $produits = @(Get-CimInstance -ClassName SoftwareLicensingProduct -ErrorAction Stop `
        -Filter "ApplicationID='$idWindows' AND PartialProductKey IS NOT NULL")
    if ($produits.Count -eq 0) {
        return [pscustomobject]@{ Definitif = $false; Statut = 'aucune clé de produit installée'; Detail = '' }
    }
    $p = $produits | Sort-Object { if ($_.LicenseStatus -eq 1) { 0 } else { 1 } } | Select-Object -First 1
    $libelles = @{
        0 = 'non activé'; 1 = 'activé'; 2 = 'période d''essai initiale'
        3 = 'période de grâce (changement de matériel)'; 4 = 'période de grâce (copie non authentique)'
        5 = 'non activé (notifications)'; 6 = 'période de grâce prolongée'
    }
    $statut = $libelles[[int]$p.LicenseStatus]
    if (-not $statut) { $statut = "état inconnu ($($p.LicenseStatus))" }
    $evaluation = ("$($p.Description)" -match 'TIMEBASED_EVAL')
    if ($evaluation) { $statut = 'version d''évaluation (limitée dans le temps)' }
    $detail = ''
    if ([int]$p.GracePeriodRemaining -gt 0) { $detail = "{0} jour(s) restant(s)" -f [math]::Floor($p.GracePeriodRemaining / 1440) }
    return [pscustomobject]@{
        Definitif = ([int]$p.LicenseStatus -eq 1 -and -not $evaluation)
        Statut    = $statut
        Detail    = $detail
    }
}

function Test-ActivationWindows {
    Write-Etape 'Activation de Windows'
    try { $etatLicence = Get-EtatActivationWindows }
    catch { Write-Alerte "État d'activation de Windows illisible : $($_.Exception.Message)"; return }

    if ($etatLicence.Definitif) { Write-Ok 'Windows est activé.'; return }

    $precision = ''
    if ($etatLicence.Detail) { $precision = " ($($etatLicence.Detail))" }
    Write-Info "Windows n'est pas activé définitivement : $($etatLicence.Statut)$precision."

    # La commande d'activation se trouve dans un fichier séparé, à compléter par le mainteneur
    $fichier = Join-Path $Tech 'activation\activation_windows.ps1'
    $commandes = @(Get-Content $fichier -Encoding UTF8 -ErrorAction SilentlyContinue |
        Where-Object { $_.Trim() -and -not $_.Trim().StartsWith('#') })
    if ($commandes.Count -eq 0) {
        Write-Alerte "Windows n'est pas activé : aucune commande d'activation configurée (activation\activation_windows.ps1)."
        return
    }

    Write-Info 'Lancement de la commande d''activation...'
    try {
        $ErrorActionPreference = 'Stop'
        . $fichier
    } catch {
        Write-Alerte "Commande d'activation en échec : $($_.Exception.Message)"
    } finally {
        $ErrorActionPreference = 'Continue'
    }

    try { $etatLicence = Get-EtatActivationWindows } catch { return }
    if ($etatLicence.Definitif) { Write-Ok 'Windows est maintenant activé.' }
    else { Write-Alerte "Windows n'est toujours pas activé ($($etatLicence.Statut)). Vérifiez activation\activation_windows.ps1." }
}

function Update-TousLesLogiciels {
    Write-Etape 'Mise à jour de tous les logiciels Windows'
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) { return }
    if ($script:Distro) { & wsl.exe --shutdown | Out-Null }   # libère WSL avant sa propre mise à jour
    # Source winget uniquement : une boutique Microsoft injoignable ne bloque plus toutes
    # les mises à jour (les applications du Store se mettent à jour par le Store).
    & winget.exe upgrade --all --source winget -h --accept-package-agreements --accept-source-agreements --disable-interactivity | Out-Host
    $code = $LASTEXITCODE
    # 0 = tout est à jour ; -1978335189 (0x8A15002B) = aucune mise à jour applicable
    if ($code -eq 0 -or $code -eq -1978335189) { Write-Ok 'Mise à jour des logiciels terminée.' }
    else { Write-Alerte ("Certaines mises à jour de logiciels ont échoué (code 0x{0:X8}, voir le journal)." -f $code) }
}

# =============================================================== WSL
function Enable-FonctionnaliteWSL {
    # Retourne $true si un redémarrage est nécessaire.
    Write-Etape 'Sous-système Linux (WSL 1)'
    $f = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
    if ($f.State -eq 'Enabled') { Write-Ok 'WSL est activé.'; return $false }
    if ($f.State -eq 'EnablePending') { Write-Info 'WSL attend un redémarrage.'; return $true }

    Write-Info 'Activation de WSL...'
    $r = Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -All -NoRestart
    Write-Ok 'WSL activé.'
    return [bool]$r.RestartNeeded
}

function Get-DistributionsWSL {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { return @() }
    $sortie = & wsl.exe --list --quiet
    if ($LASTEXITCODE -ne 0) { return @() }
    # Nettoyage au cas où wsl.exe répond en UTF-16
    @($sortie | ForEach-Object { ($_ -replace "`0", '').Trim() } | Where-Object { $_ })
}

function Find-Distribution {
    $liste = Get-DistributionsWSL
    if ($script:Etat.distribution -and ($liste -contains $script:Etat.distribution)) {
        return $script:Etat.distribution
    }
    # Machines installées en version 1 : la distribution s'appelle "Ubuntu"
    return ($liste | Where-Object { $_ -like 'Ubuntu*' } | Select-Object -First 1)
}

function Install-Distribution {
    Write-Etape "Installation de $DistroNouvelle"
    & wsl.exe --set-default-version 1 | Out-Host
    & wsl.exe --install -d $DistroNouvelle --no-launch --web-download | Out-Host

    if (-not ((Get-DistributionsWSL) -contains $DistroNouvelle)) {
        # Anciennes distributions "Store" : l'enregistrement passe par leur lanceur
        $lanceur = 'ubuntu' + ($DistroNouvelle -replace '[^0-9]', '') + '.exe'
        if (Get-Command $lanceur -ErrorAction SilentlyContinue) { & $lanceur install --root | Out-Host }
    }
    if ((Get-DistributionsWSL) -contains $DistroNouvelle) {
        & wsl.exe --set-version $DistroNouvelle 1 2>&1 | Out-Null   # sans effet si déjà en WSL 1
        Write-Ok "$DistroNouvelle installée."
        return $DistroNouvelle
    }
    Write-Alerte "$DistroNouvelle n'a pas pu être installée. Relancez la mise à jour plus tard."
    return $null
}

function Get-NomUtilisateurLinux {
    $nom = ($env:USERNAME.ToLower() -replace '[^a-z0-9_-]', '')
    if ($nom -notmatch '^[a-z_]') { $nom = 'esp' + $nom }
    if ($nom.Length -gt 32) { $nom = $nom.Substring(0, 32) }
    return $nom
}

function Request-MotDePasseLinux {
    $nom = Get-NomUtilisateurLinux
    Write-Host ''
    Write-Host "Un compte Linux '$nom' va être créé." -ForegroundColor Cyan
    Write-Host 'Choisissez son mot de passe (utile pour "sudo").'
    Write-Host 'C''est la seule question : vous pourrez ensuite laisser la machine travailler.'
    while ($true) {
        $a = Read-Host 'Mot de passe' -AsSecureString
        $b = Read-Host 'Confirmation' -AsSecureString
        $ta = ConvertTo-TexteClair $a
        $tb = ConvertTo-TexteClair $b
        if ([string]::IsNullOrEmpty($ta)) { Write-Host 'Le mot de passe ne peut pas être vide.' -ForegroundColor Yellow; continue }
        if ($ta -cne $tb) { Write-Host 'Les deux saisies sont différentes, recommencez.' -ForegroundColor Yellow; continue }
        break
    }
    # Chiffré avec DPAPI : seul ce compte Windows peut le relire. Supprimé après usage.
    $a | ConvertFrom-SecureString | Set-Content -Path $FichierSecret
}

function Get-MotDePasseStocke {
    if (-not (Test-Path $FichierSecret)) { return $null }
    try { return ConvertTo-TexteClair (Get-Content $FichierSecret | ConvertTo-SecureString) }
    catch { return $null }
}

# --------------------------------------------------------------- Exécution Linux
function ConvertTo-CheminLinux([string]$Chemin) {
    $p = (Resolve-Path $Chemin).Path
    return '/mnt/' + $p.Substring(0, 1).ToLower() + ($p.Substring(2) -replace '\\', '/')
}

function Copy-VersTmp([string]$Source, [string]$Nom) {
    # Copie en forçant les fins de ligne Unix (plus besoin de "sed" côté Linux)
    $contenu = [IO.File]::ReadAllText($Source) -replace "`r", ''
    $cible = Join-Path $DossierTmp $Nom
    [IO.File]::WriteAllText($cible, $contenu, $Utf8SansBom)
    return $cible
}

function Invoke-BashFichier([string]$Fichier, [string[]]$Arguments = @(), [string]$Entree, [string]$Distribution = $script:Distro) {
    $wslArgs = @('-d', $Distribution, '-u', 'root', '--exec', 'bash', (ConvertTo-CheminLinux $Fichier)) + $Arguments
    if ($Entree) { $Entree | & wsl.exe @wslArgs | Out-Host }
    else         { & wsl.exe @wslArgs | Out-Host }
    return $LASTEXITCODE
}

function Invoke-Linux {
    <#
      Exécute un morceau de script bash en root dans la distribution.
      Utilisable dans les migrations :  $code = Invoke-Linux 'apt-get -y install jq'
    #>
    param([Parameter(Mandatory)][string]$Script, [string[]]$Arguments = @())
    if (-not $script:Distro) { Write-Alerte 'Aucune distribution Linux : commande ignorée.'; return 1 }
    $nom = 'cmd_' + [guid]::NewGuid().ToString('N') + '.sh'
    $fichier = Join-Path $DossierTmp $nom
    [IO.File]::WriteAllText($fichier, ($Script -replace "`r", ''), $Utf8SansBom)
    $code = Invoke-BashFichier $fichier $Arguments
    Remove-Item $fichier -Force -ErrorAction SilentlyContinue
    return $code
}

function Copy-ScriptsLinux {
    foreach ($liste in 'paquets_apt.txt', 'outils_python.txt') {
        $src = Join-Path $DossierConfig $liste
        if (Test-Path $src) { Copy-VersTmp $src $liste | Out-Null }
    }
    return (Copy-VersTmp (Join-Path $DossierLinux 'esp_linux.sh') 'esp_linux.sh')
}

function Initialize-UtilisateurLinux {
    Write-Etape 'Compte Linux'
    $nom = Get-NomUtilisateurLinux
    $mdp = Get-MotDePasseStocke
    if (-not $mdp) { Request-MotDePasseLinux; $mdp = Get-MotDePasseStocke }

    $fichierSh = Copy-ScriptsLinux
    $code = Invoke-BashFichier $fichierSh @('utilisateur', $nom) $mdp
    if ($code -ne 0) { Write-Alerte "Création du compte Linux '$nom' échouée."; return }

    # Utilisateur par défaut aussi côté Windows (registre WSL), et désactivation
    # de l'assistant de premier lancement d'Ubuntu.
    $uid = ("$(& wsl.exe -d $script:Distro -u root --exec id -u $nom)").Trim()
    $cle = Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss' -ErrorAction SilentlyContinue |
        Where-Object { (Get-ItemProperty $_.PSPath).DistributionName -eq $script:Distro } |
        Select-Object -First 1
    if ($cle -and $uid -match '^\d+$') {
        Set-ItemProperty -Path $cle.PSPath -Name DefaultUid -Value ([int]$uid) -Type DWord
        if ((Get-ItemProperty $cle.PSPath).PSObject.Properties.Name -contains 'RunOOBE') {
            Set-ItemProperty -Path $cle.PSPath -Name RunOOBE -Value 0 -Type DWord
        }
    }
    & wsl.exe --terminate $script:Distro | Out-Null
    Remove-Item $FichierSecret -Force -ErrorAction SilentlyContinue
    Write-Ok "Compte Linux '$nom' prêt (mot de passe effacé de la machine)."
}

function Update-OutilsLinux([bool]$AvecMiseAJour) {
    # Sans mise à jour d'Ubuntu, on installe quand même les outils ajoutés aux listes
    Write-Etape 'Outils Linux'
    if (-not $AvecMiseAJour) { Write-Info 'Mise à jour du système Ubuntu : non demandée.' }
    if (-not $script:Distro) { Write-Alerte 'Pas de distribution Linux : étape ignorée.'; return }
    $action = 'outils'
    if ($AvecMiseAJour) { $action = 'maj' }
    $code = Invoke-BashFichier (Copy-ScriptsLinux) @($action)
    if ($code -eq 0) { Write-Ok 'Outils Linux à jour.' }
    else { Write-Alerte 'Certains outils Linux n''ont pas pu être installés (voir le journal).' }
}

# =============================================================== MIGRATIONS
function Invoke-Migrations {
    Write-Etape 'Migrations'
    $migrations = @(Get-ChildItem -Path $DossierMigr -Filter '*.ps1' -ErrorAction SilentlyContinue |
        Where-Object { $_.BaseName -match '^\d+' } |
        Sort-Object { [int]($_.BaseName -replace '^(\d+).*', '$1') })

    $faites = 0
    foreach ($m in $migrations) {
        $num = [int]($m.BaseName -replace '^(\d+).*', '$1')
        if ($num -le [int]$script:Etat.derniere_migration) { continue }
        Write-Info "Migration $($m.Name)..."
        try {
            $ErrorActionPreference = 'Stop'
            . $m.FullName      # "." et non "&" : la migration voit les fonctions et variables du moteur
            $ErrorActionPreference = 'Continue'
            $script:Etat.derniere_migration = $num
            Save-Etat
            Write-Ok $m.Name
            $faites++
        } catch {
            $ErrorActionPreference = 'Continue'
            Write-Alerte "Migration $($m.Name) en échec : $($_.Exception.Message). Elle sera retentée à la prochaine mise à jour."
            $faites = -1
            break   # on ne saute jamais une migration
        }
        if ($script:RedemarrageDemande) { break }
    }
    if ($faites -eq 0) { Write-Ok 'Aucune migration en attente.' }
}

# =============================================================== REDÉMARRAGE
function Restart-EtReprendre([string]$ModeOrigine) {
    if ([int]$script:Etat.redemarrages -ge 2) {
        Write-Alerte 'Un redémarrage est encore demandé après deux tentatives : on continue sans redémarrer.'
        return
    }
    $script:Etat.redemarrages = [int]$script:Etat.redemarrages + 1
    $script:Etat.reprise = $ModeOrigine
    Save-Etat

    # Tâche planifiée à l'ouverture de session, avec les droits admin : pas de
    # fenêtre d'autorisation à valider après le redémarrage.
    $compte = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Mode Reprise"
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments
    $declencheur = New-ScheduledTaskTrigger -AtLogOn -User $compte
    $declencheur.Delay = 'PT20S'
    $principal = New-ScheduledTaskPrincipal -UserId $compte -LogonType Interactive -RunLevel Highest
    $reglages = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)
    Register-ScheduledTask -TaskName $NomTache -Action $action -Trigger $declencheur -Principal $principal -Settings $reglages -Force | Out-Null

    Write-Host ''
    Write-Host 'Redémarrage dans 15 secondes.' -ForegroundColor Cyan
    Write-Host 'L''installation reprendra toute seule après l''ouverture de session.' -ForegroundColor Cyan
    Stop-Transcript | Out-Null
    & shutdown.exe /r /t 15 /c "ESP : redemarrage necessaire. L'installation reprendra automatiquement."
    exit 0
}

# =============================================================== FIN
function Complete-Execution([string]$VersionDepot) {
    $script:Etat.version = $VersionDepot
    $script:Etat.reprise = ''
    $script:Etat.redemarrages = 0
    Save-Etat

    if (Get-ScheduledTask -TaskName $NomTache -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $NomTache -Confirm:$false
    }
    Get-ChildItem $DossierTmp -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    # On garde les 20 derniers journaux
    Get-ChildItem $DossierJournaux -Filter '*.log' | Sort-Object LastWriteTime -Descending |
        Select-Object -Skip 20 | Remove-Item -Force -ErrorAction SilentlyContinue

    Write-Host ''
    Write-Host '================================================================' -ForegroundColor Cyan
    if ($script:Alertes.Count -eq 0) {
        Write-Host " ESP version $VersionDepot : tout est en ordre." -ForegroundColor Green
    } else {
        Write-Host " ESP version $VersionDepot : terminé avec $($script:Alertes.Count) point(s) à vérifier :" -ForegroundColor Yellow
        foreach ($a in $script:Alertes) { Write-Host "   - $a" -ForegroundColor Yellow }
        Write-Host ' Relancer la mise à jour suffit généralement à les corriger.'
    }
    Write-Host " Journal : $script:Journal"
    Write-Host '================================================================' -ForegroundColor Cyan
    Stop-Transcript | Out-Null
    Read-Host 'Appuyez sur Entrée pour fermer'
}

# ================================================================================
#                                   PROGRAMME
# ================================================================================

# --- Droits administrateur (une seule fenêtre d'autorisation) -------------------
$identite = [Security.Principal.WindowsIdentity]::GetCurrent()
$estAdmin = (New-Object Security.Principal.WindowsPrincipal $identite).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $estAdmin) {
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Mode $Mode"
    try { Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments }
    catch { Write-Host 'Autorisation administrateur refusée.' -ForegroundColor Red; Read-Host 'Entrée pour fermer' }
    exit
}

[Console]::OutputEncoding = $Utf8SansBom
$OutputEncoding = $Utf8SansBom
$env:WSL_UTF8 = '1'
$Host.UI.RawUI.WindowTitle = "ESP - $Mode"
New-Item -ItemType Directory -Force -Path $DossierEtat, $DossierTmp, $DossierJournaux | Out-Null
if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) { $env:Path += ";$env:ProgramFiles\Git\cmd" }

# --- Mise à jour : on récupère d'abord le dépôt, puis on relance la NOUVELLE version de ce script
if ($Mode -eq 'MiseAJour' -and -not $DepotSynchronise) {
    Write-Host 'Récupération de la dernière version du projet...' -ForegroundColor Cyan
    Sync-Depot
    & $PSCommandPath -Mode MiseAJour -DepotSynchronise
    exit $LASTEXITCODE
}

$script:Journal = Join-Path $DossierJournaux ('{0:yyyy-MM-dd_HH-mm-ss}_{1}.log' -f (Get-Date), $Mode)
Start-Transcript -Path $script:Journal | Out-Null

$script:Etat = Read-Etat
$ModeEffectif = $Mode
if ($Mode -eq 'Reprise') {
    $ModeEffectif = 'Installation'
    if ($script:Etat.reprise) { $ModeEffectif = $script:Etat.reprise }
}
$VersionDepot = 'inconnue'
$fichierVersion = Join-Path $Racine 'VERSION'
if (Test-Path $fichierVersion) { $VersionDepot = (Get-Content $fichierVersion -TotalCount 1).Trim() }

Write-Host '================================================================' -ForegroundColor Cyan
Write-Host " ESP - $ModeEffectif - version du projet : $VersionDepot" -ForegroundColor Cyan
Write-Host " Version installée sur ce poste : $(if ($script:Etat.version) { $script:Etat.version } else { 'aucune / version 1' })"
Write-Host '================================================================' -ForegroundColor Cyan

Set-GitConfiance
$script:Distro = Find-Distribution

# Installation et mise à jour : vérification de l'activation de Windows en tout premier
# (pas lors d'une reprise après redémarrage : elle a déjà été faite)
if ($Mode -ne 'Reprise') { Test-ActivationWindows }

# Les questions sont posées tout de suite, pendant que l'utilisateur est là ;
# la suite peut ensuite se dérouler sans surveillance.
if (-not $script:Distro -and -not (Get-MotDePasseStocke)) { Request-MotDePasseLinux }

$script:MajUbuntu = $false
if ($ModeEffectif -eq 'MiseAJour') {
    if ($Mode -eq 'Reprise') {
        $script:MajUbuntu = [bool]$script:Etat.maj_ubuntu
    } elseif ($script:Distro) {
        Write-Host ''
        $script:MajUbuntu = Read-OuiNon 'Voulez-vous aussi mettre à jour le système Ubuntu (WSL) ?'
        $script:Etat.maj_ubuntu = $script:MajUbuntu
        Save-Etat
    }
}

Set-ParametresWindows
Update-LogicielsWindows
Update-DossierLogiciels

if (Enable-FonctionnaliteWSL) { Restart-EtReprendre $ModeEffectif }

if (-not $script:Distro) {
    $script:Distro = Install-Distribution
    if ($script:Distro) { Initialize-UtilisateurLinux }
}
if ($script:Distro) { $script:Etat.distribution = $script:Distro; Save-Etat }

Invoke-Migrations
if ($script:RedemarrageDemande) { Restart-EtReprendre $ModeEffectif }

Update-OutilsLinux $script:MajUbuntu

if ($ModeEffectif -eq 'MiseAJour') { Update-TousLesLogiciels }

Complete-Execution $VersionDepot
