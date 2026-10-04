# Ketab book catalogue backend

This read-only Node.js service hosts the catalogue over HTTP for remote/deployment use. The Flutter app currently bundles the same EPUBs and `catalog.json` from `assets/books/`, so the server is optional; if you later point the app at the API, its routes mirror the asset layout. Readers can browse, search, download, and read books. They cannot upload or edit catalogue entries. You manage the catalogue by adding EPUB files under `backend/books/` and editing `backend/catalog.json` on your server.

## Run locally

```powershell
node backend/server.mjs
```

The API listens on port 8080 by default. Set `PORT` to change it. The service exposes:

- `GET /api/health`
- `GET /api/books`
- `GET /api/books/:id/download`

The server reads `catalog.json` on each request, so catalogue edits appear after refreshing the app; no restart is required. Each book's `file` value must be a plain `.epub` filename in `backend/books/`. There is deliberately no upload or mutation route.

## Connect the Flutter app

The app does not talk to this server yet. When you add an HTTP mode to `BookBackend`, use `http://localhost:8080/api` by default; for an Android emulator use the host alias `http://10.0.2.2:8080/api`, and for a physical phone use your computer's LAN address. Use HTTPS for a deployed backend; the Android manifest allows cleartext HTTP for local testing. Note the server buffers whole EPUBs in memory and does not support range requests.

## Add a book

1. Copy the EPUB into `backend/books/`.
2. Add an object to the `books` array in `backend/catalog.json` with a unique lowercase `id`, Dari UI metadata, a `file` name, a color such as `#668777`, and an icon key (`auto_stories`, `local_florist`, `waves`, `park`, `landscape`, or `menu_book`).
3. Refresh the app. Only backend-managed books appear in the reader.

The five bundled test EPUBs come from Project Gutenberg: [10315](https://www.gutenberg.org/ebooks/10315), [13060](https://www.gutenberg.org/ebooks/13060), [61724](https://www.gutenberg.org/ebooks/61724), [60471](https://www.gutenberg.org/ebooks/60471), and [52189](https://www.gutenberg.org/ebooks/52189). Their current editions are English text or translations; the reader UI and catalogue metadata are Dari.
