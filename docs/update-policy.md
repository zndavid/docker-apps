# Container update policy

This stack intentionally does not apply unattended container updates.

## Why

Automatic replacement of running containers can turn an upstream image regression into an immediate outage. This is especially undesirable for Home Assistant, VPN networking and the media download path.

The stack therefore uses **Diun** to inspect the images used by running Docker containers and send Telegram notifications when a tracked image changes. Diun does not replace or restart the application containers.

LinuxServer.io explicitly recommends Diun for image-update notifications and does not recommend unattended automatic container updates.

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

## Diun behavior

Diun runs once per day at 12:00 local time with up to 10 minutes of jitter. With `TZ=Europe/Vienna`, the normal check window is therefore approximately 12:00-12:10 Austrian local time.

`DIUN_WATCH_RUNONSTARTUP=false` is set deliberately so restarting the NAS or the Diun container at night or in the evening does not trigger an off-schedule update check or notification.

Docker discovery uses `watchByDefault=true`, so running containers are checked without having to label every service individually.

Telegram notifications use:

- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_CHAT_ID`

The first scan does not send notifications, which avoids an initial burst when Diun is first deployed.

## Why Diun instead of Watchtower

Watchtower performed unattended updates. This stack deliberately separates **detection** from **deployment** so an upstream regression does not automatically replace a working Home Assistant, VPN, media server or download client.

## Docker socket note

Diun reads Docker metadata through `/var/run/docker.sock`. The mount is marked read-only at the filesystem level, but Docker daemon access is still security-sensitive. Run this stack only on a trusted host and do not expose the Docker socket over the network.

## Rollback preparation

Before a major application update, back up the corresponding `/share/Config/<service>` directory. For particularly sensitive services, consider pinning a known-good image tag before upgrading and record the previous tag so it can be restored quickly.
