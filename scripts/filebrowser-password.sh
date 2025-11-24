#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*"
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/infra/docker-compose.yaml"
SERVICE="filebrowser"

if [ ! -f "$COMPOSE_FILE" ]; then
  log "Arquivo $COMPOSE_FILE não encontrado. Execute o script a partir do repositório."
  exit 1
fi

if docker compose version >/dev/null 2>&1; then
  compose_cmd=(docker compose -f "$COMPOSE_FILE")
elif command -v docker-compose >/dev/null 2>&1; then
  compose_cmd=(docker-compose -f "$COMPOSE_FILE")
else
  log "Docker Compose não encontrado. Instale docker compose plugin ou docker-compose."
  exit 1
fi

log "Capturando logs recentes do serviço $SERVICE"
log_output="$(${compose_cmd[@]} logs "$SERVICE" 2>/dev/null || true)"

if [ -z "$log_output" ]; then
  log "Nenhum log encontrado. Verifique se o serviço está em execução."
  exit 1
fi

password_lines=$(printf '%s\n' "$log_output" | grep -Ei '(initial admin|generated password|username|password)' | tail -n 20 || true)

if [ -z "$password_lines" ]; then
  log "Logs não contêm a senha inicial. Reinicie o container após remover o banco para forçar nova geração."
  exit 1
fi

printf '\n=== Credenciais detectadas ===\n%s\n' "$password_lines"
