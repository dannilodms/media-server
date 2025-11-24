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

TRANSCODE_DIR=${TRANSCODE_DIR:-/media/transcoded}
OUTPUT_1080_DIR="$TRANSCODE_DIR/1080p"
OUTPUT_720_DIR="$TRANSCODE_DIR/720p"
mkdir -p "$OUTPUT_1080_DIR" "$OUTPUT_720_DIR"

FINAL_DIR=${FINAL_DIR:-/media/Final}
mkdir -p "$FINAL_DIR"

BASENAME="$(basename "${INPUT_FILE%.*}")"
OUTPUT_1080="$OUTPUT_1080_DIR/${BASENAME}_1080p.mp4"
OUTPUT_720="$OUTPUT_720_DIR/${BASENAME}_720p.mp4"

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

DEST_DIR="$FINAL_DIR/$BASENAME"
mkdir -p "$DEST_DIR"

move_into_final() {
  local source_file="$1"
  local destination_file="$DEST_DIR/$(basename "$source_file")"

  if [ ! -f "$source_file" ]; then
    log "Aviso: arquivo para mover não encontrado: $source_file"
    return
  fi

  log "Movendo $(basename "$source_file") para $DEST_DIR"
  mv -f "$source_file" "$destination_file"
}

move_into_final "$INPUT_FILE"
move_into_final "$OUTPUT_1080"
move_into_final "$OUTPUT_720"

log "Arquivos organizados em $DEST_DIR"
