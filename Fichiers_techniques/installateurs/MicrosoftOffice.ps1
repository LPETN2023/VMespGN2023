# =============================================================================
#  Installateur spécial : Microsoft Office
#  Appelé par la ligne "script:MicrosoftOffice" de config\logiciels_windows.txt.
#
#  Office est installé avec l'outil officiel de Microsoft (Office Deployment
#  Tool, setup.exe) et NOTRE configuration config\office.xml : édition, langue
#  française, 64 bits, applications installées.
#
#  Pourquoi pas "winget install Microsoft.Office" : le paquet winget pointe vers
#  un setup.exe que Microsoft remplace régulièrement à la même adresse ; tant
#  que le paquet n'est pas mis à jour, winget refuse le fichier (erreur
#  0x8A150011, "le code de hachage ne correspond pas"). On télécharge donc
#  setup.exe directement chez Microsoft et on vérifie sa signature numérique.
#
#  Office est ensuite "épinglé" dans winget : "winget upgrade --all" n'essaie
#  pas de le réinstaller. Office se met à jour tout seul.
# =============================================================================

$cleOffice = 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration'
$urlOdt    = 'https://officecdn.microsoft.com/pr/wsus/setup.exe'

function Lock-OfficeDansWinget {
    $null = & winget.exe pin add --id Microsoft.Office -e --source winget --accept-source-agreements --disable-interactivity
}

$present = Get-ItemProperty -Path $cleOffice -ErrorAction SilentlyContinue
if ($present -and $present.ProductReleaseIds) {
    Write-Ok "Microsoft Office déjà présent ($($present.ProductReleaseIds))."
    Lock-OfficeDansWinget
    return
}

$xmlSource = Join-Path $DossierConfig 'office.xml'
if (-not (Test-Path $xmlSource)) { throw 'fichier config\office.xml introuvable' }

# Dossier de travail sans espaces (les chemins sont passés tels quels à setup.exe)
$dossierOdt = Join-Path $DossierTmp 'office'
New-Item -ItemType Directory -Force -Path $dossierOdt | Out-Null
$xml   = Join-Path $dossierOdt 'office.xml'
$setup = Join-Path $dossierOdt 'setup.exe'
Copy-Item -Path $xmlSource -Destination $xml -Force

Write-Info 'Téléchargement de l''outil d''installation Microsoft Office...'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -UseBasicParsing -Uri $urlOdt -OutFile $setup

# setup.exe doit être signé par Microsoft
$signature = Get-AuthenticodeSignature $setup
if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') {
    Remove-Item $setup -Force -ErrorAction SilentlyContinue
    throw "signature de setup.exe non valide ($($signature.Status))"
}

Write-Info 'Installation de Microsoft Office (plusieurs Go à télécharger, cela peut être long)...'
$processus = Start-Process -FilePath $setup -ArgumentList "/configure $xml" -WorkingDirectory $dossierOdt -Wait -PassThru
$codeOffice = $processus.ExitCode

$present = Get-ItemProperty -Path $cleOffice -ErrorAction SilentlyContinue
if (-not ($present -and $present.ProductReleaseIds)) {
    throw ("installation non confirmée (code de setup.exe : {0})" -f $codeOffice)
}
Lock-OfficeDansWinget
Write-Ok "Microsoft Office installé ($($present.ProductReleaseIds))."
