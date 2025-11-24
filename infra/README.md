# Media Server Infrastructure

Este diretório contém a definição completa dos containers necessários para executar o servidor de mídia baseado em Jellyfin.

## Serviços

| Serviço        | Descrição                                                                 | Portas externas            |
| -------------- | ------------------------------------------------------------------------- | -------------------------- |
| `traefik`      | Reverse proxy com Let's Encrypt. Termina TLS e publica os subdomínios.    | 80 (HTTP), 443 (HTTPS)     |
| `jellyfin`     | Frontend e backend de streaming. Lê toda a biblioteca presente em `/media`.| via Traefik (HTTPS)        |
| `qbittorrent`  | Cliente BitTorrent (imagem `linuxserver/qbittorrent:5.1.4`) com pasta watch habilitada.| 6881 (TCP/UDP) + via Traefik |
| `filebrowser`  | Interface web para navegar e gerenciar arquivos dentro de `/media`.        | via Traefik (HTTPS)        |
| `ffmpeg-watch` | Container dedicado a monitorar downloads concluídos e disparar `ffmpeg`.   | —                          |

Os painéis HTTP dos serviços ficam disponíveis somente pelos subdomínios configurados no Traefik:

- `https://jellyfin.<seu-dominio>`
- `https://torrent.<seu-dominio>`
- `https://files.<seu-dominio>`

Caso deseje outros nomes, ajuste o arquivo `infra/.env` antes de subir a stack.

> O qBittorrent mantém as portas 6881 TCP/UDP expostas diretamente para o tráfego BitTorrent, enquanto o acesso WebUI passa pelo Traefik.

## Volumes

Todos os serviços compartilham o volume raiz `../media`, garantindo que downloads e a pasta final consolidada fiquem acessíveis para qualquer container.

```
media/
├── torrents/
│   ├── watch/
│   └── completed/
└── final_media/
	└── Série/Temporada/Episódio/arquivo/
		├── arquivo.mkv
		├── arquivo_1080p.mp4
		└── arquivo_720p.mp4
```

Essa árvore é criada automaticamente no host pelo script `scripts/setup.sh`, evitando que diretórios vazios sejam versionados.

As configurações específicas de cada serviço ficam em `../config/<serviço>` e são persistidas somente no host.

## Rede

Todos os containers residem na rede bridge `media_net`, isolando a stack do restante do host.

## Uso

```bash
cd infra
docker compose up -d
```

Antes de subir, copie `infra/.env.example` para `infra/.env` e informe:

```bash
cp infra/.env.example infra/.env
vim infra/.env   # defina e-mail do Let's Encrypt e os subdomínios desejados
```

Também é necessário apontar os registros DNS `A`/`AAAA` dos subdomínios para o IP do servidor para que o desafio HTTP-01 funcione.

> Recomendado executar `scripts/setup.sh` na raiz do repositório para criação de diretórios, permissões e inicialização automática.

## Configuração dos serviços

O passo a passo completo para configurar o qBittorrent (watch folder, caminhos de download e porta 6881) e o Jellyfin (bibliotecas apontando para `final_media`) está descrito no README principal na raiz do repositório. Siga aquelas instruções logo após subir os containers para garantir que o pipeline funcione do download à publicação.
