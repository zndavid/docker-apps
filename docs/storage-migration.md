# Shared storage and hardlinks

The target layout is one existing NAS directory, normally `/share/MediaStack`,
containing `torrents/`, `media/movies/` and `media/tv/`. Set its absolute path in
`MEDIA_STACK_DATA_ROOT` only after preparing the data. Downloads and libraries
must be on the same filesystem; sibling symlinks to other shares/volumes do
not provide that guarantee. The Compose bind mounts refuse to create a missing
source directory silently.

| Application | Host path under the shared root | Container path |
| --- | --- | --- |
| qBittorrent | `torrents/` | `/data/torrents` |
| Radarr / Sonarr | Entire shared root | `/data` |
| Bazarr | `media/` | `/data/media` |
| Jellyfin | `media/` (read only) | `/data/media` |

Arr imports now cross directories within a single `/data` mount, rather than
crossing separate `/downloads` and `/movies` or `/tv` mounts. Hardlinks also
require appropriate app-user permissions and **Use Hardlinks instead of Copy**
in Radarr/Sonarr Media Management. Existing duplicate files are not automatically
consolidated by this change.

## Prepare before enabling GitOps

Keep polling off during migration. Disable Arr RSS/automatic import and pause
qBittorrent torrents. Back up app configurations, including qBittorrent resume
data and Radarr/Sonarr databases. Stop the old project as described in
[NAS deployment](nas-deploy.md) before copying live files. Do not delete the old
shares or replace QNAP's managed share symlinks.

Create the new `MediaStack` share/directory on the same NAS volume as the current
files. Resolve the existing paths and check their filesystem device numbers:

```bash
readlink -f /share/Downloads
readlink -f /share/Media/Movies
readlink -f /share/Media/Series
stat -c '%d %n' /share/Downloads/. /share/Media/Movies/. /share/Media/Series/. /share/MediaStack/.
```

Equal device numbers are a preliminary check; also check for nested mounts and
symlinks in the source trees. The definitive test is creating a hardlink across
the actual destination directories. If sources reside on different filesystems,
copy them into the single destination volume instead and budget space for the
copy. Do not assume a move between volumes is atomic.

For the default layout, create empty destination directories and grant the
configured `PUID`/`PGID` write access using QNAP's permission controls:

```bash
mkdir -p /share/MediaStack/torrents /share/MediaStack/media/movies /share/MediaStack/media/tv
```

## Copy without deleting the old trees

Use these source/destination mappings; preserve subdirectory and category names:

| Old host path | New host path | Old container path | New container path |
| --- | --- | --- | --- |
| `/share/Downloads/` | `/share/MediaStack/torrents/` | `/downloads` | `/data/torrents` |
| `/share/Media/Movies/` | `/share/MediaStack/media/movies/` | `/movies` | `/data/media/movies` |
| `/share/Media/Series/` | `/share/MediaStack/media/tv/` | `/tv` | `/data/media/tv` |

On the same filesystem, rsync `--link-dest` can populate an **empty** destination
with hardlinks to unchanged source files, reducing migration space. First run
with `--dry-run`; inspect the result before repeating without that flag:

```bash
rsync -aH --dry-run --link-dest="$(readlink -f /share/Downloads)" /share/Downloads/ /share/MediaStack/torrents/
rsync -aH --dry-run --link-dest="$(readlink -f /share/Media/Movies)" /share/Media/Movies/ /share/MediaStack/media/movies/
rsync -aH --dry-run --link-dest="$(readlink -f /share/Media/Series)" /share/Media/Series/ /share/MediaStack/media/tv/
```

There is intentionally no `--delete`. Check free space first: rsync can still
copy files when linking is impossible or attributes do not match. If you need
independent migration copies, omit `--link-dest`; budget the additional space.
Hardlinked old/new trees share file content and are **not independent backups**.
Do not run both application stacks or perform recursive permission changes on
one tree while assuming the other is isolated.

Validate counts, sizes and samples, and compare a known source/destination file's
`stat -c '%d:%i %h %n'` output when using `--link-dest`. Do not resume applications
until the new tree is complete.

## Update application paths in a controlled transition

For the first deployment, add `docker-compose.legacy-paths.yml` to Portainer's
**Additional paths**. This temporary override exposes the old container paths
as aliases into the **new** data tree. It lets existing configs see their files
while you change paths; imports through old aliases still lack the desired
single-mount behavior. Keep automatic imports/downloads paused during this stage.

1. qBittorrent: update the default save path to `/data/torrents`, the incomplete
   path if enabled, and all category save paths. For example, the existing
   `radarr` and `sonarr` categories can point to `/data/torrents/movies` and
   `/data/torrents/tv`. Preserve each existing torrent's relative location;
   change `/downloads/...` to `/data/torrents/...` using **Set location**. The
   temporary aliases point to the same data; verify one paused torrent first,
   then recheck after relocation. Do not start a second download of the data.
2. Radarr: add `/data/media/movies` as a root folder. Select movies in the movie
   editor and change their root to it, choosing **not to move files** because
   migration already populated the destination. Remove the old root after
   verifying paths. Sonarr: do the equivalent with `/data/media/tv`.
3. Remove obsolete Remote Path Mappings for this local qBittorrent client;
   qBittorrent and Arr now agree on `/data/torrents/...`. Preserve mappings for
   unrelated external downloaders. Enable **Use Hardlinks instead of Copy**.
4. Bazarr: refresh the Radarr/Sonarr library paths, and update/remove old
   `/movies` or `/tv` path mappings; paths should match `/data/media/...`.
5. Jellyfin: update existing library folders from `/data/movies` and
   `/data/tvshows` to `/data/media/movies` and `/data/media/tv`, then scan the
   libraries. Keep the original library definitions and verify metadata/watch
   status using the config backup if necessary.
6. Remove `docker-compose.legacy-paths.yml` from Additional paths and redeploy.
   Confirm no old container paths remain in app settings, existing torrent
   locations, library roots or mappings before resuming automation.

## Verify hardlinks as the application user

On the NAS, run the repository helper (this is a manual check, not a deployment
file dependency):

```bash
sh scripts/check-hardlinks.sh
```

It executes a probe inside Radarr as LinuxServer's `abc` user, links a temporary
file from `/data/torrents` to `/data/media`, verifies matching device/inode IDs,
and removes only its own probe files/directories. A failure means the storage,
mounts or permissions still need correction.

Finally import one test download and compare both actual torrent/media files:

```bash
docker exec radarr stat -c '%d:%i %h %n' /data/torrents/movies/EXAMPLE.mkv /data/media/movies/EXAMPLE.mkv
```

Substitute real paths. Both entries should have the same device/inode and a link
count of at least two. Check Sonarr too, then resume torrents/imports and enable
polling. Keep old data until playback, seeding and imports have been verified;
any later cleanup is a separate manual decision.

[Reference: TRaSH Docker storage layout](https://trash-guides.info/File-and-Folder-Structure/How-to-set-up/Docker/)
