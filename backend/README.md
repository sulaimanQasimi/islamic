# Ketab book catalogue backend

This read-only Node.js service is the app's catalogue source. Readers can browse, search, download, and read books. They cannot upload or edit catalogue entries. You manage the catalogue by adding EPUB files under `backend/books/` and editing `backend/catalog.json` on your server.

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

The default app API address is `http://localhost:8080/api`. For an Android emulator, use the host alias:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api
```

For a physical phone, use the computer's LAN address instead of `10.0.2.2`. Flutter web and desktop can use the default localhost address. Use HTTPS for a deployed backend; the Android manifest allows cleartext HTTP for this local test setup.

## Add a book

1. Copy the EPUB into `backend/books/`.
2. Add an object to the `books` array in `backend/catalog.json` with a unique lowercase `id`, Dari UI metadata, a `file` name, a color such as `#668777`, and an icon key (`auto_stories`, `local_florist`, `waves`, `park`, `landscape`, or `menu_book`).
3. Refresh the app. Only backend-managed books appear in the reader.

The five bundled test EPUBs come from Project Gutenberg: [10315](https://www.gutenberg.org/ebooks/10315), [13060](https://www.gutenberg.org/ebooks/13060), [61724](https://www.gutenberg.org/ebooks/61724), [60471](https://www.gutenberg.org/ebooks/60471), and [52189](https://www.gutenberg.org/ebooks/52189). Their current editions are English text or translations; the reader UI and catalogue metadata are Dari.
