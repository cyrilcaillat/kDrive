#!/usr/bin/env bash
set -euo pipefail

# Fonction pour logger avec horodatage
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

INSTALL_PATH="$HOME/Applications/kDrive.AppImage"
REPO="cyrilcaillat/kDrive"

log "========================================"
log "Début de la vérification kDrive"
log "========================================"

# Version installée
INSTALLED_VERSION="(inconnue)"
if [[ -x "$INSTALL_PATH" ]]; then
    # Tenter avec offscreen pour éviter l'erreur Qt sans display (anacron)
    RAW_VERSION_OUTPUT=$(QT_QPA_PLATFORM=offscreen "$INSTALL_PATH" --version 2>&1 || true)
    log "Sortie brute de --version : '$RAW_VERSION_OUTPUT'"
    INSTALLED_VERSION=$(echo "$RAW_VERSION_OUTPUT" | grep -oP 'version \K[\d.]+( \(build \d+\))?' | sed 's/ (build \([0-9]*\))/.\1/' || true)
    if [[ -z "$INSTALLED_VERSION" ]]; then
        # Fallback : extraire la version depuis les métadonnées ELF du fichier
        RAW_STRINGS=$(strings "$INSTALL_PATH" 2>/dev/null | grep -oP 'kDrive-\K[\d]+\.[\d]+\.[\d]+\.[\d]+' | head -1 || true)
        if [[ -n "$RAW_STRINGS" ]]; then
            INSTALLED_VERSION="$RAW_STRINGS"
            log "Version extraite depuis les métadonnées du binaire"
        else
            INSTALLED_VERSION="(inconnue)"
            log "Impossible d'extraire la version depuis la sortie ou le binaire"
        fi
    fi
else
    log "Fichier $INSTALL_PATH non trouvé ou non exécutable"
fi
log "Version installée : $INSTALLED_VERSION"

# Récupérer le nom du dernier fichier AppImage dans le dépôt
log "Recherche de la dernière version sur GitHub..."
API_URL="https://api.github.com/repos/${REPO}/git/trees/main?recursive=1"
log "Appel API : $API_URL"
API_RESPONSE=$(curl -fsSL "$API_URL" 2>&1) || {
    log_error "échec de l'appel API GitHub (code retour: $?)"
    log_error "Réponse : $API_RESPONSE"
    exit 1
}
log "Réponse API reçue ($(echo "$API_RESPONSE" | wc -c) octets)"
APPIMAGE_NAME=$(echo "$API_RESPONSE" | jq -r '.tree[] | select(.path | endswith(".AppImage")) | .path' | tail -1)
log "Fichier AppImage trouvé : '${APPIMAGE_NAME:-}'"

if [[ -z "$APPIMAGE_NAME" ]]; then
    log_error "aucun fichier AppImage trouvé dans le dépôt."
    log_error "Contenu de la réponse API (truncated) : $(echo "$API_RESPONSE" | head -c 500)"
    exit 1
fi

# Version distante extraite du nom de fichier (ex: kDrive-3.8.2.6-amd64.AppImage -> 3.8.2.6)
REMOTE_VERSION=$(echo "$APPIMAGE_NAME" | grep -oP '[\d]+\.[\d]+\.[\d]+\.[\d]+' || echo "(inconnue)")
log "Version disponible  : $REMOTE_VERSION"

if [[ "$INSTALLED_VERSION" == *"$REMOTE_VERSION"* ]]; then
    log "Déjà à jour, aucune installation nécessaire."
    if ! pgrep -f "kDrive.AppImage" > /dev/null 2>&1; then
        log "kDrive n'est pas en cours d'exécution, lancement..."
        nohup "$INSTALL_PATH" > /dev/null 2>&1 &
        log "kDrive lancé (PID $!)"
    else
        log "kDrive est déjà en cours d'exécution."
    fi
    exit 0
fi

# Arrêter kDrive si en cours
if pgrep -f "kDrive.AppImage" > /dev/null 2>&1; then
    log "Arrêt de kDrive..."
    pkill -f "kDrive.AppImage"
    sleep 2
else
    log "kDrive n'est pas en cours d'exécution."
fi

# Télécharger via l'URL LFS media
DOWNLOAD_URL="https://media.githubusercontent.com/media/${REPO}/main/${APPIMAGE_NAME}"
mkdir -p "$HOME/Applications"

log "Téléchargement de $APPIMAGE_NAME..."
curl -fL --progress-bar "$DOWNLOAD_URL" -o "$INSTALL_PATH"

chmod +x "$INSTALL_PATH"

log "Mise à jour terminée : $INSTALL_PATH ($REMOTE_VERSION)"

# Relancer kDrive
log "Lancement de kDrive..."
nohup "$INSTALL_PATH" > /dev/null 2>&1 &
log "kDrive lancé (PID $!)"
