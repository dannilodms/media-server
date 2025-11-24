# Jellyfin Stack

Infraestrutura completa para automatizar downloads e disponibilização de mídia via Jellyfin utilizando Docker Compose.

## Pré-requisitos

- Docker 24+ com plugin **docker compose** habilitado
- Bash 5+ (para executar os scripts em `scripts/`)
- Acesso a Internet para baixar imagens e dependências das imagens Docker utilizadas

## Estrutura

```
infra/                  # Arquivos de orquestração
scripts/                # Automação de setup e utilitários
config/                 # Configurações persistentes (criado pelo setup)
media/                  # Raiz com downloads do qBittorrent (criado pelo setup)
```

A pasta `media/` é criada já com a hierarquia mínima:

```
media/
├── watch_torrents/
├── incomplete_download/
└── complete_download/
```

Esses caminhos são os únicos esperados pelos containers.

As pastas `config/` e `media/` não ficam versionadas: o script `setup.sh` cria toda a hierarquia diretamente no servidor antes de subir os containers.

## Configuração de domínio e HTTPS

1. Crie os registros DNS `A/AAAA` para os subdomínios que irão atender Jellyfin, qBittorrent e Filebrowser.
2. Copie `infra/.env.example` para `infra/.env` e configure:

	- `LETSENCRYPT_EMAIL`: e-mail para emissão automática pelo Let's Encrypt
	- `JELLYFIN_HOST`, `QBITTORRENT_HOST`, `FILEBROWSER_HOST`: FQDNs que apontam para o servidor

3. Execute `./scripts/setup.sh` normalmente. O Traefik faz o desafio HTTP-01 e provisiona/renova os certificados em `config/traefik/acme.json` automaticamente.

## Como subir tudo

```bash
git clone <este-repo>
cd media-server
chmod +x scripts/*.sh
./scripts/setup.sh
```

O script `setup.sh` cria a estrutura completa, aplica permissões básicas (775) e executa `docker compose up -d` usando `infra/docker-compose.yaml`.

### Serviços e portas expostas

- Traefik: 80/443 públicos, finaliza TLS e encaminha para os subdomínios configurados
- Jellyfin: disponível exclusivamente via `https://jellyfin.<seu-dominio>` (ou o host definido no `.env`)
- qBittorrent Web UI: `https://torrent.<seu-dominio>` (BitTorrent usa diretamente 6881 TCP/UDP)
- Filebrowser: `https://files.<seu-dominio>`

## Fluxo automatizado

1. Copie arquivos `.torrent` para `media/watch_torrents`. O qBittorrent monitora essa pasta e importa automaticamente cada torrent nova.
2. Enquanto o download está em andamento, os pedaços ficam em `media/incomplete_download`. Ao finalizar, o qBittorrent move o resultado para `media/complete_download` (mapeado como `/downloads` dentro do container).
3. Jellyfin e Filebrowser leem diretamente `media/complete_download`, portanto todo arquivo finalizado fica imediatamente disponível para streaming e navegação.
- **Jellyfin**: sem limites de recursos e montando `media/` inteiro, protegida pelo Traefik.
- **qBittorrent (linuxserver/qbittorrent:5.1.4)**: utiliza PUID/PGID 1000 por padrão, monitora `media/watch_torrents` e mantém limites de 1 CPU / 1 GB. A WebUI passa pelo proxy enquanto as portas 6881 TCP/UDP continuam abertas para o protocolo BitTorrent.
- **Filebrowser**: interface web com acesso somente leitura ao usuário padrão (ajuste em `config/filebrowser`). Limites de 0.5 CPU / 512 MB e publicação exclusiva via Traefik.

Mais detalhes estão em `infra/README.md`.

## Configuração do qBittorrent (passo a passo)

1. Acesse `https://torrent.<seu-dominio>` (ou o host definido em `infra/.env`). Caso não lembre a senha inicial, execute `./scripts/qbittorrent-password.sh` para extraí-la dos logs.
2. No primeiro login, troque imediatamente usuário e senha em **Tools ▸ Options ▸ Web UI** para evitar que o Traefik exponha credenciais padrão.
3. Ainda em **Web UI**, mantenha a porta em `8080` (é a que o Traefik encaminha) e marque **Use HTTPS** desativado, já que o TLS é finalizado no proxy.
4. Abra **Tools ▸ Options ▸ Downloads** e configure:
	- **Default Save Path**: `/downloads` (mapeia para `media/complete_download`).
	- **Keep incomplete torrents in**: `/incomplete` (mapeia para `media/incomplete_download`).
	- **Monitored Folder**: `/watch`, habilitando **Automatically add torrents from** para que qualquer arquivo colocado em `media/watch_torrents` seja iniciado automaticamente.
	- **Copy .torrent files to**: `/watch` para manter um backup das torrents aceitas.
