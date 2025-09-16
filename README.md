# Media Stack — Modernized Docker Compose Setup

A fully automated media server stack with VPN-protected downloading, automated content management, and secure remote streaming.

## Key improvements (what this stack aims to provide)

- Organization & structure with clear sections and consistent naming (kebab-case for containers).
- Reduced redundancy using YAML anchors for shared config (UIDs, timezone, restart policy).
- Health checks to ensure services are running properly.
- Resource limits to prevent runaway containers.
- Network isolation for security and clean service separation.
- Startup dependencies (e.g., download clients wait until VPN is up).
- Labels ready for integrations like Watchtower (auto-updates) and Traefik (reverse proxy).
- Improved scripting (e.g., slskd wrapper with better error handling, logging, and clean shutdown).
- Well-documented `.env` with required and optional settings.

## Stack components

| Service    | Purpose                | Host Port | VPN Protected | Tag      |
|------------|------------------------|----------:|:-------------:|----------|
| qBittorrent | Torrent client         | 8080      | ✅            | latest   |
| slskd      | Soulseek client        | 8585      | ✅            | latest   |
| Sonarr     | TV show management     | 8181      | ❌            | latest   |
| Radarr     | Movie management       | 8282      | ❌            | latest   |
| Lidarr     | Music management       | 8383      | ❌            | nightly  |
| Readarr    | Book management        | 8484      | ❌            | nightly  |
| Prowlarr   | Indexer management     | 9696      | ❌            | develop  |
| Picard     | Music tagger           | 8586      | ❌            | 2.13.3   |
| Navidrome  | Music streaming        | 8686      | ❌            | latest   |
| Cloudflared | Remote access tunnel  | N/A       | ❌            | latest   |

Note: "Host Port" is the port on your machine. Many apps use different internal container ports (e.g., Sonarr uses 8989 internally).

## Quick start

### 1) Prerequisites

```bash
# Install Docker and Docker Compose Plugin
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"

# Log out and back in for the new group to take effect.
# Then get your user/group IDs for the .env file:
id
```

### 2) Set up the project

```bash
# Create the stack directory
mkdir -p ~/media-stack
cd ~/media-stack

# Create directories
mkdir -p scripts data/{config,media/{downloads,tv,movies,music,books}}

# Place these files in ~/media-stack:
# - docker-compose.yml
# - example.env
# - scripts/slskd-wrapper.sh

# Make the wrapper executable
chmod +x scripts/slskd-wrapper.sh

# Create your .env
cp example.env .env

# Edit your .env with correct values
nano .env
# IMPORTANT: Update DATA_ROOT, PUID, PGID, and your VPN keys.
# OPTIONAL: Set CLOUDFLARE_TUNNEL_TOKEN for remote access via Cloudflare Tunnel.
```

### 3) VPN setup

Obtain a WireGuard configuration from your VPN provider (e.g., ProtonVPN, Mullvad). Extract the private keys you'll use for the containers protected by VPN and add them to `.env`:

```env
TORRENT_WIREGUARD_PRIVATE_KEY="your_key_for_torrents_goes_here"
SLSKD_WIREGUARD_PRIVATE_KEY="your_key_for_slskd_goes_here"
```

### 4) Launch the stack

```bash
# Start all services
docker compose up -d

# See status
docker compose ps

# Tail all logs
docker compose logs -f

# Tail a specific service (example: vpn-torrents)
docker compose logs -f vpn-torrents

# Stop and remove services
docker compose down
```

## Configuration

### Connect Sonarr to qBittorrent

- Open Sonarr: http://localhost:8181
- Go to Settings → Download Clients → Add (+) → qBittorrent
  - Host: vpn-torrents (Docker service name)
  - Port: 8080

### Add indexers via Prowlarr

- Open Prowlarr: http://localhost:9696
- Add your indexers
- Go to Settings → Apps → Add Application (+) → Sonarr
  - Prowlarr Server: http://prowlarr:9696
  - Sonarr Server: http://sonarr:8989 (use internal container port)
- Repeat for Radarr, Lidarr, and Readarr with their service names and internal ports.

### Media paths

Configure the same container paths across your apps:

- Downloads: `/downloads`
- Media: `/tv`, `/movies`, `/music`, `/books`

## Security and remote access

### Network isolation

The stack uses multiple Docker networks to restrict communication:
- A VPN network (e.g., `vpn_torrents`) isolates traffic for qBittorrent and slskd.
- A media network links the *arr services, indexers, and supporting apps as needed.
This reduces blast radius and enforces least privilege between services.

### Cloudflare Tunnel (optional)

Use Cloudflare Tunnel to expose services (e.g., Navidrome) without opening router ports:

1. Create a tunnel and obtain a token from Cloudflare Zero Trust dashboard.
2. Add the token to `CLOUDFLARE_TUNNEL_TOKEN` in `.env`.
3. In Cloudflare, point your hostname (e.g., `music.yourdomain.com`) to `http://navidrome:4533`.
4. Start the stack. The `cloudflared-navidrome` service will connect automatically.

## Monitoring and maintenance

### Health checks

Critical services include health checks. Use `docker compose ps` to verify status. A status of `healthy` indicates the service is functioning.

### Backups

Back up the `data/config` directory regularly. Example script:

```bash
#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="/path/to/backups/media-stack-$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"
cd ~/media-stack

echo "Stopping services..."
docker compose down

echo "Backing up configuration..."
tar -czf "$BACKUP_DIR/configs.tar.gz" data/config/

echo "Restarting services..."
docker compose up -d
```

## Troubleshooting

### Port conflicts

If a host port is in use:

```bash
# Find the process using a port (example: 8080)
sudo lsof -i :8080
```

Change the conflicting port in `.env`, for example:

```env
QBITTORRENT_WEBUI_PORT=8081
```

Then restart:

```bash
docker compose up -d
```

### Permission issues

"Permission denied" usually indicates UID/GID mismatches. You can use the provided one-off service:

```bash
docker compose run --rm init-permissions
```

Or fix from the host:

```bash
sudo chown -R 1000:1000 data/  # Replace 1000:1000 with your PUID:PGID
```

## Resources

- Docker Compose documentation: https://docs.docker.com/compose/
- Gluetun wiki: https://github.com/qdm12/gluetun/wiki
- TRaSH Guides (*arr best practices): https://trash-guides.info/
