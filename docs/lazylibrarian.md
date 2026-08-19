# LazyLibrarian setup

LazyLibrarian is the ebook request/search/download automation layer in the media stack.

## Container layout

- Web UI: `http://<NAS-IP>:5299`
- Config: `/share/Config/lazylibrarian` -> `/config`
- Shared downloads: `/share/Downloads` -> `/downloads`
- LazyLibrarian library: `/share/Media/LazyLibrarian` -> `/books`
- CWA handoff: `/share/Media/Calibre-Ingest` -> `/cwa-ingest`

LazyLibrarian must keep its own persistent library under `/books`. Do not point `/books` directly at the CWA ingest directory: CWA removes successfully ingested files, while LazyLibrarian's library scan treats `/books` as its own library root and may try to remove it when it becomes empty.

Successful LazyLibrarian post-processing should copy ebooks into `/cwa-ingest` using LazyLibrarian's built-in Calibre Books Auto Add Directory setting. CWA then imports that handoff copy into the managed Calibre library.

## Start the service

```bash
mkdir -p \
  /share/Config/lazylibrarian \
  /share/Media/LazyLibrarian \
  /share/Media/Calibre-Ingest

docker compose pull lazylibrarian
docker compose up -d --force-recreate lazylibrarian
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

## Processing settings

In LazyLibrarian open **Settings -> Processing** and use:

```text
Download Directories: /downloads/books
eBook Library Folder: /books
Keep original files: enabled
```

`/books` resolves to `/share/Media/LazyLibrarian` on the NAS and remains a persistent LazyLibrarian-owned library.

## CWA handoff via Calibre Auto Add

In LazyLibrarian open **Settings -> Importing**. In the **Calibre** section use:

```text
Calibre Books Auto Add Directory: /cwa-ingest
Keep a copy of the book in the local library: enabled
Only add eBook, not opf or jpg: enabled
```

Leave **Calibredb import program** empty and leave **Use Calibre Content Server** disabled. LazyLibrarian is not importing directly into Calibre; it is only placing a handoff copy in CWA's watched ingest directory.

`/cwa-ingest` resolves to `/share/Media/Calibre-Ingest` on the NAS. CWA owns the final `/share/Media/Books` library and its `metadata.db`; LazyLibrarian must not write directly into that final library.

Both LazyLibrarian and qBittorrent see the shared download tree under:

```text
/downloads
```

## End-to-end flow

```text
LazyLibrarian
  -> Prowlarr
  -> qBittorrent
  -> /downloads/books
  -> LazyLibrarian post-processing
  -> /books (persistent LL library)
  -> Calibre Books Auto Add copy
  -> /cwa-ingest (Calibre-Ingest)
  -> Calibre-Web Automated
  -> /calibre-library (NAS: /share/Media/Books)
```

Configure e-reader/Kindle delivery in Calibre-Web Automated after this ingest path is validated.

## Initial validation

Test with a legally obtained ebook:

1. Add/request the book in LazyLibrarian.
2. Confirm Prowlarr returns the expected provider result.
3. Confirm qBittorrent receives it with the `books` category.
4. Confirm LazyLibrarian post-processes it into `/books` and keeps that library copy.
5. Confirm LazyLibrarian places a handoff copy in `/cwa-ingest`.
6. Confirm CWA removes the ingest copy after successful processing and adds the book to the Calibre library.
