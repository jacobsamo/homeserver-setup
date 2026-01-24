# Home Assistant Proxy Configuration

This guide covers configuring Home Assistant to work behind Traefik reverse proxy with Cloudflare tunnel, including mobile app compatibility.

## Overview

Home Assistant requires specific configuration to work correctly behind a reverse proxy:

- Trust the proxy's forwarded headers
- Allow connections from the proxy network
- Handle WebSocket connections for real-time updates

## Architecture

```
Mobile App / Browser
        |
        v
  Cloudflare Tunnel
        |
        v
     Traefik (192.168.0.100)
        |
        v
  Home Assistant (192.168.0.105:8123)
```

## Step 1: Home Assistant configuration.yaml

Add the following to your Home Assistant `configuration.yaml`:

```yaml
# HTTP configuration for reverse proxy
http:
  use_x_forwarded_for: true
  trusted_proxies:
    # Docker VM running Traefik
    - 192.168.0.100
    # Docker network ranges (cloudflared container)
    - 172.16.0.0/12
    - 10.0.0.0/8
    # Cloudflare IP ranges (if connecting directly)
    - 103.21.244.0/22
    - 103.22.200.0/22
    - 103.31.4.0/22
    - 104.16.0.0/13
    - 104.24.0.0/14
    - 108.162.192.0/18
    - 131.0.72.0/22
    - 141.101.64.0/18
    - 162.158.0.0/15
    - 172.64.0.0/13
    - 173.245.48.0/20
    - 188.114.96.0/20
    - 190.93.240.0/20
    - 197.234.240.0/22
    - 198.41.128.0/17
```

### Configuration Explanation

| Setting | Purpose |
|---------|---------|
| `use_x_forwarded_for: true` | Trust X-Forwarded-For header from proxy |
| `trusted_proxies` | List of IPs allowed to set forwarded headers |

After editing, restart Home Assistant:
```bash
# Via UI: Settings > System > Restart
# Or via CLI
ha core restart
```

## Step 2: Traefik Router Configuration

### Option A: Using File Provider (Recommended for External Services)

Add to `docker/proxy/config/services.yml`:

```yaml
http:
  routers:
    homeassistant:
      rule: Host(`home.jsamo.com`)
      service: homeassistant
      entryPoints:
        - websecure
      tls:
        certResolver: cloudflare

  services:
    homeassistant:
      loadBalancer:
        servers:
          - url: http://192.168.0.105:8123
```

### Option B: Using Docker Labels (If HA is Dockerized)

If Home Assistant is running as a Docker container on the same host:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.homeassistant.rule=Host(`home.jsamo.com`)"
  - "traefik.http.routers.homeassistant.entrypoints=websecure"
  - "traefik.http.routers.homeassistant.tls.certresolver=cloudflare"
  - "traefik.http.services.homeassistant.loadbalancer.server.port=8123"
```

### WebSocket Support

Traefik v3 handles WebSocket connections automatically. No additional configuration needed.

For older Traefik versions, you may need:

```yaml
http:
  middlewares:
    homeassistant-headers:
      headers:
        customRequestHeaders:
          X-Forwarded-Proto: "https"
        customResponseHeaders:
          X-Robots-Tag: "noindex, nofollow"

  routers:
    homeassistant:
      middlewares:
        - homeassistant-headers
