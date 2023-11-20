$retry = $true

while ($retry) {
    # Étape 1 : Demande à l'utilisateur quel logiciel il souhaite rechercher
    $softwareName = Read-Host "Entrez le nom du logiciel que vous souhaitez rechercher via winget"

    # Étape 2 : Exécute la commande winget search pour rechercher le logiciel
    $packageInfo = winget search $softwareName

    # Vérifie si la recherche a donné des résultats
    if ($packageInfo -match "Aucun package ne correspond") {
        Write-Host "Aucun logiciel correspondant à '$softwareName' n'a été trouvé."

        # Demande à l'utilisateur s'il souhaite refaire une recherche
        $retryChoice = Read-Host "Voulez-vous refaire une recherche ? (Oui/Non)"

        if ($retryChoice -eq "Non") {
            $retry = $false
        }
    } else {
        # Package trouvé, poursuivre le traitement
        Write-Host "Resultat de la recherche pour '$softwareName' :"

        $tableLines = $packageInfo -split "`r`n"
        $lineNumber = 1

        foreach ($line in $tableLines) {
            Write-Host ("{0:D3}: {1}" -f $lineNumber, $line)
            $lineNumber++
        }

        # Étape 3 : Demande à l'utilisateur de saisir un numéro de ligne
        $selectedLineNumber = Read-Host "Entrez le numero de ligne du logiciel que vous souhaitez installer (par exemple, 1) :"

        # Convertir l'entrée en entier
        $lineIndex = [int]$selectedLineNumber - 1

        # Extraire la deuxième colonne (ID) de la ligne sélectionnée en utilisant des espaces multiples comme délimiteur
        $selectedID = $null
        if ($lineIndex -ge 0 -and $lineIndex -lt $tableLines.Length) {
            $line = $tableLines[$lineIndex]
            $lineData = $line -split '\s+'
            if ($lineData.Length -ge 2) {
                $selectedID = $lineData[1]
            }
        }

        if ($selectedID) {
            # Étape 4 : Lancer la commande winget install avec l'ID extrait
            Write-Host "Lancement de l'installation avec l'ID : $selectedID"
            winget install $selectedID -h --accept-package-agreements --accept-source-agreements
        } else {
            Write-Host "Numero de ligne invalide ou ID non trouve."
        }
    }
}