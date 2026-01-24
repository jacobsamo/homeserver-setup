# Architecture Overview

This document describes the network architecture, security layers, and infrastructure layout for the homeserver setup.

## Network Diagram

```
                                    INTERNET
                                        |
                                        v
                            +-------------------+
                            |    Cloudflare     |
                            |   (DNS + CDN)     |
                            | *.jsamo.com       |
                            +-------------------+
                                        |
                                        | Cloudflare Access
                                        | (Authentication)
                                        v
                            +-------------------+
                            | Cloudflare Tunnel |
                            |   (cloudflared)   |
                            +-------------------+
                                        |
                                        | Encrypted tunnel
                                        | (no port forwarding)
                                        v
+-----------------------------------------------------------------------------------+
|                              DOCKER VM (192.168.0.100)                            |
|                                                                                   |
|   +-------------------+                                                           |
|   |     Traefik       |                                                           |
|   | (Reverse Proxy)   |<------ TLS termination, routing, middlewares             |
|   | :80, :443, :8080  |                                                           |
|   +-------------------+                                                           |
|            |                                                                      |
|            +------------------+------------------+------------------+             |
|            |                  |                  |                  |             |
|            v                  v                  v                  v             |
|   +---------------+  +---------------+  +---------------+  +---------------+      |
|   |    Glance     |  |    Pi-hole    |  |      N8N      |  |  Uptime Kuma  |      |
|   |    :8080      |  |   :53, :8053  |  |     :5678     |  |     :3001     |      |
|   +---------------+  +---------------+  +---------------+  +---------------+      |
|                                                                                   |
+-----------------------------------------------------------------------------------+

+-----------------------------------------------------------------------------------+
|                             PROXMOX HOST (192.168.0.102)                          |
|                                                                                   |
|   +-------------------+   +-------------------+   +-------------------+            |
|   |    Docker VM      |   |  Home Assistant   |   |     TrueNAS       |           |
|   |   192.168.0.100   |   |   192.168.0.105   |   |                   |           |
|   +-------------------+   +-------------------+   +-------------------+            |
|                                                                                   |
+-----------------------------------------------------------------------------------+
```

## Proxmox VM Layout

| VM/LXC         | IP Address    | vCPU | RAM  | Storage | Purpose               |
|----------------|---------------|------|------|---------|------------------------|
| Docker VM      | 192.168.0.100 | 4    | 8GB  | 100GB   | Main container host    |
| Home Assistant | 192.168.0.105 | 2    | 4GB  | 32GB    | Home automation        |
| TrueNAS        | DHCP/Static   | 2    | 8GB  | Passthrough | Network storage    |

## Network Flow

### External Request Flow

1. **User Request** - User navigates to `service.jsamo.com`
2. **Cloudflare DNS** - Resolves domain to Cloudflare edge
3. **Cloudflare Access** - Authenticates user (if configured)
4. **Cloudflare Tunnel** - Routes request through encrypted tunnel
5. **cloudflared** - Container receives request, forwards to Traefik
6. **Traefik** - Applies middlewares, routes to correct service
7. **Service** - Handles request and returns response

### Internal Request Flow

For services accessed within the local network:

```
Local Device (192.168.0.x)
        |
        v
    Traefik (:80/:443)
        |
        v
    Service Container
```

## Security Layers

### Layer 1: Cloudflare

- **DDoS Protection** - Automatic mitigation at the edge
- **WAF Rules** - Web Application Firewall filtering
- **Bot Management** - Blocks malicious automated traffic
- **SSL/TLS** - Full (strict) encryption mode

### Layer 2: Cloudflare Access (Zero Trust)

Configure access policies in Cloudflare Zero Trust dashboard:

- **Authentication** - Email OTP, SSO, or service tokens
- **Authorization** - Application-level access policies
- **Session Management** - Configurable session durations

Example policy structure:
```
Application: traefik.jsamo.com
  - Allow: Emails ending in @yourdomain.com
  - Require: Country is [your countries]
```

### Layer 3: Traefik Middlewares

Defined in `docker/proxy/config/services.yml`:

```yaml
middlewares:
  # Security headers for all responses
  default-headers:
    headers:
      frameDeny: true
      browserXssFilter: true
      contentTypeNosniff: true
      forceSTSHeader: true
      stsIncludeSubdomains: true
      stsPreload: true
      stsSeconds: 15552000

  # IP whitelist for internal-only services
  default-whitelist:
    ipAllowList:
      sourceRange:
        - "10.0.0.0/8"
        - "192.168.0.0/16"
        - "172.16.0.0/12"

  # Combined middleware chain
  secured:
    chain:
      middlewares:
        - default-whitelist
        - default-headers
```

### Layer 4: Container Isolation

- **Docker Networks** - Isolated `proxy` network for exposed services
- **Read-only Mounts** - Where possible, mount configs as `:ro`
- **No Privileged Mode** - Avoid unless absolutely necessary
- **Minimal Capabilities** - Only add required caps (e.g., `NET_ADMIN` for Pi-hole)

## Port Mappings

### Docker VM (192.168.0.100)

| Port  | Protocol | Service     | Notes                    |
|-------|----------|-------------|--------------------------|
| 80    | TCP      | Traefik     | HTTP (redirects to 443)  |
| 443   | TCP      | Traefik     | HTTPS                    |
| 8080  | TCP      | Traefik     | Dashboard (internal)     |
| 53    | TCP/UDP  | Pi-hole     | DNS                      |
| 8053  | TCP      | Pi-hole     | Web interface            |

### Home Assistant (192.168.0.105)

| Port  | Protocol | Service         | Notes              |
|-------|----------|-----------------|---------------------|
| 8123  | TCP      | Home Assistant  | Web interface       |

### Proxmox (192.168.0.102)

| Port  | Protocol | Service   | Notes              |
|-------|----------|-----------|---------------------|
| 8006  | TCP      | Proxmox   | Web interface       |

## SSL/TLS Configuration

### Certificate Management

Traefik automatically manages SSL certificates via Cloudflare DNS challenge:

```yaml
certificatesResolvers:
  cloudflare:
    acme:
      email: ${EMAIL}
      storage: acme.json
      dnsChallenge:
        provider: cloudflare
        resolvers:
          - "1.1.1.1:53"
          - "1.0.0.1:53"
```

### Wildcard Certificate

The configuration requests a wildcard certificate for the domain:

```yaml
tls:
  certresolver: cloudflare
  domains[0].main: ${DOMAIN}
  domains[0].sans: *.${DOMAIN}
```

## Backup Strategy

### What to Back Up

| Component        | Location                  | Method               |
|------------------|---------------------------|----------------------|
| Docker configs   | `docker/*/config/`        | Git + rsync to NAS   |
| Container data   | Docker volumes            | Scheduled rsync      |
| Traefik certs    | `docker/proxy/config/acme.json` | Git (encrypted) |
| Environment files| `docker/*/.env`           | Encrypted backup     |

### Restore Process

1. Clone repository
2. Restore `.env` files from encrypted backup
3. Restore `acme.json` (or let Traefik regenerate)
4. `docker compose up -d` in each stack directory
