# Adding New Services

This guide walks through the process of adding a new Docker service to the homeserver infrastructure with Traefik reverse proxy and Cloudflare tunnel access.

## Prerequisites

- Service is available as a Docker image
- The `proxy` Docker network exists (`docker network create proxy`)
- Traefik and Cloudflared are running

## Step-by-Step Guide

### Step 1: Choose the Appropriate Stack

Decide which stack your service belongs to:

| Stack      | Use Case                                    |
|------------|---------------------------------------------|
| proxy      | Network edge services (reverse proxy, tunnel) |
| management | Admin tools (dashboards, container management) |
| apps       | Core applications (automation, utilities)    |
| monitoring | Health checks, logging, alerts              |
| games      | Game servers                                |

### Step 2: Add Service to Docker Compose

Add the service definition to the appropriate `docker-compose.yml` file.

#### Docker Compose Template

```yaml
services:
  your-service:
    image: organization/image:latest
    container_name: your-service
    restart: unless-stopped
    networks:
      - proxy
    volumes:
      - ./config/your-service:/config  # Adjust paths as needed
    environment:
      - TZ=${TZ}
      # Add other environment variables
    labels:
      # Traefik configuration
      - "traefik.enable=true"

      # Router configuration
      - "traefik.http.routers.your-service.rule=Host(`your-service.jsamo.com`)"
      - "traefik.http.routers.your-service.entrypoints=websecure"
      - "traefik.http.routers.your-service.tls.certresolver=cloudflare"

      # Optional: Apply security middlewares
      - "traefik.http.routers.your-service.middlewares=secured@file"

      # Service configuration (specify container port)
      - "traefik.http.services.your-service.loadbalancer.server.port=8080"

networks:
  proxy:
    external: true
```

### Step 3: Configure Traefik Labels

#### Basic Configuration

| Label | Purpose | Example |
|-------|---------|---------|
| `traefik.enable` | Enable Traefik discovery | `true` |
| `traefik.http.routers.<name>.rule` | Routing rule | `Host(\`app.jsamo.com\`)` |
| `traefik.http.routers.<name>.entrypoints` | Entry point | `websecure` |
| `traefik.http.routers.<name>.tls.certresolver` | SSL provider | `cloudflare` |
| `traefik.http.services.<name>.loadbalancer.server.port` | Container port | `8080` |

#### Optional Middleware

Add security middleware for internal-only services:

```yaml
- "traefik.http.routers.your-service.middlewares=secured@file"
```

Or chain multiple middlewares:

```yaml
- "traefik.http.routers.your-service.middlewares=default-headers@file,default-whitelist@file"
```

#### Custom Middleware Example

For basic authentication:

```yaml
labels:
  - "traefik.http.middlewares.your-service-auth.basicauth.users=${YOUR_SERVICE_CREDENTIALS}"
  - "traefik.http.routers.your-service.middlewares=your-service-auth"
```

### Step 4: Configure Cloudflare Tunnel

1. **Log in to Cloudflare Zero Trust Dashboard**
   - Go to https://one.dash.cloudflare.com
   - Navigate to Access > Tunnels

2. **Select Your Tunnel**
   - Click on your active tunnel
   - Go to the "Public Hostname" tab

3. **Add New Public Hostname**

   | Field | Value |
   |-------|-------|
   | Subdomain | `your-service` |
   | Domain | `jsamo.com` |
   | Type | `HTTPS` |
   | URL | `traefik:443` |

4. **Configure Additional Settings**

   Under "Additional application settings":

   - **TLS**: Enable "No TLS Verify" (since Traefik handles internal certs)
   - **HTTP Settings**: Keep defaults unless service requires WebSocket

5. **Save the Hostname**

### Step 5: Configure Cloudflare Access (Optional)

For services requiring authentication:

1. **Navigate to Access > Applications**
2. **Add an Application**
   - Type: Self-hosted
   - Name: Your Service
   - Session Duration: 24 hours (adjust as needed)

3. **Configure Application Settings**

   | Field | Value |
   |-------|-------|
   | Application domain | `your-service.jsamo.com` |
   | Path | Leave empty for full site |

4. **Add Access Policy**

   Example policy:
   ```
   Policy name: Allow Authorized Users
   Action: Allow
   Include: Emails ending in @yourdomain.com
   ```

5. **Save the Application**

### Step 6: Start the Service

```bash
cd docker/<stack>
docker compose up -d your-service
```

### Step 7: Verify Deployment

Run through this checklist to confirm everything is working:

## Testing Checklist

- [ ] **Container Running**
  ```bash
  docker ps | grep your-service
  ```

- [ ] **Container Logs Clean**
  ```bash
  docker logs your-service
  ```

- [ ] **Traefik Discovery**
  - Check Traefik dashboard at `traefik.jsamo.com`
  - Verify router and service appear

- [ ] **Internal Access**
  - Test from local network: `https://your-service.jsamo.com`
  - Or via IP: `http://192.168.0.100:<port>`

- [ ] **External Access**
  - Test from outside network or mobile data
  - Verify SSL certificate is valid

- [ ] **Cloudflare Access** (if configured)
  - Verify authentication prompt appears
  - Test login flow

## Troubleshooting

### Service Not Appearing in Traefik

1. Check container is on `proxy` network:
   ```bash
   docker network inspect proxy
   ```

2. Verify `traefik.enable=true` label is set

3. Check Traefik logs:
   ```bash
   docker logs traefik
   ```

### 502 Bad Gateway

1. Verify container port matches loadbalancer port in labels
2. Check container is actually listening on specified port:
   ```bash
   docker exec your-service netstat -tlnp
   ```

### SSL Certificate Issues

1. Check `acme.json` permissions (should be 600)
2. Verify Cloudflare API token has DNS:Edit permissions
3. Check Traefik logs for ACME errors

### Cloudflare Tunnel Not Routing

1. Verify tunnel is running:
   ```bash
   docker logs cloudflared
   ```

2. Check public hostname configuration in Cloudflare dashboard
3. Ensure URL points to `traefik:443` (not localhost)

## Complete Example: Adding Uptime Kuma

```yaml
# docker/monitoring/docker-compose.yml
services:
  uptime-kuma:
    image: louislam/uptime-kuma:latest
    container_name: uptime-kuma
    restart: unless-stopped
    networks:
      - proxy
    volumes:
      - ./config/uptime-kuma:/app/data
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.uptime-kuma.rule=Host(`status.jsamo.com`)"
      - "traefik.http.routers.uptime-kuma.entrypoints=websecure"
      - "traefik.http.routers.uptime-kuma.tls.certresolver=cloudflare"
      - "traefik.http.services.uptime-kuma.loadbalancer.server.port=3001"

networks:
  proxy:
    external: true
```

Cloudflare Tunnel configuration:
- Subdomain: `status`
- Domain: `jsamo.com`
- Type: `HTTPS`
- URL: `traefik:443`
- No TLS Verify: Enabled
