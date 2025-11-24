#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*"
}

usage() {
  cat <<'EOF'
Uso: reset.sh [-y]
  -y    não pede confirmação antes de remover diretórios
EOF
}

FORCE=0
while getopts ":yh" opt; do
  case "$opt" in
    y) FORCE=1 ;;
    h)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/infra/docker-compose.yaml"
MEDIA_DIR="$ROOT_DIR/media"
CONFIG_DIR="$ROOT_DIR/config"

if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(docker compose -f "$COMPOSE_FILE")
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD=(docker-compose -f "$COMPOSE_FILE")
else
  log "Docker Compose não encontrado. Instale docker compose plugin ou docker-compose."
  exit 1
fi

if [ -f "$COMPOSE_FILE" ]; then
  log "Derrubando stack Docker"
  "${COMPOSE_CMD[@]}" down -v || true
fi

confirm_removal() {
  if [ "$FORCE" -eq 1 ]; then
    return 0
  fi

  read -r -p "Remover diretórios 'media/' e 'config/'? (y/N) " answer
  case "$answer" in
    [Yy][Ee][Ss]|[Yy]) return 0 ;;
    *)
      log "Operação cancelada."
      exit 0
      ;;
  esac
}

confirm_removal

log "Removendo diretórios criados pelo setup"
rm -rf "$MEDIA_DIR" "$CONFIG_DIR"

log "Reset concluído. Execute scripts/setup.sh para recriar a estrutura."
