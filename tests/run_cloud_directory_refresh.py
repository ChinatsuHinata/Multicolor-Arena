"""Exercise cloud directory return/refresh against a loopback-only relay fixture."""
import os
from pathlib import Path
import socket
import subprocess
import time

root = Path(__file__).resolve().parents[1]
godot = root / ".godot-toolchain/editor/Godot_v4.7.2-stable_win64_console.exe"
scratch = root / "work/cloud-directory-refresh"
scratch.mkdir(parents=True, exist_ok=True)
port = 47975
creationflags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0


def ready():
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=0.2):
            return True
    except OSError:
        return False


if ready():
    raise SystemExit(f"Loopback test port {port} must be unused.")

with open(scratch / "services.log", "w", encoding="utf-8") as log:
    relay = subprocess.Popen([
        str(godot), "--headless", "--path", ".", "--log-file", str(scratch / "relay.log"),
        "--script", "res://tests/support/cloud_resume_relay.gd", "--", "--test-resume",
        "--bind", "127.0.0.1", "--port", str(port), "--transport", "websocket",
    ], cwd=root, stdout=log, stderr=log, creationflags=creationflags)
    try:
        deadline = time.monotonic() + 10
        while not ready():
            if time.monotonic() > deadline or relay.poll() is not None:
                raise RuntimeError(f"Loopback relay failed to start; see {scratch / 'services.log'}")
            time.sleep(0.1)
        result = subprocess.run([
            str(godot), "--headless", "--path", ".", "--log-file", str(scratch / "test.log"),
            "--script", "res://tests/test_cloud_directory_refresh.gd",
        ], cwd=root, creationflags=creationflags, timeout=120, capture_output=True, encoding="utf-8", errors="replace")
        print(result.stdout, end="", flush=True)
        print(result.stderr, end="", flush=True)
        raise SystemExit(result.returncode)
    finally:
        relay.terminate()
        relay.wait(timeout=10)
