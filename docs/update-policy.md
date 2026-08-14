# Container update policy

This stack intentionally does not apply unattended container updates.

## Why

Automatic replacement of running containers can turn an upstream image regression into an immediate outage. This is especially undesirable for Home Assistant, VPN networking and the media download path.

The stack therefore uses **Diun** to inspect the images used by running Docker containers and send Telegram notifications when an image changes. Diun does not replace or restart the application containers.

## Normal update workflow

After receiving a notification, review the affected service and update deliberately:

```bash
docker compose pull
docker compose up -d
docker compose ps
```

For the optional qBittorrent + Gluetun profile:

```bash
docker compose --profile vpn-qbit pull
docker compose --profile vpn-qbit up -d
docker compose --profile vpn-qbit ps
```

Inspect service logs after important updates, especially for:

- `homeassistant`
- `gluetun`
- `qbittorrent`
- `transmission-openvpn`
- `jellyfin`

## Rollback preparation

Before a major application update, back up the corresponding `/share/Config/<service>` directory. For particularly sensitive services, consider pinning a known-good image tag before upgrading and record the previous tag so it can be restored quickly.

## Docker socket note

Diun reads Docker metadata through `/var/run/docker.sock`. The mount is marked read-only at the filesystem level and Diun is used only for image inspection/notification. Access to the Docker daemon is still security-sensitive, so this stack should only run on a trusted host.
