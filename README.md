# Media stack

QNAP Docker Compose stack for Jellyfin, Seerr, Sonarr, Radarr, Prowlarr,
Bazarr and qBittorrent behind Gluetun. It also includes Cloudflare Tunnel,
WUD and the existing Home Assistant service.

Deploy configuration changes from GitHub using **Portainer GitOps polling**:

1. Follow [NAS deployment and migration](docs/nas-deploy.md).
2. Set runtime variables in Portainer using [.env.example](.env.example) as the template.
3. Review changes on a branch, validate them, then merge into `main`.
4. Portainer checks `main` every 5 minutes and applies Compose changes.

No NAS SSH access from GitHub, webhook, Actions runner on the NAS, custom
image build, or repository-relative bind mount is needed. GitHub Actions
only validates the configuration; it cannot access the NAS or runtime secrets.

The ebook services are currently removed. Their existing NAS directories
are retained so they can be restored later from Git history.

- [VPN setup](docs/qbittorrent-gluetun.md)
- [VPN reconnect recovery](docs/qbittorrent-vpn-recovery.md)
- [Image update policy](docs/update-policy.md)

For local validation, with Docker Compose installed:

```bash
docker compose --env-file .env.example config --quiet
```

This checks configuration only; use real values in Portainer for deployment.
