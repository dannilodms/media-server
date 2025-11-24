#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*"
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MEDIA_DIR="$ROOT_DIR/media"
CONFIG_DIR="$ROOT_DIR/config"

# UID/GID usados pelos containers (default 1000)
PUID=${PUID:-1000}
PGID=${PGID:-1000}

REQUIRED_DIRS=(
  "$MEDIA_DIR/torrents/watch"
  "$MEDIA_DIR/torrents/completed"
  "$MEDIA_DIR/originals"
  "$MEDIA_DIR/transcoded/1080p"
  "$MEDIA_DIR/transcoded/720p"
  "$CONFIG_DIR/jellyfin"
  "$CONFIG_DIR/qbittorrent"
  "$CONFIG_DIR/filebrowser"
  "$CONFIG_DIR/traefik"
)

log "Criando diretórios necessários"
for dir in "${REQUIRED_DIRS[@]}"; do
  mkdir -p "$dir"

done

ACME_FILE="$CONFIG_DIR/traefik/acme.json"
if [ ! -f "$ACME_FILE" ]; then
  log "Criando arquivo ACME para o Traefik"
  umask 177
  printf '{}' > "$ACME_FILE"
else
  chmod 600 "$ACME_FILE"
fi
umask 022

log "Aplicando proprietário ${PUID}:${PGID} e permissões (dirs 775, arquivos 664) em media/ e config/"
for path in "$MEDIA_DIR" "$CONFIG_DIR"; do
  [ -d "$path" ] || continue
  if command -v chown >/dev/null 2>&1; then
    chown -R "$PUID":"$PGID" "$path"
  fi
  find "$path" -type d -exec chmod 775 {} +
  find "$path" -type f -exec chmod 664 {} +
done

[ -f "$ACME_FILE" ] && chmod 600 "$ACME_FILE"

compose_cmd=""
if docker compose version >/dev/null 2>&1; then
  compose_cmd="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  compose_cmd="docker-compose"
else
  log "Docker Compose não encontrado. Instale docker compose plugin ou docker-compose."
  exit 1
fi

log "Subindo containers em modo detached"
$compose_cmd -f "$ROOT_DIR/infra/docker-compose.yaml" up -d

log "Setup concluído. A stack está rodando."
