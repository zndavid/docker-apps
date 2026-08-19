# LazyLibrarian setup

LazyLibrarian is the ebook request/search/download automation layer in the media stack.

## Container layout

- Web UI: `http://<NAS-IP>:5299`
- Config: `/share/Config/lazylibrarian` -> `/config`
- Shared downloads: `/share/Downloads` -> `/downloads`
- Processed-book destination: `/share/Media/Calibre-Ingest` -> `/books`

The `/books` path is intentionally the Calibre-Web Automated ingest directory, not the final Calibre library. LazyLibrarian should post-process completed downloads there; CWA then imports them into the managed Calibre library.

## Start the service

```bash
mkdir -p /share/Config/lazylibrarian /share/Media/Calibre-Ingest
docker compose pull lazylibrarian
docker compose up -d lazylibrarian
docker compose logs -f lazylibrarian
```

## qBittorrent

In LazyLibrarian, open **Settings -> Downloaders** and configure qBittorrent.

Because qBittorrent shares Gluetun's network namespace, use:

- Host: `gluetun`
- Port: `18080` unless `QBITTORRENT_WEBUI_PORT` was changed
- Username/password: the qBittorrent Web UI credentials
- Category/label: `books`

Keep seeding enabled and keep/copy original files so post-processing does not break active torrents.

## Prowlarr

Use Prowlarr's native LazyLibrarian application integration rather than manually creating a generic Torznab URL.

In **Prowlarr -> Settings -> Apps -> LazyLibrarian** use:

- Sync Level: `Full Sync`
- Prowlarr Server: `http://prowlarr:9696`
- LazyLibrarian Server: `http://lazylibrarian:5299`
- API Key: the LazyLibrarian API key from **Settings -> Interface**

Prowlarr will create and maintain the appropriate provider entries in LazyLibrarian.

## Processing destination

Configure LazyLibrarian's ebook destination as:

```text
/books
```

This resolves to `/share/Media/Calibre-Ingest` on the NAS. CWA owns the final `/share/Media/Books` library and its `metadata.db`; LazyLibrarian must not write directly into that library.

Both LazyLibrarian and qBittorrent see the shared download tree under:

```text
/downloads
```

## End-to-end flow

```text
LazyLibrarian
  -> Prowlarr
  -> qBittorrent
  -> /downloads
  -> LazyLibrarian post-processing
  -> /books (Calibre-Ingest)
  -> Calibre-Web Automated
  -> /calibre-library (NAS: /share/Media/Books)
```

Configure e-reader/Kindle delivery in Calibre-Web Automated after this ingest path is validated.

## Initial validation

Test with a legally obtained ebook:

1. Add/request the book in LazyLibrarian.
2. Confirm Prowlarr returns the expected provider result.
3. Confirm qBittorrent receives it with the `books` category.
4. Confirm LazyLibrarian post-processes it into `/books`.
5. Confirm CWA removes it from its ingest directory after successful processing and adds it to the Calibre library.
