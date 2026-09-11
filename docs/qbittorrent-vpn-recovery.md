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

## Deploy

Sync the repository to the NAS, then from the stack directory run:

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

Confirm both services are running:

```bash
docker compose ps gluetun qbittorrent qbittorrent-recovery
```

Do not grant the Docker socket to Gluetun itself. The restart capability remains isolated in the recovery helper.
