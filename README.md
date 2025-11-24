# Jellyfin Contabo Stack

Infraestrutura completa para automatizar downloads, transcodificação e disponibilização de mídia via Jellyfin utilizando Docker Compose.

## Pré-requisitos

- Docker 24+ com plugin **docker compose** habilitado
- Bash 5+ (para executar os scripts em `scripts/`)
- Acesso a Internet para baixar imagens e dependências dentro do container `ffmpeg-watch`

## Estrutura

```
infra/                  # Arquivos de orquestração
scripts/                # Automação de setup, watch e transcodificação
config/                 # Configurações persistentes (criado pelo setup)
media/                  # Raiz com torrents/originais/transcodificados (criado pelo setup)
```

As pastas `config/` e `media/` não ficam versionadas: o script `setup.sh` cria toda a hierarquia diretamente no servidor antes de subir os containers.

## Como subir tudo

```bash
git clone <este-repo>
cd Contabo
chmod +x scripts/*.sh
./scripts/setup.sh
```

O script `setup.sh` cria a estrutura completa, aplica permissões básicas (775) e executa `docker compose up -d` usando `infra/docker-compose.yaml`.

## Fluxo automatizado

1. Copie arquivos `.torrent` para `media/torrents/watch`. O qBittorrent detecta automaticamente e inicia o download em `media/torrents/completed`.
2. O container `ffmpeg-watch` monitora `completed/` com `inotifywait`, move o arquivo finalizado para `media/originals` e chama `scripts/transcode.sh`.
3. `transcode.sh` gera duas versões (`1080p` e `720p`, H.264 + AAC) dentro de `media/transcoded/` garantindo idempotência (não sobrescreve saídas existentes).
4. Jellyfin lê continuamente `media/` e disponibiliza as novas versões aos clientes.

## Serviços principais

- **Jellyfin**: sem limites de recursos, expõe 8096/8920 e monta `media/` inteiro.
- **qBittorrent (linuxserver/qbittorrent:5.1.4)**: utiliza PUID/PGID 1000 por padrão, pasta watch dedicada e limites de 2 CPUs / 2 GB.
- **Filebrowser**: interface web rápida com acesso somente leitura ao usuário padrão (ajuste em `config/filebrowser`). Limites de 1 CPU / 512 MB.
- **ffmpeg-watch**: baseado em `jrottenberg/ffmpeg:latest`, executa `scripts/watch.sh` para orquestrar movimento e transcodificação.

Mais detalhes estão em `infra/README.md`.

## Senha temporária do qBittorrent

Sempre que o container `qbittorrent` inicia pela primeira vez (ou gera uma nova senha), a credencial padrão é enviada aos logs. Para visualizá-la rapidamente execute:

```bash
./scripts/qbittorrent-password.sh
```

O script captura os logs do serviço e exibe as últimas linhas que contêm `username`/`password`. Caso nada seja retornado, reinicie o container (`docker compose -f infra/docker-compose.yaml restart qbittorrent`) para forçar a regeneração da senha temporária.

## Boas práticas

- Ajuste `PUID`/`PGID` em `infra/docker-compose.yaml` para casar com o usuário do host e evite problemas de permissão.
- Se quiser modificar bitrates ou presets, edite `scripts/transcode.sh` e reinicie apenas o container `ffmpeg-watch`.
- Mantenha o host atualizado para garantir performance de IO e transcodificação GPU (caso deseje, adicione dispositivos ao serviço Jellyfin).
- Utilize volumes externos (EBS, discos Contabo) para `media/` a fim de suportar grandes bibliotecas.
- Execute `docker compose logs -f ffmpeg-watch` ao depurar a automação de transcoding.

## Limpeza e atualização

- `docker compose -f infra/docker-compose.yaml pull` mantém as imagens atualizadas.
- `docker compose -f infra/docker-compose.yaml down` desmonta toda a stack sem remover volumes.
- Faça backup periódico de `config/` para preservar ajustes de Jellyfin, qBittorrent e Filebrowser.
