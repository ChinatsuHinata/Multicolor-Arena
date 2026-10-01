#!/usr/bin/env python3
"""Serve signed game releases and pass existing WebSocket traffic to Godot."""

import argparse
import os
import re
import select
import socket
import socketserver
from pathlib import Path

MAX_HEADER = 16384
ASSET = re.compile(r"^/updates/(\d+\.\d+\.\d+(?:\.\d+)?)/(MulticolorArena-\1-(?:win64-setup\.exe|android\.apk))$")
RANGE = re.compile(r"^bytes=(\d*)-(\d*)$")


class Gateway(socketserver.ThreadingMixIn, socketserver.TCPServer):
    allow_reuse_address = True
    daemon_threads = True

    def __init__(self, address, handler, root, backend):
        self.release_root = Path(root).resolve()
        self.backend = backend
        super().__init__(address, handler)


class Handler(socketserver.BaseRequestHandler):
    def handle(self):
        self.request.settimeout(10)
        data = bytearray()
        while b"\r\n\r\n" not in data and len(data) < MAX_HEADER:
            chunk = self.request.recv(min(4096, MAX_HEADER - len(data)))
            if not chunk:
                return
            data.extend(chunk)
        if b"\r\n\r\n" not in data:
            self.reply(431, b"Request header too large")
            return
        header = bytes(data).split(b"\r\n\r\n", 1)[0]
        try:
            lines = header.decode("ascii").split("\r\n")
            method, target, protocol = lines[0].split(" ", 2)
            headers = dict(line.split(":", 1) for line in lines[1:] if ":" in line)
            headers = {key.lower(): value.strip() for key, value in headers.items()}
        except (UnicodeError, ValueError):
            self.reply(400, b"Bad request")
            return
        if headers.get("upgrade", "").lower() == "websocket":
            self.websocket(bytes(data))
            return
        if protocol not in ("HTTP/1.0", "HTTP/1.1") or method not in ("GET", "HEAD"):
            self.reply(405, b"Method not allowed")
            return
        if target == "/updates/latest.json":
            path = self.server.release_root / "latest.json"
            cache = "no-store"
            content_type = "application/json"
        else:
            match = ASSET.fullmatch(target)
            if not match:
                self.reply(404, b"Not found")
                return
            path = self.server.release_root / match[1] / match[2]
            cache = "public, max-age=31536000, immutable"
            content_type = "application/octet-stream"
        if not path.is_file() or not path.resolve().is_relative_to(self.server.release_root):
            self.reply(404, b"Not found")
            return
        size = path.stat().st_size
        start, end, status = 0, size - 1, 200
        if "range" in headers:
            match = RANGE.fullmatch(headers["range"])
            if not match or not match[1] and not match[2]:
                self.reply(416, b"Invalid range")
                return
            if match[1]:
                start = int(match[1])
                end = min(int(match[2]), size - 1) if match[2] else size - 1
            else:
                start = max(0, size - int(match[2]))
            if start >= size or end < start:
                self.reply(416, b"Invalid range")
                return
            status = 206
        response = [
            f"HTTP/1.1 {status} {'Partial Content' if status == 206 else 'OK'}",
            f"Content-Length: {end - start + 1}",
            f"Content-Type: {content_type}",
            f"Cache-Control: {cache}",
            "Accept-Ranges: bytes",
            "X-Content-Type-Options: nosniff",
            "Connection: close",
        ]
        if status == 206:
            response.append(f"Content-Range: bytes {start}-{end}/{size}")
        if content_type == "application/octet-stream":
            response.append(f'Content-Disposition: attachment; filename="{path.name}"')
        self.request.sendall(("\r\n".join(response) + "\r\n\r\n").encode("ascii"))
        if method == "HEAD":
            return
        self.request.settimeout(120)
        try:
            with path.open("rb") as file:
                file.seek(start)
                remaining = end - start + 1
                while remaining:
                    chunk = file.read(min(1024 * 1024, remaining))
                    if not chunk:
                        break
                    self.request.sendall(chunk)
                    remaining -= len(chunk)
        except (BrokenPipeError, ConnectionResetError, socket.timeout):
            pass

    def websocket(self, first_data):
        try:
            with socket.create_connection(self.server.backend, timeout=10) as backend:
                backend.sendall(first_data)
                self.request.settimeout(None)
                backend.settimeout(None)
                while True:
                    ready, _, _ = select.select((self.request, backend), (), ())
                    for source in ready:
                        chunk = source.recv(65536)
                        if not chunk:
                            return
                        (backend if source is self.request else self.request).sendall(chunk)
        except (OSError, ValueError):
            pass

    def reply(self, status, message):
        response = f"HTTP/1.1 {status} Error\r\nContent-Length: {len(message)}\r\nConnection: close\r\n\r\n".encode("ascii")
        self.request.sendall(response + message)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=47862)
    parser.add_argument("--backend-port", type=int, default=47866)
    parser.add_argument("--releases", default=os.path.expanduser("~/.local/share/multicolor-updates"))
    args = parser.parse_args()
    with Gateway((args.host, args.port), Handler, args.releases, ("127.0.0.1", args.backend_port)) as server:
        print(f"Update gateway listening on {args.host}:{args.port}", flush=True)
        server.serve_forever(poll_interval=0.2)


if __name__ == "__main__":
    main()
