# =============================================================================
#  Installateur spécial : WinHTTrack Website Copier
#  Appelé par la ligne "script:HTTrack" de config\logiciels_windows.txt.
#
#  Pourquoi pas winget : le paquet winget "XavierRoche.HTTrack" pointe vers une
#  adresse dont le fichier a été remplacé par une version plus récente ; winget
#  le refuse (erreur 0x8A150011, "le code de hachage ne correspond pas").
#  On télécharge donc la dernière version sur le site officiel (le lien
#  "httrack_x64.exe" désigne toujours la version la plus récente) et on vérifie
#  sa signature numérique.
#
#  Règles d'un installateur spécial : ne rien faire si le logiciel est déjà là,
#  et "throw" en cas d'erreur (le moteur affiche alors une alerte).
# =============================================================================

$urlHTTrack = 'https://download.httrack.com/cserv.php3?File=httrack_x64.exe'

function Lock-HTTrackDansWinget {
    # Évite que "winget upgrade --all" bute sur le paquet winget défectueux
    $null = & winget.exe pin add --id XavierRoche.HTTrack -e --source winget --accept-source-agreements --disable-interactivity
}

if (Test-LogicielInstalle 'WinHTTrack*') {
    Write-Ok 'HTTrack déjà présent.'
    Lock-HTTrackDansWinget
    return
}

Write-Info 'Installation de HTTrack depuis httrack.com...'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

$installeur = Join-Path $DossierTmp 'httrack-installeur.exe'
Invoke-WebRequest -UseBasicParsing -Uri $urlHTTrack -OutFile $installeur

$signature = Get-AuthenticodeSignature $installeur
if ($signature.Status -ne 'Valid') {
    Remove-Item $installeur -Force -ErrorAction SilentlyContinue
    throw "signature de l'installeur non valide ($($signature.Status))"
}

# Installeur Inno Setup : installation silencieuse
$p = Start-Process -FilePath $installeur -ArgumentList '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-' -Wait -PassThru
Remove-Item $installeur -Force -ErrorAction SilentlyContinue
if ($p.ExitCode -ne 0) { throw "l'installeur a renvoyé le code $($p.ExitCode)" }

if (-not (Test-LogicielInstalle 'WinHTTrack*')) { throw 'installation non confirmée' }
Lock-HTTrackDansWinget
Write-Ok 'HTTrack installé.'
