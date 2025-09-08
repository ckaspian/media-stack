# Media Stack - Modernized Docker Compose Setup

A fully automated media server stack with VPN-protected downloading, automated content management, and streaming capabilities.

## 🎯 Key Improvements Made

### 1. **Organization & Structure**
- Clear sectioning with visual separators
- Grouped related services logically
- Added comprehensive comments throughout
- Consistent naming conventions (kebab-case for containers)

### 2. **Reduced Redundancy with YAML Anchors**
```yaml
# Before: Repeated environment variables everywhere
environment:
  - PUID=1000
  - PGID=1000
  - TZ=Etc/UTC

# After: Define once, reuse everywhere
x-common-env: &common-env
  PUID: ${PUID:-1000}
  PGID: ${PGID:-1000}
  TZ: ${TZ:-Etc/UTC}
```

### 3. **Enhanced Features**
- ✅ Health checks for all services
- ✅ Resource limits to prevent runaway containers
- ✅ Network isolation for security
- ✅ Dependency management with conditions
- ✅ Labels for future integrations (Watchtower, Traefik)
- ✅ Deploy configurations for resource management

### 4. **Improved Script**
The wrapper script now includes:
- Proper error handling with `set -euo pipefail`
- Colored logging for better visibility
- Port validation
- Timeout mechanisms
- Signal trapping for clean shutdowns

### 5. **Better Configuration**
The `.env` file now features:
- Logical grouping of settings
- Detailed documentation
- Future-ready optional features
- Security considerations

## 📦 Stack Components

| Service | Purpose | Port | VPN Protected | Version |
|---------|---------|------|---------------|---------|
| **qBittorrent** | Torrent client | 8080 | ✅ | latest |
| **slskd** | Soulseek client | 8585 | ✅ | latest |
| **Sonarr** | TV show management | 8181 | ❌ | latest |
| **Radarr** | Movie management | 8282 | ❌ | latest |
| **Lidarr** | Music management | 8383 | ❌ | 2.14.1-nightly |
| **Readarr** | Book management | 8484 | ❌ | 0.4.19-nightly |
| **Prowlarr** | Indexer management | 9696 | ❌ | 2.1.0-develop |
| **Navidrome** | Music streaming | 8686 | ❌ | latest |

## 🚀 Quick Start

### 1. Prerequisites
```bash
# Install Docker and Docker Compose
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Get your user/group IDs
id
```

### 2. Configuration
```bash
# Clone or create the stack directory
mkdir -p ~/media-stack
cd ~/media-stack

# Create directory structure
mkdir -p scripts data/{config,downloads,media/{tv,movies,music,books}}

# Copy the files
# - docker-compose.yml
# - .env
# - scripts/slskd-wrapper.sh

# Make wrapper executable
chmod +x scripts/slskd-wrapper.sh

# Edit .env file
nano .env
# Update: DATA_ROOT, PUID, PGID, VPN keys
```

### 3. VPN Setup
1. Get WireGuard configuration from your VPN provider (ProtonVPN, Mullvad, etc.)
2. Extract the private keys
3. Update `.env` with your keys:
```bash
TORRENT_WIREGUARD_PRIVATE_KEY="your_key_here"
SLSKD_WIREGUARD_PRIVATE_KEY="your_other_key_here"
```

### 4. Launch the Stack
```bash
# Start all services
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f

# Stop all services
docker compose down
```

## 🔧 Configuration Examples

### Connect Sonarr to qBittorrent
1. Open Sonarr: `http://localhost:8181`
2. Settings → Download Clients → Add → qBittorrent
3. Host: `vpn-torrents` (internal Docker network name)
4. Port: `8080`

### Add Indexers via Prowlarr
1. Open Prowlarr: `http://localhost:9696`
2. Add indexers
3. Settings → Apps → Add Sonarr/Radarr/Lidarr
4. Use service names as hosts (e.g., `sonarr`, `radarr`)

### Configure Media Paths
All *arr apps should use these paths:
- Downloads: `/downloads`
- Media: `/tv`, `/movies`, `/music`, `/books`

## 🛡️ Security Features

### Network Isolation
```yaml
networks:
  vpn_torrents:   # Only for torrent traffic
  vpn_slskd:      # Only for Soulseek traffic
  media_network:  # Internal communication between *arr apps
  frontend:       # Web UI access
```

### Resource Limits Example
```yaml
deploy:
  resources:
    limits:
      memory: 2G      # Maximum memory
    reservations:
      memory: 512M    # Minimum guaranteed
```

## 📊 Monitoring & Maintenance

### Health Checks
All services include health checks:
```bash
# Check health status
docker compose ps

# Manual health check
docker exec sonarr wget --spider -q http://localhost:8989
```

### Logs Management
```bash
# View specific service logs
docker compose logs -f sonarr

# Limit log size in docker-compose.yml
logging:
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"
```

### Backup Strategy
```bash
# Backup script example
#!/bin/bash
BACKUP_DIR="/backup/media-stack-$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Stop stack
docker compose down

# Backup configs
tar -czf "$BACKUP_DIR/configs.tar.gz" data/config/

# Restart stack
docker compose up -d
```

## 🔍 Troubleshooting

### Slskd Exits with Code 0
If slskd keeps restarting:
```bash
# Option 1: Use the fixed wrapper script
cp scripts/slskd-wrapper-fixed.sh scripts/slskd-wrapper.sh

# Option 2: Disable the wrapper entirely
# In docker-compose.yml, comment out:
# entrypoint: ["/bin/sh", "/wrapper.sh"]
# And uncomment:
# command: ["dotnet", "slskd.dll"]

# Then restart
docker compose up -d slskd --force-recreate

# Check logs
docker compose logs -f slskd
```

### VPN Connection Issues
```bash
# Check VPN status
docker exec vpn-torrents cat /gluetun/forwarded_port

# View Gluetun logs
docker compose logs -f vpn-torrents
```

### Port Conflicts
```bash
# Find what's using a port
sudo lsof -i :8080

# Change port in .env file
QBITTORRENT_WEBUI_PORT=8081
```

### Permission Issues
```bash
# Fix permissions
docker compose run --rm init-permissions

# Or manually
sudo chown -R $(id -u):$(id -g) data/
```

## 🎨 Optional Enhancements

### Add Jellyfin Media Server
Uncomment the Jellyfin section in `docker-compose.yml`:
```yaml
jellyfin:
  <<: *restart-policy
  image: jellyfin/jellyfin:latest
  # ... rest of configuration
```

### Enable Automatic Updates
Add Watchtower to automatically update containers:
```yaml
watchtower:
  image: containrrr/watchtower
  container_name: watchtower
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock
  command: --cleanup --schedule "0 0 4 * * *"
  restart: unless-stopped
```

### Add Reverse Proxy
Use Traefik or Nginx Proxy Manager for SSL and domain access:
```yaml
traefik:
  image: traefik:latest
  # Configuration for SSL, domains, etc.
```

## 📚 Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Gluetun Wiki](https://github.com/qdm12/gluetun/wiki)
- [TRaSH Guides](https://trash-guides.info/) - Best practices for *arr setup
- [Awesome-Selfhosted](https://github.com/awesome-selfhosted/awesome-selfhosted)

## 🤝 Contributing

Feel free to suggest improvements or report issues. This stack is designed to be modular and extensible!

---
*Last Updated: 2025*
