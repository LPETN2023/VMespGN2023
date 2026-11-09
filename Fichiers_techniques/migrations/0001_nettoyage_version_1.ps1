# =============================================================================
#  Migration 0001 - Nettoyage des éléments laissés par la version 1 (2023)
#  Exécutée une seule fois par machine. Sans effet sur une installation neuve.
# =============================================================================

# Installation neuve (pas encore de Linux) : rien à nettoyer côté Linux.
if ($script:Distro) {
# Anciens alias de .bashrc : ils masqueraient les nouvelles commandes
# "sherlock" et "telepathy" installées dans /usr/local/bin.
$code = Invoke-Linux @'
for f in /root/.bashrc /home/*/.bashrc; do
    [ -f "$f" ] && sed -i -e '/^alias sherlock=/d' -e '/^alias telepathy=/d' "$f"
done
# Anciennes installations "sudo pip3" : remplacées par pipx
pip3 uninstall -y holehe ignorant >/dev/null 2>&1 || true
exit 0
'@
if ($code -ne 0) { throw "nettoyage Linux en échec (code $code)" }
}

# Ancienne entrée de démarrage de la version 1, si elle traîne encore
Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' `
    -Name 'Installation_WSL.bat' -ErrorAction SilentlyContinue
