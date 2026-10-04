# QNAP deployment with Portainer GitOps

Portainer on the NAS pulls Compose from GitHub over HTTPS. Routine deployment
needs no inbound NAS port, GitHub-to-NAS SSH connection, webhook or self-hosted
Actions runner. Use Docker Standalone, not Swarm.

## Runtime variables and files

Set runtime values in the Portainer stack's **Environment variables** section.
Import your real NAS `.env` with **Load variables from .env file**, or enter the
values manually. Use `.env.example` only as a template; do not deploy its
placeholder keys. Portainer's Git clone does not automatically read the old
`/share/CACHEDEV1_DATA/Config/stack/.env`.

Compose references the variables explicitly, so no `env_file` or `stack.env`
needs to be committed or mounted. Keep the original `.env` and a Portainer
backup in a private location. For default WireGuard deployment, supply:

- `TZ`, `PUID`, `PGID`
- `MEDIA_STACK_DATA_ROOT` after [storage migration](storage-migration.md)
- `GLUETUN_WIREGUARD_PRIVATE_KEY`
- `WUD_ADMIN_USER`, `WUD_ADMIN_PASSWORD` for mandatory WUD v9 authentication
- `CLOUDFLARE_TUNNEL_TOKEN`
- `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`

The other settings/defaults are documented in `.env.example`. If using
OpenVPN, set `GLUETUN_VPN_TYPE=openvpn` and supply NordVPN service credentials
in `NORDVPN_USER` and `NORDVPN_PASS`.

Application configs keep their existing `/share/Config/...` paths. Media and
downloads move to the shared root in [storage migration](storage-migration.md).
Complete that migration before normal deployment. The recovery shell is
embedded in Compose, so **Enable relative path volumes** is unnecessary. No
custom recovery image or NAS-side build is required.

## One-time migration

Expect an outage while handing over the old stack and migrating storage;
the duration depends on whether files can be hardlinked or need copying.
The old project includes Home Assistant and Cloudflare Tunnel. Work over the
NAS LAN; a connection through the stack's tunnel will drop.

1. Leave polling disabled until migration is verified. Back up the current
   NAS Compose file, `.env`, Portainer data and application configurations,
   including WUD before its v9 database migration. Merge the reviewed changes
   into `main` only with deployment under this maintenance procedure. Keep the
   **old Compose file including the ebook services** until migration succeeds
   so it can remove the old book containers and support rollback.
2. Check existing ownership before stopping anything:

   ```bash
   docker inspect gluetun --format '{{index .Config.Labels "com.docker.compose.project"}}'
   ```

   The expected project is `media-stack`. Check Portainer's Stacks list too.
   If the current project name differs, use that actual name when stopping it.
3. Prepare the Git source and environment values in Portainer using the
   settings below. Do not deploy a second copy while the old containers exist:
   their fixed container names and host ports would collide.
4. If Portainer owns the old stack, remove that old stack through Portainer
   after backing up its definition and variables. If it was deployed directly
   with Compose, stop it from the **old NAS checkout**, for example:

   ```bash
   cd /share/CACHEDEV1_DATA/Config/stack
   docker compose -p media-stack down --remove-orphans
   ```

   Use the verified project name. Do not add `--volumes` or delete NAS
   directories. This removes old containers/network, including LazyLibrarian
   and Calibre-Web Automated, while retaining their bind-mounted data.
   Stopping containers alone does not release their fixed names.
5. With the old containers stopped, prepare the shared data tree using
   [storage migration](storage-migration.md). Set `MEDIA_STACK_DATA_ROOT` and
   a real `WUD_ADMIN_PASSWORD` in Portainer. Deploy the separate
   [Home Assistant stack](homeassistant-deploy.md) so media changes no longer
   control its lifecycle.
6. Deploy the Git-backed media stack with the name `media-stack` using
   `docker-compose.yml` only (plus the optional Jellyfin GPU override after
   device checks). Keep downloads/imports paused until all application paths
   point at the new `/data` layout. Do not use the old rsync deployment.
7. Verify storage, VPN, [WUD](update-policy.md) and the checks below. Import
   the [corrected Radarr custom formats](radarr-custom-formats.md) separately.
   Enable polling only afterwards. In Prowlarr disable the
   existing LazyLibrarian application entry if present. In qBittorrent pause
   unwanted book downloads without deleting files.

