#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Uso: $0 <arquivo de vídeo>"
  exit 1
fi

log() {
  printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*"
}

INPUT_FILE="$1"
shift || true

if [ ! -f "$INPUT_FILE" ]; then
  log "Arquivo não encontrado: $INPUT_FILE"
  exit 1
fi

FINAL_MEDIA_ROOT=${FINAL_MEDIA_ROOT:-/media/final_media}
mkdir -p "$FINAL_MEDIA_ROOT"

RELATIVE_PATH=${RELATIVE_PATH:-}
FILENAME="$(basename "$INPUT_FILE")"
BASENAME="${FILENAME%.*}"
INPUT_DIR="$(dirname "$INPUT_FILE")"

if [[ "$INPUT_DIR" == "$FINAL_MEDIA_ROOT"* ]]; then
  DEST_DIR="$INPUT_DIR"
else
  DEST_DIR="$FINAL_MEDIA_ROOT"
  if [ -n "$RELATIVE_PATH" ]; then
    DEST_DIR="$DEST_DIR/$RELATIVE_PATH"
  fi
  DEST_DIR="$DEST_DIR/$BASENAME"
fi

mkdir -p "$DEST_DIR"
FINAL_ORIGINAL_PATH="$DEST_DIR/$FILENAME"

if [ "$INPUT_FILE" != "$FINAL_ORIGINAL_PATH" ]; then
  log "Movendo arquivo original para $DEST_DIR"
  mv -f "$INPUT_FILE" "$FINAL_ORIGINAL_PATH"
fi

INPUT_FILE="$FINAL_ORIGINAL_PATH"
BASENAME="$(basename "${INPUT_FILE%.*}")"

OUTPUT_1080="$DEST_DIR/${BASENAME}_1080p.mp4"
OUTPUT_720="$DEST_DIR/${BASENAME}_720p.mp4"

transcode_variant() {
  local target="$1"
  local scale_expr="$2"
  local crf_value="$3"

  if [ -f "$target" ]; then
    log "Arquivo de saída já existe, pulando: $target"
    return 0
  fi

  log "Gerando $(basename "$target")"
  ffmpeg -y -i "$INPUT_FILE" \
    -vf "scale=${scale_expr}" \
    -c:v libx264 -preset veryfast -crf "$crf_value" \
    -c:a aac -b:a 192k \
    "$target"
}

transcode_variant "$OUTPUT_1080" "min(1920\,iw):-2" 20
transcode_variant "$OUTPUT_720" "min(1280\,iw):-2" 22

log "Arquivos organizados em $DEST_DIR"
