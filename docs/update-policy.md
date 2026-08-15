# Container update policy

This stack uses **What's up Docker (WUD)** for controlled automatic updates.

## Schedule

WUD checks for new container images once per week:

- Sunday
- 12:00 local time
- `Europe/Vienna`
- with up to about one minute of jitter

The watcher cron is:

```text
0 12 * * 0
```

Startup checks and Docker-event-triggered scans are disabled deliberately. This prevents a NAS/container restart in the evening or at night from causing an unscheduled automatic update.

## What WUD does

When WUD finds an eligible update during the Sunday scan, its Docker trigger automatically:

1. pulls the new image,
2. stops the existing container,
3. recreates it with the existing Docker configuration,
4. starts it again if it was previously running,
5. removes the previous image after a successful replacement.

A Telegram trigger is configured in parallel using:

- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_CHAT_ID`

The WUD Web UI is available on the host loopback interface at `WUD_WEBUI_PORT` (default `13000`).

## Update scope

Most running services are watched and automatically updated on the weekly schedule.

WUD itself is excluded from self-updates and should be upgraded deliberately.

### Gluetun + qBittorrent exception

`gluetun` and `qbittorrent` are the primary torrent stack. They are watched, but excluded from the automatic Docker trigger.

qBittorrent uses:

```text
network_mode: service:gluetun
```

so the two containers share one network namespace. Recreating Gluetun independently could leave a running qBittorrent container attached to the old namespace. For that reason WUD may notify about updates for these two containers, but they should be upgraded together:

```bash
docker compose pull gluetun qbittorrent
docker compose up -d --force-recreate gluetun qbittorrent
```

After updating the pair, confirm Gluetun is healthy and verify the VPN exit IP before relying on qBittorrent again.

## Registry choice

LinuxServer images use their official public GitHub Container Registry references:

```text
ghcr.io/linuxserver/...
```

Public GHCR images can be checked without adding a separate registry credential to WUD, keeping the updater configuration simpler.

## Docker socket note

WUD must have write-capable access to `/var/run/docker.sock` because automatic container replacement requires Docker API mutations. Treat the WUD container as highly privileged infrastructure and do not expose the Docker socket over the network.

## Manual update / recovery

A full manual refresh can be performed from the stack directory:

```bash
docker compose pull
docker compose up -d --remove-orphans
docker compose ps
```

Because qBittorrent shares Gluetun's network namespace, if either of those two services is specifically recreated or upgraded, recreate the pair together and verify VPN egress afterwards.

Before major application changes, keep backups of the corresponding `/share/Config/<service>` directories. If an upstream release causes a regression, pin or restore the previous known-good image and recreate the affected service.
