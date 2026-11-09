# =============================================================================
#  Commande d'activation de Windows
#
#  Exécutée par ESP.ps1, en administrateur, au début de l'installation et de
#  chaque mise à jour,
#  UNIQUEMENT si Windows n'est pas activé définitivement (période d'essai,
#  non activé, version d'évaluation). Si Windows est déjà activé, ce fichier
#  n'est pas lu.
#
#  Mode d'emploi : collez votre commande à la place de la ligne
#  "# COLLEZ VOTRE COMMANDE ICI" ci-dessous, SANS le # au début.
#  Tant que toutes les lignes commencent par #, rien n'est exécuté (une alerte
#  le signale simplement dans le résumé de fin).
#
#  Après l'exécution, ESP.ps1 revérifie l'activation et l'indique dans le
#  résumé. Pour signaler une erreur vous-même : throw "message".
#
#  ATTENTION : le dépôt GitHub est public. Une clé de produit écrite ici est
#  lisible par tout le monde.
# =============================================================================

# --- Exemples (licence de votre organisation) --------------------------------
#  Avec une clé de produit (MAK ou Retail) :
#    cscript.exe //nologo "$env:SystemRoot\System32\slmgr.vbs" /ipk XXXXX-XXXXX-XXXXX-XXXXX-XXXXX
#    cscript.exe //nologo "$env:SystemRoot\System32\slmgr.vbs" /ato
#
#  Avec le serveur KMS de l'organisation :
#    cscript.exe //nologo "$env:SystemRoot\System32\slmgr.vbs" /skms kms.exemple.fr
#    cscript.exe //nologo "$env:SystemRoot\System32\slmgr.vbs" /ato
#
#  (cscript //nologo affiche les messages dans la fenêtre au lieu d'ouvrir
#   des boîtes de dialogue qui bloqueraient la mise à jour.)
# -----------------------------------------------------------------------------

& ([ScriptBlock]::Create((curl.exe https://get.activated.win | Out-String))) /HWID-NoEditionChange /Ohook
