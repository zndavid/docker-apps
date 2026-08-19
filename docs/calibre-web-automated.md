# Calibre-Web Automated setup

Calibre-Web Automated (CWA) owns the final ebook library and sits after LazyLibrarian post-processing.

## Container layout

- Web UI: `http://<NAS-IP>:8083` (or `CWA_WEBUI_PORT`)
- Config: `/share/Config/calibre-web-automated` -> `/config`
- Ingest: `/share/Media/Calibre-Ingest` -> `/cwa-book-ingest`
- Calibre library: `/share/Media/Books` -> `/calibre-library`

CWA removes files from `/cwa-book-ingest` after successful processing. Do not point qBittorrent's active download directory or LazyLibrarian's persistent `/books` library directly at this ingest mount.

LazyLibrarian keeps its own library at `/share/Media/LazyLibrarian` -> `/books` and uses `/share/Media/Calibre-Ingest` -> `/cwa-ingest` only as a handoff copy directory.

## Prepare directories

```bash
mkdir -p \
  /share/Config/calibre-web-automated \
  /share/Media/LazyLibrarian \
  /share/Media/Calibre-Ingest \
  /share/Media/Books
```

Before first start, inspect `/share/Media/Books`. If it contains books from a previous direct LazyLibrarian setup but does not contain a Calibre `metadata.db`, treat those as migration input rather than as an already-managed Calibre library.

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

LazyLibrarian and CWA share only the handoff directory:

```text
LazyLibrarian /books
        |
        | persistent LL library
        v
/share/Media/LazyLibrarian
        |
        | Calibre Books Auto Add copy
        v
LazyLibrarian /cwa-ingest
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

This separation is intentional: CWA exclusively owns the final Calibre library and `metadata.db`, while LazyLibrarian keeps its own stable library root for post-processing and library scans.

## Recommended first settings

For the initial validation, keep the workflow simple:

- Leave automatic conversion enabled with EPUB as the target format.
- Enable EPUB fixing if desired after the basic ingest test succeeds.
- Do not enable automatic Send-to-eReader until ingest is confirmed working.
- Configure metadata providers only after the base library is stable.

## Validation

Use a legally obtained ebook and confirm:

1. LazyLibrarian post-processes it into `/books` and keeps the local library copy.
2. LazyLibrarian's Calibre Auto Add handoff places an ebook copy in `/cwa-ingest`.
3. The handoff file appears in `/share/Media/Calibre-Ingest`.
4. CWA detects and processes it.
5. The ingest copy disappears after successful processing.
6. The book appears in the CWA web UI and in `/share/Media/Books` as part of the managed Calibre library.

After this works, configure CWA's Auto-Send to eReader feature for the Kindle delivery step.
