#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*"
}

require_binary() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "Binary '$1' não encontrado. Instalando dependências..."
    apt-get update >/dev/null 2>&1
    apt-get install -y --no-install-recommends inotify-tools >/dev/null 2>&1
  fi
}

WATCH_DIR=${WATCH_DIR:-/media/torrents/completed}
ORIGINALS_DIR=${ORIGINALS_DIR:-/media/originals}
TRANSCODE_DIR=${TRANSCODE_DIR:-/media/transcoded}
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRANSCODE_SCRIPT="${TRANSCODE_SCRIPT:-${SCRIPT_ROOT}/transcode.sh}"

require_binary inotifywait
mkdir -p "$WATCH_DIR" "$ORIGINALS_DIR" "$TRANSCODE_DIR/1080p" "$TRANSCODE_DIR/720p"

if [ ! -f "$TRANSCODE_SCRIPT" ]; then
  log "Script de transcodificação não encontrado em $TRANSCODE_SCRIPT"
  exit 1
fi

log "Monitorando novos arquivos em $WATCH_DIR"
inotifywait -m -e close_write -e moved_to --format '%w%f' "$WATCH_DIR" | while read -r completed_path; do
  if [ -f "$completed_path" ]; then
    filename="$(basename "$completed_path")"
    destination="$ORIGINALS_DIR/$filename"

    log "Movendo $filename para originais"
    mv -f "$completed_path" "$destination"

    log "Iniciando transcodificação de $filename"
    if /bin/bash "$TRANSCODE_SCRIPT" "$destination"; then
      log "Transcodificação concluída para $filename"
    else
      log "Falha ao transcodificar $filename"
    fi
  elif [ -d "$completed_path" ]; then
    folder_name="$(basename "$completed_path")"
    destination_dir="$ORIGINALS_DIR/$folder_name"

    log "Movendo pasta $folder_name para originais"
    mv -f "$completed_path" "$destination_dir"

    find "$destination_dir" -type f -print0 | while IFS= read -r -d '' nested_file; do
      nested_name="$(basename "$nested_file")"
      log "Iniciando transcodificação de $nested_name"
      if /bin/bash "$TRANSCODE_SCRIPT" "$nested_file"; then
        log "Transcodificação concluída para $nested_name"
      else
        log "Falha ao transcodificar $nested_name"
      fi
    done
  else
    log "Entrada ignorada: $completed_path"
  fi
done
