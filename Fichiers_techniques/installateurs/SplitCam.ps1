# =============================================================================
#  Installateur spécial : SplitCam
#  Appelé par la ligne "script:SplitCam" de config\logiciels_windows.txt.
#
#  Pourquoi pas winget : le paquet "SplitCam.SplitCam" n'existe plus dans le
#  catalogue winget (erreur 0x8A150014, "aucun paquet trouvé"). On télécharge
#  donc l'installeur officiel (lien du bouton "Download for Windows" de
#  splitcam.com) et on vérifie sa signature numérique.
#  SplitCam s'installe pour l'utilisateur courant et se met à jour tout seul.
#
#  Règles d'un installateur spécial : ne rien faire si le logiciel est déjà là,
#  et "throw" en cas d'erreur (le moteur affiche alors une alerte).
# =============================================================================

$urlSplitCam = 'https://splitcam.com/win-download/SplitCamSetup_x64.msi'

if (Test-LogicielInstalle 'SplitCam*') {
    Write-Ok 'SplitCam déjà présent.'
    return
}

Write-Info 'Installation de SplitCam depuis splitcam.com (fichier volumineux)...'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

$installeur = Join-Path $DossierTmp 'SplitCamSetup_x64.msi'
Invoke-WebRequest -UseBasicParsing -Uri $urlSplitCam -OutFile $installeur

$signature = Get-AuthenticodeSignature $installeur
if ($signature.Status -ne 'Valid') {
    Remove-Item $installeur -Force -ErrorAction SilentlyContinue
    throw "signature de l'installeur non valide ($($signature.Status))"
}

# Paquet MSI : installation silencieuse, sans redémarrage
$p = Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i `"$installeur`" /qn /norestart" -Wait -PassThru
Remove-Item $installeur -Force -ErrorAction SilentlyContinue
if ($p.ExitCode -notin 0, 3010) { throw "msiexec a renvoyé le code $($p.ExitCode)" }

if (-not (Test-LogicielInstalle 'SplitCam*')) { throw 'installation non confirmée' }
Write-Ok 'SplitCam installé.'
