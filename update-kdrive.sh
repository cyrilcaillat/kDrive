#!/usr/bin/env bash
set -euo pipefail

INSTALL_PATH="$HOME/Applications/kDrive.AppImage"
REPO="cyrilcaillat/kDrive"

# Version installée
INSTALLED_VERSION="(inconnue)"
if [[ -x "$INSTALL_PATH" ]]; then
    INSTALLED_VERSION=$("$INSTALL_PATH" --version 2>/dev/null | grep -oP 'version \K[\d.]+( \(build \d+\))?' | sed 's/ (build \([0-9]*\))/.\1/' || echo "(inconnue)")
fi
echo "Version installée : $INSTALLED_VERSION"

# Récupérer le nom du dernier fichier AppImage dans le dépôt
echo "Recherche de la dernière version sur GitHub..."
API_RESPONSE=$(curl -fsSL "https://api.github.com/repos/${REPO}/git/trees/main?recursive=1")
APPIMAGE_NAME=$(echo "$API_RESPONSE" | jq -r '.tree[] | select(.path | endswith(".AppImage")) | .path' | tail -1)

if [[ -z "$APPIMAGE_NAME" ]]; then
    echo "Erreur : aucun fichier AppImage trouvé dans le dépôt." >&2
    exit 1
fi

# Version distante extraite du nom de fichier (ex: kDrive-3.8.2.6-amd64.AppImage -> 3.8.2.6)
REMOTE_VERSION=$(echo "$APPIMAGE_NAME" | grep -oP '[\d]+\.[\d]+\.[\d]+\.[\d]+' || echo "(inconnue)")
echo "Version disponible  : $REMOTE_VERSION"

if [[ "$INSTALLED_VERSION" == *"$REMOTE_VERSION"* ]]; then
    echo "Déjà à jour, aucune installation nécessaire."
    if ! pgrep -f "kDrive.AppImage" > /dev/null 2>&1; then
        echo "kDrive n'est pas en cours d'exécution, lancement..."
        nohup "$INSTALL_PATH" > /dev/null 2>&1 &
        echo "kDrive lancé (PID $!)"
    else
        echo "kDrive est déjà en cours d'exécution."
    fi
    exit 0
fi

# Arrêter kDrive si en cours
if pgrep -f "kDrive.AppImage" > /dev/null 2>&1; then
    echo "Arrêt de kDrive..."
    pkill -f "kDrive.AppImage"
    sleep 2
else
    echo "kDrive n'est pas en cours d'exécution."
fi

# Télécharger via l'URL LFS media
DOWNLOAD_URL="https://media.githubusercontent.com/media/${REPO}/main/${APPIMAGE_NAME}"
mkdir -p "$HOME/Applications"

echo "Téléchargement de $APPIMAGE_NAME..."
curl -fL --progress-bar "$DOWNLOAD_URL" -o "$INSTALL_PATH"

chmod +x "$INSTALL_PATH"

echo "Mise à jour terminée : $INSTALL_PATH ($REMOTE_VERSION)"

# Relancer kDrive
echo "Lancement de kDrive..."
nohup "$INSTALL_PATH" > /dev/null 2>&1 &
echo "kDrive lancé (PID $!)"