The existing book library and config directories are retained. Removing
services from Git alone does not stop containers managed by the old deployment;
the ownership transition above handles that explicitly.

## Portainer settings

Select the NAS Docker environment, then **Stacks -> Add stack -> Git Repository**.
Newer versions may ask you to add/select a Git repository **Source** first.

| Setting | Value |
| --- | --- |
| Stack name | `media-stack` |
| Repository URL | `https://github.com/zndavid/docker-apps` |
| Repository reference | `refs/heads/main` (or select `main` in the branch picker) |
| Compose path | `docker-compose.yml` |
| Additional paths | Empty by default; optional `docker-compose.jellyfin-gpu.yml` after device checks |
| GitOps updates | Enable after verifying the initial deployment |
| Mechanism | Polling |
| Fetch interval | `5m` / 5 minutes |
| Re-pull image | Off |
| Force redeployment | Off |
| Enable relative path volumes | Off, if shown |
| TLS verification | Enabled; leave Skip TLS verification off |

The repository is public, so Git authentication is unnecessary. If it becomes
private, use repository-scoped read-only credentials in Portainer's Git source;
do not place them in Compose or `.env.example`.

Portainer compares the branch commit hash. A changed commit triggers stack
processing even for documentation-only changes; with force redeployment off,
unchanged services ordinarily stay running. Re-pull off avoids deliberately
refreshing every floating image on each configuration deployment. Missing
images still need to be downloaded. WUD scans and sends notifications; its
Docker updater now requires manual execution. See [update policy](update-policy.md).

## Verify deployment

In Portainer, confirm:

- Gluetun is healthy and qBittorrent runs in its network namespace.
- `qbittorrent-recovery` logs say `Recovery watcher armed`.
- Sonarr/Radarr can reach qBittorrent at `gluetun:18080` (or your configured port).
- Jellyfin sees the migrated libraries at `/data/media/...`; Seerr is available.
- Home Assistant is available from its independent `homeassistant-stack`.
- The application-user hardlink probe passes and real Arr imports hardlink.
- WUD login works, the `docker.auto` trigger is active, and Gluetun/qBittorrent remain excluded from individual automatic updates.
- LazyLibrarian and Calibre-Web Automated containers are absent.
- The stack source remains Git and the environment values are retained.

Verify [VPN egress](qbittorrent-gluetun.md#verify-vpn-egress) on the NAS before
using the torrent client. Keep Portainer and the Docker socket accessible
only through your existing trusted admin access.

## Changes and rollback

Create a branch, review the diff and wait for **Validate stack** before merging
into `main`. Polling operates independently of CI; it does not wait for a failed
check on a commit already in `main`. Branch protection requiring that check can
be configured separately in GitHub.

Before merging any Gluetun configuration/image change, bump the shared
`x-vpn-stack-revision` so both VPN namespace members change configuration. CI
rejects an unchanged revision on a Gluetun diff. Require that check in branch
protection before unattended polling; direct main commits can otherwise deploy
before CI finishes. VPN environment changes made directly in Portainer require
coordinated manual recreation of both containers with polling disabled.

After deployment, check Portainer's status, both container namespaces and VPN
egress. Follow [update policy](update-policy.md) for image updates.

For configuration rollback, revert the offending commit via a reviewed PR and
let polling apply it, or use **Pull and redeploy** after the revert. This does
not restore mutable image tags or undo database migrations; pin known-good
images and restore compatible config backups when necessary.

If migration fails, remove both partially created Git stacks before starting
the saved old Compose definition, which also owns Home Assistant. Restore
pre-migration app configs/WUD backups if paths or databases changed. Old data
must still be present for that rollback. Keep one owner at a time.

## References

- [Portainer Git stacks and GitOps settings](https://docs.portainer.io/user/docker/stacks/add)
- [How Portainer detects updates](https://docs.portainer.io/faqs/troubleshooting/stacks-deployments-and-updates/how-do-automatic-updates-for-stacks-applications-work)
- [Relative mount limitations](https://docs.portainer.io/faqs/troubleshooting/stacks-deployments-and-updates/empty-relative-bind-mounts)
- [Compose dollar escaping](https://docs.docker.com/reference/compose-file/interpolation/)
