# =============================================================================
#  Installateur spécial : Microsoft Office
#  Appelé par la ligne "script:MicrosoftOffice" de config\logiciels_windows.txt.
#
#  Office est installé avec le paquet winget officiel de Microsoft
#  (Microsoft.Office = Office Deployment Tool), mais avec NOTRE configuration
#  config\office.xml : édition, langue française, 64 bits, applications
#  installées. Sans elle, winget installerait la configuration par défaut de
#  Microsoft.
#
#  Office est ensuite "épinglé" dans winget : "winget upgrade --all" ne le
#  réinstalle donc pas avec la configuration par défaut. Office se met à jour
#  tout seul par son propre mécanisme.
# =============================================================================

$cleOffice = 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration'

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

# Copie dans un dossier sans espaces (le chemin est passé tel quel à l'installeur)
$xml = Join-Path $DossierTmp 'office.xml'
Copy-Item -Path $xmlSource -Destination $xml -Force

Write-Info 'Installation de Microsoft Office (plusieurs Go à télécharger, cela peut être long)...'
& winget.exe install --id Microsoft.Office -e -h --source winget --accept-package-agreements --accept-source-agreements `
    --disable-interactivity --override "/configure $xml" | Out-Host
$codeOffice = $LASTEXITCODE

$present = Get-ItemProperty -Path $cleOffice -ErrorAction SilentlyContinue
if (-not ($present -and $present.ProductReleaseIds)) {
    throw ("installation non confirmée (code winget 0x{0:X8})" -f $codeOffice)
}
Lock-OfficeDansWinget
Write-Ok "Microsoft Office installé ($($present.ProductReleaseIds))."
