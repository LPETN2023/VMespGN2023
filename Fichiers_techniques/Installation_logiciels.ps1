# =============================================================================
#  Installation_logiciels.ps1 - recherche et installe un logiciel avec winget
#  Lancé par "Installation de logiciels.bat" (nom conservé pour compatibilité).
#  Enregistré en UTF-8 avec BOM.
# =============================================================================
$ErrorActionPreference = 'Continue'

# Droits administrateur si le script est lancé directement
$principal = New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
$Host.UI.RawUI.WindowTitle = 'ESP - Installation de logiciels'

function Search-Winget([string]$Terme, [switch]$ParId) {
    <#
      Lit le tableau de "winget search" en se repérant sur la POSITION des
      colonnes dans l'en-tête. Fonctionne quelle que soit la langue de Windows
      et même quand le nom du logiciel contient des espaces.
    #>
    $critere = @($Terme)
    if ($ParId) { $critere = @('--id', $Terme) }
    $lignes = @(& winget.exe search @critere --accept-source-agreements --disable-interactivity) |
        ForEach-Object { ($_ -split "`r")[-1] }     # retire les animations de progression

    $iSep = -1
    for ($i = 0; $i -lt $lignes.Count; $i++) { if ($lignes[$i] -match '^-{5,}') { $iSep = $i; break } }
    if ($iSep -lt 1) { return @() }

    $entete = $lignes[$iSep - 1]
    $cols = [regex]::Matches($entete, '\S+')
    if ($cols.Count -lt 3) { return @() }
    $posId      = $cols[1].Index
    $posVersion = $cols[2].Index
    $aSource    = ($cols[$cols.Count - 1].Value -eq 'Source')

    $resultats = @()
    if ($iSep + 1 -ge $lignes.Count) { return @() }
    foreach ($l in $lignes[($iSep + 1)..($lignes.Count - 1)]) {
        if ($l.Length -le $posId -or -not $l.Trim()) { continue }
        $id = ($l.Substring($posId).Trim() -split '\s+')[0]
        if (-not $id) { continue }
        $source = ''
        if ($aSource) { $source = ($l.Trim() -split '\s+')[-1] }
        $version = ''
        if ($l.Length -gt $posVersion) { $version = ($l.Substring($posVersion).Trim() -split '\s+')[0] }
        $resultats += [pscustomobject]@{
            N       = $resultats.Count + 1
            Nom     = $l.Substring(0, [Math]::Min($posId, $l.Length)).Trim()
            Id      = $id
            Version = $version
            Source  = $source
        }
    }
    return $resultats
}

while ($true) {
    Write-Host ''
    $terme = Read-Host 'Nom du logiciel à rechercher (ou Entrée pour quitter)'
    if (-not $terme.Trim()) { break }

    Write-Host 'Recherche en cours...'
    $resultats = @(Search-Winget $terme)
    if ($resultats.Count -eq 0) {
        Write-Host "Aucun logiciel trouvé pour '$terme'." -ForegroundColor Yellow
        continue
    }

    $resultats | Format-Table N, Nom, Id, Version, Source -AutoSize | Out-Host
    $choix = Read-Host 'Numéro du logiciel à installer (Entrée pour une nouvelle recherche)'
    $n = 0
    if (-not [int]::TryParse($choix, [ref]$n) -or $n -lt 1 -or $n -gt $resultats.Count) { continue }

    $logiciel = $resultats[$n - 1]

    # winget coupe les identifiants trop longs ("…") : on retrouve l'identifiant complet
    if ($logiciel.Id -match '(…|\.\.\.)$') {
        $prefixe = $logiciel.Id -replace '(…|\.\.\.)$', ''
        $complets = @(Search-Winget $prefixe -ParId | Where-Object { $_.Id -like "$prefixe*" -and $_.Id -notmatch '(…|\.\.\.)$' })
        if ($complets.Count -eq 1) {
            $logiciel = $complets[0]
        } else {
            Write-Host "Identifiant trop long pour être affiché en entier ($($logiciel.Id))." -ForegroundColor Yellow
            Write-Host 'Faites une recherche plus précise.' -ForegroundColor Yellow
            continue
        }
    }
    Write-Host "Installation de $($logiciel.Nom) ($($logiciel.Id))..." -ForegroundColor Cyan
    $options = @('--id', $logiciel.Id, '-e', '-h', '--accept-package-agreements', '--accept-source-agreements')
    if ($logiciel.Source) { $options += @('--source', $logiciel.Source) }
    & winget.exe install @options
    if ($LASTEXITCODE -eq 0) { Write-Host 'Installation terminée.' -ForegroundColor Green }
    else { Write-Host ("winget a signalé un problème (code 0x{0:X8})." -f $LASTEXITCODE) -ForegroundColor Yellow }
}
