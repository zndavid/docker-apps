# QNAP deployment with rsync

The NAS does not need Git installed. Sync the repository contents over SSH with the helper script and keep the runtime `.env` on the NAS.

## Default target

The helper defaults to the current QNAP deployment location:

```text
admin@192.168.178.78:/share/CACHEDEV1_DATA/Config/stack/
```

On this NAS, `/share/Config` points into `CACHEDEV1_DATA`, so this is the physical path behind the stack directory.

The media paths used by Compose stay on the existing shares:

```text
/share/Config/calibre-web-automated
/share/Media/Calibre-Ingest
/share/Media/Books
```

## Sync

From the repository root, run:

```bash
bash scripts/rsync-to-nas.sh
```

The script:

- creates `/share/CACHEDEV1_DATA/Config/stack` if needed;
- copies the full repository tree, including dotfiles such as a local `.env` when present;
- excludes `.git` and desktop metadata files;
- deliberately does **not** use `--delete`, so an existing NAS-only `.env` is not removed when the local checkout does not contain one.

You can override the destination without editing the script:

```bash
NAS_USER=admin \
NAS_HOST=192.168.178.78 \
NAS_PATH=/share/CACHEDEV1_DATA/Config/stack \
bash scripts/rsync-to-nas.sh
```

## Apply the stack on the NAS

After syncing:

```bash
ssh admin@192.168.178.78
cd /share/CACHEDEV1_DATA/Config/stack
mkdir -p \
  /share/Config/calibre-web-automated \
  /share/Media/Calibre-Ingest \
  /share/Media/Books

docker compose pull calibre-web-automated lazylibrarian
docker compose up -d calibre-web-automated lazylibrarian
```

Calibre-Web Automated is then available on port `8083` unless `CWA_WEBUI_PORT` is changed in `.env`.