5. Em **Tools ▸ Options ▸ Connection** desmarque **Use different port on each startup** e mantenha a porta TCP/UDP fixa em `6881`, que já está liberada no `docker-compose`. Ajuste UPnP/port forwarding conforme a rede do servidor.
6. Na aba **BitTorrent** configure os limites de upload/download conforme a sua banda e ative **Do not start the download automatically** se quiser pausar torrents importadas automaticamente.
7. Salve as alterações. Qualquer `.torrent` copiado para `media/watch_torrents` entra em download, os arquivos incompletos ficam em `media/incomplete_download` e o resultado final aparece em `media/complete_download` pronto para o Jellyfin.

## Configuração do Jellyfin (passo a passo)

1. Acesse `https://jellyfin.<seu-dominio>` e conclua o assistente inicial criando o usuário administrador e definindo o idioma base.
2. Quando o wizard solicitar bibliotecas, crie uma biblioteca por tipo de mídia apontando para `/media/complete_download`. Você pode organizar o diretório final no formato que preferir (filmes, séries, etc.) diretamente no host.
3. Após a configuração inicial vá em **Dashboard ▸ Libraries** para revisar as bibliotecas, habilitar **Real-time monitoring** e configurar varreduras agendadas (recomenda-se a cada 15 minutos ou logo após grandes lotes de download).
4. Em **Dashboard ▸ Playback** ajuste a política de transcodificação (codec preferido, limite de taxa) conforme o perfil de hardware disponível. Caso pretenda usar aceleração por GPU, adicione o dispositivo ao serviço Jellyfin no `docker-compose` antes de ativar a opção.
5. Em **Dashboard ▸ Users & Access** defina perfis adicionais (usuários familiares, convidados), limites de bitrate e coleções compartilhadas.
6. Sempre que organizar novos arquivos, execute um **Scan Library** manual ou aguarde o monitoramento em tempo real detectar as mudanças.

Com esses passos, o qBittorrent alimenta automaticamente o pipeline de downloads e o Jellyfin consome diretamente `media/complete_download`.

## Senha temporária do qBittorrent

Sempre que o container `qbittorrent` inicia pela primeira vez (ou gera uma nova senha), a credencial padrão é enviada aos logs. Para visualizá-la rapidamente execute:

```bash
./scripts/qbittorrent-password.sh
```

O script captura os logs do serviço e exibe as últimas linhas que contêm `username`/`password`. Caso nada seja retornado, reinicie o container (`docker compose -f infra/docker-compose.yaml restart qbittorrent`) para forçar a regeneração da senha temporária.

## Senha temporária do Filebrowser

O Filebrowser imprime **apenas uma vez** a senha inicial do usuário `admin` nos logs ao criar o banco em `/config/filebrowser/database`. Guarde-a imediatamente ou utilize:

```bash
./scripts/filebrowser-password.sh
```

O script busca as últimas ocorrências de `username`/`password` nos logs do serviço e exibe o trecho correspondente. Se nenhuma senha for exibida, é porque o banco já foi inicializado e os logs não serão emitidos novamente. Para forçar a regeneração:

1. `docker compose -f infra/docker-compose.yaml stop filebrowser`
2. Remova o banco: `rm -rf config/filebrowser/database/*`
3. `docker compose -f infra/docker-compose.yaml up -d filebrowser`

Na próxima inicialização, a senha volta a aparecer nos logs e pode ser capturada com o script acima.

## Resetando o ambiente

Para derrubar todos os containers, remover volumes e apagar as pastas `media/` e `config/`, execute:

```bash
./scripts/reset.sh      # adiciona -y para pular a confirmação
```

Depois, rode `./scripts/setup.sh` para recomeçar do zero.

## Boas práticas

- Ajuste `PUID`/`PGID` em `infra/docker-compose.yaml` para casar com o usuário do host e evite problemas de permissão.
- Mantenha o host atualizado para garantir performance de IO e transcodificação GPU (caso deseje, adicione dispositivos ao serviço Jellyfin).
- Utilize volumes externos (EBS, discos Contabo) para `media/` a fim de suportar grandes bibliotecas.
- Configurar categorias no qBittorrent ajuda a organizar automaticamente subpastas dentro de `media/complete_download`.

## Limpeza e atualização

- `docker compose -f infra/docker-compose.yaml pull` mantém as imagens atualizadas.
- `docker compose -f infra/docker-compose.yaml down` desmonta toda a stack sem remover volumes.
- Faça backup periódico de `config/` para preservar ajustes de Jellyfin, qBittorrent e Filebrowser.
