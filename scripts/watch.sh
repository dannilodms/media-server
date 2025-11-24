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
FINAL_MEDIA_ROOT=${FINAL_MEDIA_ROOT:-/media/final_media}
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRANSCODE_SCRIPT="${TRANSCODE_SCRIPT:-${SCRIPT_ROOT}/transcode.sh}"

require_binary inotifywait
mkdir -p "$WATCH_DIR" "$FINAL_MEDIA_ROOT"

if [ ! -f "$TRANSCODE_SCRIPT" ]; then
  log "Script de transcodificação não encontrado em $TRANSCODE_SCRIPT"
  exit 1
fi

derive_relative_dir() {
  local path="$1"
  if [[ "$path" == "$WATCH_DIR"* ]]; then
    local rel="${path#$WATCH_DIR/}"
    local dir_part="$(dirname "$rel")"
    if [ "$dir_part" = "." ]; then
      echo ""
    else
      echo "$dir_part"
    fi
  else
    echo ""
  fi
}

process_file() {
  local source="$1"
  if [ ! -f "$source" ]; then
    log "Arquivo não encontrado durante processamento: $source"
    return
  fi

  local filename="$(basename "$source")"
  local base_name="${filename%.*}"
  local rel_dir="$(derive_relative_dir "$source")"

  local destination_dir="$FINAL_MEDIA_ROOT"
  if [ -n "$rel_dir" ]; then
    destination_dir="$destination_dir/$rel_dir"
  fi
  destination_dir="$destination_dir/$base_name"

  mkdir -p "$destination_dir"
  local destination_path="$destination_dir/$filename"

  log "Movendo $filename para $destination_dir"
  mv -f "$source" "$destination_path"

  log "Iniciando transcodificação de $filename"
  if /bin/bash "$TRANSCODE_SCRIPT" "$destination_path"; then
    log "Transcodificação concluída para $filename"
  else
    log "Falha ao transcodificar $filename"
  fi
}

log "Monitorando novos arquivos em $WATCH_DIR"
inotifywait -m -e close_write -e moved_to --format '%w%f' "$WATCH_DIR" | while read -r completed_path; do
  if [ -f "$completed_path" ]; then
    process_file "$completed_path"
  elif [ -d "$completed_path" ]; then
    log "Processando pasta $(basename "$completed_path")"
    find "$completed_path" -type f -print0 | while IFS= read -r -d '' nested_file; do
      process_file "$nested_file"
    done
    rm -rf "$completed_path"
  else
    log "Entrada ignorada: $completed_path"
  fi
done
