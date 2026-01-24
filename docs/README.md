# Homeserver Setup

A complete Docker-based homelab infrastructure running on Proxmox, featuring Traefik reverse proxy with Cloudflare tunnel for secure external access.

## Infrastructure Overview

| Component       | IP Address      | Description                          |
|-----------------|-----------------|--------------------------------------|
| Proxmox         | 192.168.0.102   | Hypervisor host (port 8006)          |
| Docker VM       | 192.168.0.100   | Main Docker host running all stacks  |
| Home Assistant  | 192.168.0.105   | Home automation (port 8123)          |
| TrueNAS         | -               | Network storage                      |

## Services

| Service       | Internal Port | External URL                    | Stack      | Description                    |
|---------------|---------------|---------------------------------|------------|--------------------------------|
| Traefik       | 80/443        | traefik.jsamo.com               | proxy      | Reverse proxy & SSL            |
| Cloudflared   | -             | -                               | proxy      | Cloudflare tunnel connector    |
| Glance        | 8080          | -                               | management | Dashboard/start page           |
| Portainer     | 9000          | portainer.jsamo.com             | management | Docker management UI           |
| Pi-hole       | 53/8053       | pihole.jsamo.com                | apps       | DNS-level ad blocking          |
| N8N           | 5678          | n8n.jsamo.com                   | apps       | Workflow automation            |
| Uptime Kuma   | 3001          | status.jsamo.com                | monitoring | Service monitoring             |
| Watchtower    | -             | -                               | monitoring | Auto-update containers         |
| Home Assistant| 8123          | home.jsamo.com                  | external   | Home automation                |
| Minecraft     | 25565         | -                               | games      | Game server                    |

## Docker Stacks Structure

```
docker/
├── proxy/              # Traefik + Cloudflared (network edge)
├── management/         # Glance, Portainer (admin tools)
├── apps/               # Pi-hole, N8N (core applications)
├── monitoring/         # Uptime Kuma, Watchtower
├── games/              # Minecraft and other game servers
└── scripts/            # Helper scripts and utilities
```

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- Cloudflare account with domain configured
- Cloudflare tunnel token

### 1. Create the proxy network

```bash
docker network create proxy
```

### 2. Set up the proxy stack

```bash
cd docker/proxy
cp .env.example .env
# Edit .env with your Cloudflare credentials and domain
chmod 600 config/acme.json
docker compose up -d
```

### 3. Start additional stacks

```bash
# Management stack
cd docker/management
docker compose up -d

# Apps stack
cd docker/apps
cp .env.example .env
# Edit .env with your settings
docker compose up -d
```

### 4. Configure Cloudflare Tunnel

1. Go to Cloudflare Zero Trust dashboard
2. Create a tunnel and copy the token
3. Add the token to `docker/proxy/.env`
4. Configure public hostnames pointing to `traefik:443`

## Documentation

- [Architecture Overview](./ARCHITECTURE.md) - Network diagram and security layers
- [Adding Services Guide](./guides/adding-services.md) - How to add new services
- [Home Assistant Proxy Setup](./guides/home-assistant-proxy.md) - Configure HA with Traefik
- [TrueNAS Proxmox Setup](./guides/TrueNAS-setup-proxmox.md) - Storage VM configuration

## Environment Variables

### Proxy Stack (.env)

| Variable                     | Description                              |
|------------------------------|------------------------------------------|
| `DOMAIN`                     | Your domain (e.g., jsamo.com)            |
| `EMAIL`                      | Email for Let's Encrypt notifications    |
| `CLOUDFLARE_DNS_API_TOKEN`   | Cloudflare API token for DNS challenge   |
| `TRAEFIK_DASHBOARD_CREDENTIALS` | htpasswd-encoded credentials          |
| `TUNNEL_TOKEN`               | Cloudflare tunnel token                  |

### Apps Stack (.env)

| Variable         | Description                     |
|------------------|---------------------------------|
| `TZ`             | Timezone (e.g., Australia/Sydney)|
| `PIHOLE_PASSWORD`| Pi-hole admin password          |
| `WEBHOOK_URL`    | N8N webhook base URL            |

## Useful Commands

```bash
# View all running containers
docker ps

# Check Traefik logs
docker logs -f traefik

# Restart a stack
cd docker/<stack> && docker compose restart

# Update all containers in a stack
cd docker/<stack> && docker compose pull && docker compose up -d
```

## Network Architecture

See [ARCHITECTURE.md](./ARCHITECTURE.md) for detailed network diagrams and security information.
