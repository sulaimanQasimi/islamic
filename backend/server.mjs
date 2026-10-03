import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { basename, extname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('.', import.meta.url));
const catalogPath = join(root, 'catalog.json');
const booksDir = join(root, 'books');
const port = Number(process.env.PORT ?? 8080);

function sendJson(res, status, value) {
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Cache-Control': 'no-store',
  });
  res.end(JSON.stringify(value));
}

const server = createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') { res.writeHead(204); res.end(); return; }
  if (req.method !== 'GET') { sendJson(res, 405, { error: 'Only GET is supported.' }); return; }

  const url = new URL(req.url ?? '/', `http://${req.headers.host ?? 'localhost'}`);
  if (url.pathname === '/api/health') { sendJson(res, 200, { status: 'ok' }); return; }
  if (url.pathname === '/api/books') {
    try {
      const catalog = JSON.parse(await readFile(catalogPath, 'utf8'));
      const books = (catalog.books ?? []).map(({ file: _file, ...book }) => book);
      sendJson(res, 200, { books });
    } catch (error) {
      console.error('Could not read catalogue:', error);
      sendJson(res, 500, { error: 'Catalogue could not be read.' });
    }
    return;
  }

  const match = url.pathname.match(/^\/api\/books\/([a-z0-9-]+)\/download$/i);
  if (match) {
    try {
      const catalog = JSON.parse(await readFile(catalogPath, 'utf8'));
      const book = (catalog.books ?? []).find((item) => item.id === match[1]);
      if (!book || extname(book.file ?? '').toLowerCase() !== '.epub' || basename(book.file) !== book.file) {
        sendJson(res, 404, { error: 'Book not found.' });
        return;
      }
      const path = join(booksDir, book.file);
      const info = await stat(path);
      res.writeHead(200, {
        'Content-Type': 'application/epub+zip',
        'Content-Length': info.size,
        'Content-Disposition': `attachment; filename="${book.id}.epub"`,
        'Access-Control-Allow-Origin': '*',
        'Cache-Control': 'public, max-age=3600',
      });
      res.end(await readFile(path));
    } catch (error) {
      if (error?.code === 'ENOENT') sendJson(res, 404, { error: 'EPUB file is missing.' });
      else { console.error('Could not serve EPUB:', error); sendJson(res, 500, { error: 'EPUB could not be served.' }); }
    }
    return;
  }
  sendJson(res, 404, { error: 'Route not found.' });
});

server.listen(port, '0.0.0.0', () => {
  console.log(`Ketab book backend is ready at http://localhost:${port}`);
  console.log('Read-only routes: GET /api/health, GET /api/books, GET /api/books/:id/download');
});
