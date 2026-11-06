# =============================================================================
#  Installateur spécial : Tor Browser
#  Appelé par la ligne "script:TorBrowser" de config\logiciels_windows.txt.
#
#  Pourquoi pas winget : le paquet winget de Tor Browser est souvent en retard
#  sur les nouvelles versions (erreur de vérification à l'installation), et
#  winget ne le reconnaît pas toujours comme installé. On télécharge donc la
#  dernière version sur le site officiel. Tor Browser se met ensuite à jour
#  tout seul.
#
#  Règles d'un installateur spécial : ne rien faire si le logiciel est déjà là,
#  et "throw" en cas d'erreur (le moteur affiche alors une alerte).
# =============================================================================

$dossierTor = Join-Path $env:LOCALAPPDATA 'Tor Browser'
$exeTor     = Join-Path $dossierTor 'Browser\firefox.exe'
$exeAncien  = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Tor Browser\Browser\firefox.exe'   # installé par winget (v1)

if ((Test-Path $exeTor) -or (Test-Path $exeAncien)) {
    Write-Ok 'Tor Browser déjà présent.'
    return
}

Write-Info 'Installation de Tor Browser depuis torproject.org...'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'   # sinon le téléchargement est très lent sous PowerShell 5.1

$infos = Invoke-RestMethod -UseBasicParsing `
    -Uri 'https://aus1.torproject.org/torbrowser/update_3/release/download-windows-x86_64.json'
if (-not $infos.binary) { throw 'adresse de téléchargement introuvable sur torproject.org' }

$installeurTor = Join-Path $DossierTmp 'torbrowser-installeur.exe'
Invoke-WebRequest -UseBasicParsing -Uri $infos.binary -OutFile $installeurTor

# L'installeur doit être signé par le Tor Project
$signature = Get-AuthenticodeSignature $installeurTor
if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Tor Project') {
    Remove-Item $installeurTor -Force -ErrorAction SilentlyContinue
    throw "signature de l'installeur non valide ($($signature.Status))"
}

# Installation silencieuse (/D= doit rester en dernier et sans guillemets)
Start-Process -FilePath $installeurTor -ArgumentList "/S /D=$dossierTor" -Wait
Remove-Item $installeurTor -Force -ErrorAction SilentlyContinue

if (-not (Test-Path $exeTor)) { throw "installation non confirmée ($exeTor absent)" }
Write-Ok 'Tor Browser installé.'
