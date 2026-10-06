"""Stream isolated test assets through a loopback-only HTTP server."""
import argparse
import json
import shutil
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("folder", type=Path)
args = parser.parse_args()
folder = args.folder.resolve()


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        routes_path = folder / "routes.json"
        routes = json.loads(routes_path.read_text(encoding="utf-8")) if routes_path.exists() else {}
        relative = routes.get(self.path)
        path = (folder / relative).resolve() if relative else None
        valid = path is not None and path.is_relative_to(folder) and path.is_file()
        status = 200 if valid else 404
        with (folder / "requests.jsonl").open("a", encoding="utf-8") as log:
            log.write(json.dumps({"path": self.path, "status": status}) + "\n")
        self.send_response(status)
        self.send_header("Content-Length", str(path.stat().st_size if valid else 0))
        self.send_header("Connection", "close")
        self.end_headers()
        if valid:
            with path.open("rb") as stream:
                shutil.copyfileobj(stream, self.wfile, 1024 * 1024)

    def log_message(self, *_args):
        pass


server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
(folder / "server.json").write_text(json.dumps({"origin": f"http://127.0.0.1:{server.server_port}"}), encoding="utf-8")
server.serve_forever()
