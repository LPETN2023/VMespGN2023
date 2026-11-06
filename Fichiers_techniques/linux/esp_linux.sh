#!/usr/bin/env bash
# =============================================================================
#  esp_linux.sh - partie Linux de l'environnement ESP
#  Lancé EN ROOT par ESP.ps1 (wsl -u root) : aucun mot de passe sudo nécessaire.
#
#  Usage :  bash esp_linux.sh utilisateur <nom>   (mot de passe lu sur l'entrée)
#           bash esp_linux.sh outils                (installe ce qui manque)
#           bash esp_linux.sh maj                   (outils + mises à jour)
#
#  Les listes paquets_apt.txt et outils_python.txt sont copiées à côté de ce
#  script par ESP.ps1 (source : Fichiers_techniques/config/).
# =============================================================================
set -u
export DEBIAN_FRONTEND=noninteractive
export PIPX_HOME=/opt/pipx            # outils Python installés pour tous les comptes
export PIPX_BIN_DIR=/usr/local/bin

ICI="$(cd "$(dirname "$0")" && pwd)"
ACTION="${1:-}"
ECHECS=0

echec() { echo "  [!] $*"; ECHECS=$((ECHECS + 1)); }

lire_liste() {   # une valeur par ligne, '#' = commentaire
    [ -f "$ICI/$1" ] || return 0
    sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$ICI/$1" | grep -v '^$'
}

utilisateur_principal() {   # premier compte "humain" (UID 1000)
    getent passwd 1000 | cut -d: -f1
}

# -----------------------------------------------------------------------------
creer_utilisateur() {
    local u="$1" mdp=""
    IFS= read -r mdp || true
    mdp="${mdp%$'\r'}"

    if ! id -u "$u" >/dev/null 2>&1; then
        useradd -m -s /bin/bash -G sudo "$u" || { echec "useradd $u"; return 1; }
    fi
    if [ -n "$mdp" ]; then
        echo "$u:$mdp" | chpasswd || { echec "chpasswd"; return 1; }
    fi

    # Compte par défaut à l'ouverture d'Ubuntu
    touch /etc/wsl.conf
    if grep -q '^default=' /etc/wsl.conf; then
        sed -i "s/^default=.*/default=$u/" /etc/wsl.conf
    else
        printf '\n[user]\ndefault=%s\n' "$u" >> /etc/wsl.conf
    fi
    echo "  [OK] Compte $u prêt."
}

# -----------------------------------------------------------------------------
installer_paquets_apt() {
    echo "  Mise à jour de la liste des paquets..."
    apt-get update -q || echec "apt-get update"
    # shellcheck disable=SC2046
    apt-get install -y -q $(lire_liste paquets_apt.txt) < /dev/null || echec "installation des paquets apt"
}

installer_outils_python() {
    command -v pipx >/dev/null 2>&1 || { echec "pipx absent"; return; }
    local outil
    for outil in $(lire_liste outils_python.txt); do
        if [ -d "$PIPX_HOME/venvs/$outil" ]; then
            echo "  [OK] $outil déjà présent."
        else
            echo "  Installation de $outil..."
            pipx install "$outil" < /dev/null || echec "pipx install $outil"
        fi
    done
}

installer_telepathy() {
    local u maison depot
    u="$(utilisateur_principal)"
    [ -n "$u" ] || { echec "aucun compte utilisateur pour Telepathy"; return; }
    maison="$(getent passwd "$u" | cut -d: -f6)"
    depot="$maison/Telepathy_VM"

    if [ -d "$depot/.git" ]; then
        git -c safe.directory='*' -C "$depot" pull --ff-only -q || echec "mise à jour de Telepathy_VM"
    else
        git clone -q https://github.com/LPETN2023/Telepathy_VM "$depot" || { echec "clonage de Telepathy_VM"; return; }
    fi
    [ -x "$depot/.venv/bin/python" ] || python3 -m venv "$depot/.venv" || { echec "venv Telepathy"; return; }
    "$depot/.venv/bin/pip" install -q --upgrade -r "$depot/requirements.txt" < /dev/null || echec "dépendances Telepathy"
    chown -R "$u:$u" "$depot"

    cat > /usr/local/bin/telepathy <<EOF
#!/bin/sh
exec "$depot/.venv/bin/python" "$depot/Telegram_ESP.py" "\$@"
EOF
    chmod 755 /usr/local/bin/telepathy
    echo "  [OK] Telepathy prêt (commande : telepathy)."
}

mettre_a_jour() {
    echo "  Mise à jour d'Ubuntu..."
    apt-get -y -q -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold upgrade < /dev/null \
        || echec "apt-get upgrade"
    apt-get -y -q autoremove < /dev/null || true
    pipx upgrade-all < /dev/null || echec "pipx upgrade-all"
}

# -----------------------------------------------------------------------------
case "$ACTION" in
    utilisateur)
        creer_utilisateur "${2:?nom du compte manquant}"
        ;;
    outils)
        installer_paquets_apt
        installer_outils_python
        installer_telepathy
        ;;
    maj)
        installer_paquets_apt
        mettre_a_jour
        installer_outils_python
        installer_telepathy
        ;;
    *)
        echo "Usage : $0 utilisateur <nom> | outils | maj"
        exit 2
        ;;
esac

[ "$ECHECS" -eq 0 ] || exit 1
