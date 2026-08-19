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
/share/Config/lazylibrarian
/share/Media/LazyLibrarian
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
- copies the repository tree;
- excludes `.git`, `.env`, and desktop metadata files;
- deliberately does **not** use `--delete`, so NAS-only runtime files are preserved;
- never overwrites the NAS runtime `.env` from a developer checkout.

You can override the destination without editing the script:

```bash
NAS_USER=admin \
NAS_HOST=192.168.178.78 \
NAS_PATH=/share/CACHEDEV1_DATA/Config/stack \
bash scripts/rsync-to-nas.sh
```

## Windows deployment without rsync

From PowerShell, create a temporary tar archive from the repository root, copy it over SSH, extract it on the NAS, then remove the temporary files. The archive excludes `.git` and `.env` so the NAS runtime `.env` is preserved.

```powershell
cd C:\Users\CzinkDav\Downloads\docker-apps

tar.exe --exclude=.git --exclude=.env -cf ..\docker-apps-deploy.tar .
scp ..\docker-apps-deploy.tar admin@192.168.178.78:/tmp/docker-apps-deploy.tar
ssh admin@192.168.178.78 "mkdir -p /share/CACHEDEV1_DATA/Config/stack && tar -xf /tmp/docker-apps-deploy.tar -C /share/CACHEDEV1_DATA/Config/stack && rm -f /tmp/docker-apps-deploy.tar"
Remove-Item ..\docker-apps-deploy.tar
```

Do not pipe the binary tar stream directly through Windows PowerShell into `ssh`; use the temporary archive + `scp` method above.

## Apply the ebook services on the NAS

After syncing:

```bash
ssh admin@192.168.178.78
cd /share/CACHEDEV1_DATA/Config/stack

mkdir -p \
  /share/Config/calibre-web-automated \
  /share/Config/lazylibrarian \
  /share/Media/LazyLibrarian \
  /share/Media/Calibre-Ingest \
  /share/Media/Books

docker compose config --quiet
docker compose pull calibre-web-automated lazylibrarian
docker compose up -d --force-recreate calibre-web-automated lazylibrarian
docker compose ps calibre-web-automated lazylibrarian
```

Verify the LazyLibrarian mounts:

```bash
docker exec lazylibrarian sh -c 'ls -lad /books /cwa-ingest'
```

Then configure LazyLibrarian:

- **Settings -> Processing**
  - `Download Directories`: `/downloads/books`
  - `eBook Library Folder`: `/books`
  - `Keep original files`: enabled
- **Settings -> Importing -> Calibre**
  - `Calibre Books Auto Add Directory`: `/cwa-ingest`
  - `Keep a copy of the book in the local library`: enabled
  - `Only add eBook, not opf or jpg`: enabled
  - `Calibredb import program`: blank
  - `Use Calibre Content Server`: disabled

Calibre-Web Automated is available on port `8083` unless `CWA_WEBUI_PORT` is changed in `.env`.
