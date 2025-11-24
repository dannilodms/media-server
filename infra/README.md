# Media Server Infrastructure

Este diretório contém a definição completa dos containers necessários para executar o servidor de mídia baseado em Jellyfin.

## Serviços

| Serviço        | Descrição                                                                 | Portas            |
| -------------- | ------------------------------------------------------------------------- | ----------------- |
| `jellyfin`     | Frontend e backend de streaming. Lê toda a biblioteca presente em `/media`.| 8096 (HTTP), 8920 |
| `qbittorrent`  | Cliente BitTorrent (imagem `linuxserver/qbittorrent:5.1.4`) com pasta watch habilitada.| 8080 (UI), 6881 (TCP/UDP) |
| `filebrowser`  | Interface web para navegar e gerenciar arquivos dentro de `/media`.        | 8081              |
| `ffmpeg-watch` | Container dedicado a monitorar downloads concluídos e disparar `ffmpeg`.   | —                 |

## Volumes

Todos os serviços compartilham o volume raiz `../media`, garantindo que downloads, originais e transcodificados fiquem acessíveis para qualquer container.

```
media/
├── torrents/
│   ├── watch/
│   └── completed/
├── originals/
└── transcoded/
    ├── 1080p/
    └── 720p/
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

> Recomendado executar `scripts/setup.sh` na raiz do repositório para criação de diretórios, permissões e inicialização automática.
