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
- `GLUETUN_WIREGUARD_PRIVATE_KEY`
- `CLOUDFLARE_TUNNEL_TOKEN`
- `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`

The other settings/defaults are documented in `.env.example`. If using
OpenVPN, set `GLUETUN_VPN_TYPE=openvpn` and supply NordVPN service credentials
in `NORDVPN_USER` and `NORDVPN_PASS`.

All application data keeps its existing absolute `/share/Config/...`,
`/share/Media/...` and `/share/Downloads` paths. The recovery shell is embedded
in Compose, so **Enable relative path volumes** is unnecessary. No custom
recovery image or NAS-side build is required.

## One-time migration

Expect a short outage, including Home Assistant and Cloudflare Tunnel,
which currently belong to the same project. Work over the NAS LAN; a
connection through the stack's tunnel will drop.

1. Merge the reviewed changes into `main`. Back up the current NAS Compose
   file, `.env`, Portainer data and application configurations. Keep the
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
5. Deploy the Git-backed stack in Portainer with the name `media-stack`.
   Stop using the old rsync/Compose deployment alongside it.
6. Verify the checks below, then enable polling. In Prowlarr disable the
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
| Additional paths | Empty |
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
images still need to be downloaded. WUD's image policy remains separate.

## Verify deployment

In Portainer, confirm:

- Gluetun is healthy and qBittorrent runs in its network namespace.
- `qbittorrent-recovery` logs say `Recovery watcher armed`.
- Sonarr/Radarr can reach qBittorrent at `gluetun:18080` (or your configured port).
- Jellyfin sees the existing libraries; Seerr and Home Assistant are available.
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

After merging, check Portainer's stack status and container logs. For Gluetun
changes, verify qBittorrent was also recreated into the current namespace and
verify VPN egress. Follow [update policy](update-policy.md) for image updates.

For configuration rollback, revert the offending commit via a reviewed PR and
let polling apply it, or use **Pull and redeploy** after the revert. This does
not restore mutable image tags or undo database migrations; pin known-good
images and restore compatible config backups when necessary.

If the initial migration fails, remove the partially created Git-backed stack
before starting the saved old Compose configuration. Keep one owner at a time.

## References

- [Portainer Git stacks and GitOps settings](https://docs.portainer.io/user/docker/stacks/add)
- [How Portainer detects updates](https://docs.portainer.io/faqs/troubleshooting/stacks-deployments-and-updates/how-do-automatic-updates-for-stacks-applications-work)
- [Relative mount limitations](https://docs.portainer.io/faqs/troubleshooting/stacks-deployments-and-updates/empty-relative-bind-mounts)
- [Compose dollar escaping](https://docs.docker.com/reference/compose-file/interpolation/)
