"""Local bridge between Roblox Studio and the repo (127.0.0.1 only).

GET  /<path>                       serves repo files (used by tools/studio-sync.luau)
POST /save?path=assets/roblox/...  body = base64 .rbxm; writes it into assets/roblox/ only

Run from the repo root:  python3 tools/asset_server.py
"""

import base64
import http.server
import os
import urllib.parse

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
WRITE_ROOT = os.path.join(ROOT, "assets", "roblox")
PORT = 34872


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def do_POST(self):
        url = urllib.parse.urlparse(self.path)
        rel = urllib.parse.parse_qs(url.query).get("path", [""])[0]
        target = os.path.abspath(os.path.join(ROOT, rel))
        if url.path != "/save" or not target.startswith(WRITE_ROOT + os.sep) or not target.endswith(".rbxm"):
            self.send_error(403, "only assets/roblox/**/*.rbxm may be written")
            return
        length = int(self.headers.get("Content-Length", 0))
        data = base64.b64decode(self.rfile.read(length))
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with open(target, "wb") as f:
            f.write(data)
        self.send_response(200)
        self.end_headers()
        self.wfile.write(f"wrote {rel} ({len(data)} bytes)".encode())


if __name__ == "__main__":
    http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
