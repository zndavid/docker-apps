# Calibre-Web Automated setup

Calibre-Web Automated (CWA) owns the final ebook library and sits after LazyLibrarian post-processing.

## Container layout

- Web UI: `http://<NAS-IP>:8083` (or `CWA_WEBUI_PORT`)
- Config: `/share/Config/calibre-web-automated` -> `/config`
- Ingest: `/share/Media/Calibre-Ingest` -> `/cwa-book-ingest`
- Calibre library: `/share/Media/Books` -> `/calibre-library`

CWA removes files from `/cwa-book-ingest` after successful processing. Do not point qBittorrent's active download directory directly at the ingest mount.

## Prepare directories

```bash
mkdir -p \
  /share/Config/calibre-web-automated \
  /share/Media/Calibre-Ingest \
  /share/Media/Books
```

Before first start, inspect `/share/Media/Books`. If it contains books from the previous direct LazyLibrarian setup but does not contain a Calibre `metadata.db`, treat those as migration input rather than as an already-managed Calibre library.

## Start CWA

```bash
docker compose pull calibre-web-automated
docker compose up -d calibre-web-automated
docker compose logs -f calibre-web-automated
```

Then open:

```text
http://<NAS-IP>:8083
```

CWA can create a fresh Calibre library at `/calibre-library` when no existing Calibre library is present.

## Ingest workflow

LazyLibrarian's `/books` mount points to the same NAS directory that CWA sees as `/cwa-book-ingest`:

```text
LazyLibrarian /books
        |
        v
/share/Media/Calibre-Ingest
        |
        v
CWA /cwa-book-ingest
        |
        v
CWA /calibre-library
        |
        v
/share/Media/Books
```

This separation is intentional: CWA exclusively owns the final Calibre library and `metadata.db`.

## Recommended first settings

For the initial validation, keep the workflow simple:

- Leave automatic conversion enabled with EPUB as the target format.
- Enable EPUB fixing if desired after the basic ingest test succeeds.
- Do not enable automatic Send-to-eReader until ingest is confirmed working.
- Configure metadata providers only after the base library is stable.

## Validation

Use a legally obtained ebook and confirm:

1. LazyLibrarian copies/post-processes it into `/books`.
2. The file appears in `/share/Media/Calibre-Ingest`.
3. CWA detects and processes it.
4. The ingest copy disappears after successful processing.
5. The book appears in the CWA web UI and in `/share/Media/Books` as part of the managed Calibre library.

After this works, configure CWA's Auto-Send to eReader feature for the Kindle delivery step.