```

## Step 3: Cloudflare Tunnel Setup

### Add Public Hostname

1. Go to Cloudflare Zero Trust Dashboard
2. Navigate to Access > Tunnels > Your Tunnel
3. Add Public Hostname:

| Field | Value |
|-------|-------|
| Subdomain | `home` |
| Domain | `jsamo.com` |
| Type | `HTTPS` |
| URL | `traefik:443` |

### Additional Settings

Under "Additional application settings":

| Setting | Value | Reason |
|---------|-------|--------|
| TLS > No TLS Verify | Enabled | Traefik uses self-signed internal cert |
| HTTP Settings > HTTP/2 | Enabled | Better performance |
| HTTP Settings > WebSockets | Enabled | Required for HA real-time updates |

## Step 4: Cloudflare Access Bypass for Mobile App

The Home Assistant mobile app requires direct API access without Cloudflare Access authentication prompts. Configure a bypass policy:

### Create Service Token

1. Go to Access > Service Auth > Service Tokens
2. Click "Create Service Token"
3. Name: `Home Assistant App`
4. Copy the `CF-Access-Client-Id` and `CF-Access-Client-Secret`

### Configure Access Application

1. Go to Access > Applications
2. Create or edit the Home Assistant application

**Application Settings:**
| Field | Value |
|-------|-------|
| Application domain | `home.jsamo.com` |
| Session Duration | 24 hours |

**Access Policies:**

Create two policies in this order:

**Policy 1: Service Token Bypass (for mobile app)**
| Field | Value |
|-------|-------|
| Policy name | Mobile App Bypass |
| Action | Service Auth |
| Include | Service Token = Home Assistant App |

**Policy 2: User Authentication (for browser)**
| Field | Value |
|-------|-------|
| Policy name | Authenticated Users |
| Action | Allow |
| Include | Emails ending in @yourdomain.com |

### Alternative: Path-Based Bypass

If you prefer not to use service tokens, bypass specific API paths:

**Policy: API Bypass**
| Field | Value |
|-------|-------|
| Policy name | API Access |
| Action | Bypass |
| Selector | Path |
| Value | `/api/*` |

> **Security Note**: Path-based bypass exposes your API publicly. Ensure strong HA authentication is configured.

### Mobile App Configuration

1. Open Home Assistant mobile app
2. Go to Settings > Companion App > Home Assistant Server
3. External URL: `https://home.jsamo.com`
4. If using Service Token, add headers in advanced settings (app-specific)

## Step 5: Testing

### Test Internal Access

From your local network:
```bash
curl -I http://192.168.0.105:8123
```

### Test via Traefik

```bash
curl -I https://home.jsamo.com
```

Expected response headers:
```
HTTP/2 200
content-type: text/html; charset=utf-8
```

### Test WebSocket

Open browser developer tools (F12) > Network tab > WS
Navigate to Home Assistant - you should see WebSocket connections establishing.

### Test Mobile App

1. Disconnect from home WiFi (use mobile data)
2. Open Home Assistant app
3. Verify connection and real-time updates work

## Troubleshooting

### 400: Bad Request

**Cause**: `trusted_proxies` not configured or missing proxy IP.

**Fix**: Add the proxy IP to `trusted_proxies` in `configuration.yaml`.

### 403: Forbidden

**Cause**: Cloudflare Access blocking the request.

**Fix**:
- Check Access policies are correctly ordered
- Verify service token is valid
- Check browser cookies/clear cache

### WebSocket Disconnections

**Cause**: Cloudflare timeout or proxy misconfiguration.

**Fix**:
- Ensure WebSockets enabled in Cloudflare tunnel settings
- Check Traefik isn't timing out connections
- Increase Cloudflare session duration

### Mobile App Can't Connect

**Cause**: Access policy blocking app requests.

**Fix**:
- Verify service token bypass policy exists
- Check policy order (bypass should be first)
- Ensure external URL is correctly configured in app

### Slow Dashboard Loading

**Cause**: Large states/entities loading over tunnel.

**Fix**:
- Enable HTTP/2 in Cloudflare settings
- Consider local access for heavy usage
- Optimize HA configuration (reduce polling intervals)

## Complete Working Configuration

### configuration.yaml

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 192.168.0.100
    - 172.16.0.0/12
    - 10.0.0.0/8
```

### services.yml (Traefik)

```yaml
http:
  routers:
    homeassistant:
      rule: Host(`home.jsamo.com`)
      service: homeassistant
      entryPoints:
        - websecure
      tls:
        certResolver: cloudflare

  services:
    homeassistant:
      loadBalancer:
        servers:
          - url: http://192.168.0.105:8123
```

### Cloudflare Tunnel

- Subdomain: `home`
- Type: HTTPS
- URL: `traefik:443`
- No TLS Verify: Yes
- WebSockets: Enabled

### Cloudflare Access

1. Service Token bypass policy (Action: Service Auth)
2. Email allow policy (Action: Allow)
