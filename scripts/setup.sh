#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*"
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MEDIA_DIR="$ROOT_DIR/media"
CONFIG_DIR="$ROOT_DIR/config"

REQUIRED_DIRS=(
  "$MEDIA_DIR/torrents/watch"
  "$MEDIA_DIR/torrents/completed"
  "$MEDIA_DIR/originals"
  "$MEDIA_DIR/transcoded/1080p"
  "$MEDIA_DIR/transcoded/720p"
  "$CONFIG_DIR/jellyfin"
  "$CONFIG_DIR/qbittorrent"
  "$CONFIG_DIR/filebrowser"
)

log "Criando diretórios necessários"
for dir in "${REQUIRED_DIRS[@]}"; do
  mkdir -p "$dir"

done

log "Aplicando permissões 775 em media/ e config/"
for path in "$MEDIA_DIR" "$CONFIG_DIR"; do
  [ -d "$path" ] || continue
  chmod -R 775 "$path"
done

if command -v chown >/dev/null 2>&1; then
  PUID=${PUID:-$(id -u)}
  PGID=${PGID:-$(id -g)}
  for path in "$MEDIA_DIR" "$CONFIG_DIR"; do
    [ -d "$path" ] || continue
    chown -R "$PUID":"$PGID" "$path"
  done
fi

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
