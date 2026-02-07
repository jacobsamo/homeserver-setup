# Minecraft Server Setup

This guide covers setting up a Minecraft server using the [itzg/minecraft-server](https://github.com/itzg/docker-minecraft-server) Docker image running Paper with Bedrock Edition support via GeyserMC + Floodgate. The stack includes an RCON web admin panel for server management and automated daily backups.

## Architecture

The Minecraft stack uses dual networking paths because Cloudflare Tunnel only handles HTTP/HTTPS traffic -- it cannot proxy raw TCP or UDP game connections.

- **Game traffic** (Java TCP:25565, Bedrock UDP:19132) flows directly from the internet through your router's port forwarding to the Docker VM at `192.168.0.100`.
- **Admin panel** (`mc-admin.jsamo.com`) routes through Cloudflare Tunnel to Traefik to the RCON web container, just like all other web services.

```
                         ┌──────────────────────────────────────────────┐
                         │              Docker VM (192.168.0.100)       │
                         │                                              │
  Players (Java/Bedrock) │    ┌─────────────────────┐                  │
  ───── TCP:25565 ──────────> │                     │                  │
  ───── UDP:19132 ──────────> │  minecraft (:25565) │                  │
  (Router Port Forward)  │    │  (Paper + Geyser)   │                  │
                         │    └────────┬────────────┘                  │
                         │             │ RCON :25575 (internal only)    │
                         │             │                                │
                         │    ┌────────▼──────┐   ┌──────────────┐     │
                         │    │  rcon          │   │  mc-backup   │     │
                         │    │  (mc-admin)    │   │  (daily)     │     │
                         │    │  :4326         │   └──────────────┘     │
                         │    └────────┬───────┘                        │
                         │             │                                │
                         │    ┌────────▼───────┐                        │
  Admin (mc-admin.jsamo  │    │                │                        │
  .com)                  │    │   Traefik      │                        │
  ── Cloudflare Tunnel ──────>│   (:443)       │                        │
  (HTTPS only)           │    └────────────────┘                        │
                         └──────────────────────────────────────────────┘
```

**Key point**: Game traffic bypasses Cloudflare entirely. The `minecraft.jsamo.com` DNS record must be set to DNS only (grey cloud) so it resolves directly to your public IP.

## Prerequisites

- Docker VM running with Docker Compose on `192.168.0.100`
- Traefik reverse proxy stack running (with the `proxy` Docker network created)
- Router admin access for port forwarding configuration
- Cloudflare account with `jsamo.com` configured and tunnel active

## Step 1: Environment Setup

```bash
cd docker/games
cp .env.example .env
```

Edit `.env` and set strong passwords for both values:

```env
RCON_PASSWORD=your-strong-rcon-password
RCON_WEB_PASSWORD=your-strong-admin-panel-password
TZ=Australia/Sydney
```

`RCON_PASSWORD` is used internally between the Minecraft server and the RCON/backup containers. `RCON_WEB_PASSWORD` is the login password for the web admin panel.

## Step 2: Start the Stack

```bash
docker compose up -d
docker compose logs -f minecraft  # Wait for "Done!" message
```

The stack consists of three services:

| Service | Container Name | Purpose |
|---------|---------------|---------|
| `minecraft` | `minecraft` | Paper Minecraft server with GeyserMC + Floodgate plugins |
| `rcon` | `mc-admin` | Web-based RCON admin panel (port 4326, routed via Traefik) |
| `mc-backup` | `mc-backup` | Automated world backups every 24 hours, retains 7 days |

Both `rcon` and `mc-backup` have `depends_on` with `condition: service_healthy`, so they will wait for the Minecraft server to pass its health check before starting. The health check uses `mc-health` and allows up to 3 minutes of startup time before considering the server unhealthy.

## Step 3: Cloudflare DNS

In the Cloudflare dashboard for `jsamo.com`, add a DNS record:

| Type | Name | Content | Proxy Status |
|------|------|---------|-------------|
| A | `minecraft` | Your public IP address | **DNS only (grey cloud)** |

**CRITICAL**: The proxy status must be set to **DNS only** (grey cloud icon). Cloudflare's proxy does NOT support TCP/UDP game traffic. If you enable the proxy (orange cloud), the DNS record will resolve to Cloudflare's servers and players will not be able to connect to the Minecraft server.

## Step 4: Cloudflare Tunnel

Add `mc-admin` as a public hostname in your Cloudflare Tunnel configuration:

1. Go to [Cloudflare Zero Trust](https://one.dash.cloudflare.com) > Access > Tunnels
2. Select your active tunnel and go to the **Public Hostname** tab
3. Add a new public hostname:

| Field | Value |
|-------|-------|
| Subdomain | `mc-admin` |
| Domain | `jsamo.com` |
| Type | `HTTPS` |
| URL | `traefik:443` |

4. Under **Additional application settings** > **TLS**, enable **No TLS Verify** (Traefik handles internal certificates)
5. Save the hostname

## Step 5: Router Port Forwarding

In your router's admin interface, forward the following ports to `192.168.0.100`:

| Protocol | External Port | Internal Port | Internal IP | Purpose |
|----------|--------------|---------------|-------------|---------|
| TCP | 25565 | 25565 | 192.168.0.100 | Java Edition |
| UDP | 19132 | 19132 | 192.168.0.100 | Bedrock Edition (GeyserMC) |

The exact steps vary by router. Typically found under NAT, Port Forwarding, or Virtual Servers in your router settings.

## Step 6: Static IP

Ensure the Docker VM always receives `192.168.0.100`. If the VM's IP changes, port forwarding rules will break and players will not be able to connect.

Two options:

- **DHCP reservation** (recommended): In your router, bind the VM's MAC address to `192.168.0.100`. The VM continues to use DHCP but always receives the same IP.
- **Static IP in VM**: Configure the VM's network interface directly with a static IP of `192.168.0.100`, appropriate gateway, and DNS servers.

## Step 7: Admin Panel

1. Navigate to `https://mc-admin.jsamo.com`
2. Log in with:
   - Username: `admin`
   - Password: the `RCON_WEB_PASSWORD` value from your `.env` file
3. Add a server connection if not auto-configured (host: `minecraft`, RCON port: `25575`, password: your `RCON_PASSWORD`)
4. Add server status widgets to the dashboard to monitor player count, TPS, and memory usage
5. Use the RCON console tab to send commands directly to the server

## Step 8: First-Time Server Config

Via the RCON admin panel console or in-game chat, run these commands to set up basic access control:

```
/op YourUsername
/whitelist on
/whitelist add YourUsername
```

Add other players to the whitelist as needed:

```
/whitelist add FriendUsername
```

## Connecting

### Java Edition

- Address: `minecraft.jsamo.com`
- Port: default (25565) -- no need to specify

In the Minecraft client: Multiplayer > Add Server > enter `minecraft.jsamo.com` as the server address.

### Bedrock Edition (Mobile/Windows)

- Address: `minecraft.jsamo.com`
- Port: `19132`

In the Minecraft client: Play > Servers > Add Server > enter the address and port.

### Bedrock Console (Xbox/PlayStation/Switch)

Console editions cannot connect to custom servers directly. Workarounds exist (such as BedrockConnect or DNS redirect tricks) but are outside the scope of this guide.

## Updating

```bash
cd docker/games
docker compose pull
docker compose up -d
```

The server is configured with `VERSION: LATEST`, which auto-updates Paper to the latest build on each container recreation. GeyserMC and Floodgate plugins also pull latest versions automatically via the `PLUGINS` URLs.

To pin a specific Minecraft version, edit `docker-compose.yml` and change the `VERSION` environment variable:

```yaml
VERSION: "1.21.4"
```

## Backup & Restore

### Automated Backups

The `mc-backup` container runs every 24 hours and retains 7 days of backups. During each backup it uses RCON to pause world saves (`save-off`, `save-all`) to prevent data corruption, then re-enables saves when complete.

Backups are stored in `docker/games/minecraft/backups/`.

### Manual Backup

Trigger an immediate backup:

```bash
docker exec mc-backup backup now
```

### Restore from Backup

```bash
cd docker/games

# Stop the server
docker compose stop minecraft

# Extract backup over the existing data directory
tar -xzf minecraft/backups/BACKUP_FILE.tar.gz -C minecraft/data/

# Restart the server
docker compose start minecraft
```

Replace `BACKUP_FILE.tar.gz` with the actual backup filename from `minecraft/backups/`.

## Troubleshooting

### Server won't start

- Check logs for errors:
  ```bash
  docker compose logs minecraft
  ```
- Verify `EULA: "TRUE"` is set in `docker-compose.yml`
- Ensure the VM has enough memory. The server is configured for 4G of heap memory (`MEMORY: 4G`), so the VM should have at least 8GB RAM total to accommodate the OS and other containers.

### Bedrock players can't connect

- Verify the GeyserMC plugin loaded successfully:
  ```bash
  docker compose logs minecraft | grep -i geyser
  ```
- Confirm UDP port 19132 is forwarded in your router
- Ensure the `minecraft.jsamo.com` Cloudflare DNS record is set to **DNS only** (grey cloud), NOT proxied (orange cloud)
- Test UDP connectivity from outside your network:
  ```bash
  nc -zu SERVER_IP 19132
  ```

### Java players can't connect

- Confirm TCP port 25565 is forwarded in your router
- Ensure the `minecraft.jsamo.com` Cloudflare DNS record is set to **DNS only** (grey cloud), NOT proxied (orange cloud)
- Test TCP connectivity from outside your network:
  ```bash
  nc -zv SERVER_IP 25565
  ```

### Admin panel not accessible

- Verify the Cloudflare Tunnel has the `mc-admin` hostname configured (see Step 4)
- Check the RCON container is running:
  ```bash
  docker ps | grep mc-admin
  ```
- Verify Traefik is discovering the service: check the Traefik dashboard at `traefik.jsamo.com` for the `mc-admin` router
- Check RCON container logs:
  ```bash
  docker compose logs rcon
  ```

### Server lag / performance

- Reduce `VIEW_DISTANCE` (default 9) or `SIMULATION_DISTANCE` (default 7) in `docker-compose.yml`
- Check VM resource allocation in Proxmox (CPU and memory usage)
- Consider reducing `MAX_PLAYERS` (default 10)
- Use the `/timings` command in-game or via RCON to identify performance bottlenecks
- Enable Aikar's flags (already set with `USE_AIKAR_FLAGS: "true"`) for optimized garbage collection

## Proxmox VM Notes

The Docker VM should have at least 4 vCPUs and 8GB RAM to comfortably run Minecraft alongside other containers. See [TrueNAS Proxmox Setup](./TrueNAS-setup-proxmox.md) for general Proxmox VM configuration patterns.

If the server is under heavy load, consider increasing RAM allocation in Proxmox and adjusting `MEMORY` in `docker-compose.yml` accordingly. For example, if the VM is bumped to 12GB RAM, you could set `MEMORY: 6G` to give the Minecraft server more heap space.
