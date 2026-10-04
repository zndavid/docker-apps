# qBittorrent recovery after Gluetun reconnects

Gluetun can recover from a failed VPN healthcheck by rebuilding the VPN tunnel inside the existing container. qBittorrent keeps running in the shared network namespace, but qBittorrent/libtorrent may keep stale peer connections after that internal reconnect and leave torrents in `Stalled` state.

The stack handles this automatically.

## How it works

Gluetun uses its supported `VPN_UP_COMMAND` hook to write a timestamp to:

```text
/gluetun/vpn-up.timestamp
```

The `qbittorrent-recovery` helper watches that marker. On a new VPN-up event it:

1. waits 10 seconds for the rebuilt tunnel to settle;
2. waits until Docker reports Gluetun as healthy;
3. checks that qBittorrent is currently running;
4. restarts only the qBittorrent container.

If qBittorrent was deliberately stopped, the helper leaves it stopped.

The helper has `network_mode: none`. It only receives read-only access to the Gluetun config directory and access to the Docker socket so it can inspect Gluetun and restart qBittorrent.

The watcher shell is embedded in `docker-compose.yml` under the helper's `entrypoint`. There is no repository-relative script mount, build step, or custom image. Shell dollar signs are escaped as `$$` so Compose passes them through to the container.

The Docker socket grants access to the host Docker API even with `network_mode: none`; keep the helper trusted.

## Deploy

For GitOps, follow [NAS deployment](nas-deploy.md) and let Portainer apply the Compose change. Check the helper logs in Portainer after deployment.

For a local Compose deployment only, from the stack directory run:

```bash
docker compose config --quiet
docker compose pull gluetun qbittorrent qbittorrent-recovery
docker compose up -d --force-recreate gluetun qbittorrent qbittorrent-recovery
```

Check the watcher:

```bash
docker logs -f qbittorrent-recovery
```

Normal startup should show that the watcher found the initial marker and armed itself without restarting qBittorrent.

After a later Gluetun VPN reconnect, the expected log sequence is similar to:

```text
Detected Gluetun VPN reconnect; waiting 10s before qBittorrent recovery
Restarting qBittorrent after VPN recovery
qBittorrent restarted successfully
```

## Manual verification

Confirm the marker exists:

```bash
docker exec gluetun cat /gluetun/vpn-up.timestamp
```

Confirm all three containers are running (Portainer Containers or the NAS CLI):

```bash
docker ps --filter name=gluetun --filter name=qbittorrent
```

Do not grant the Docker socket to Gluetun itself. The restart capability remains isolated in the recovery helper.
