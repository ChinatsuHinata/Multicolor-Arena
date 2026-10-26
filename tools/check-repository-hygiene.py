"""Reject tracked local artifacts and verify the repository upload boundaries."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = [
    "project.godot", "main.tscn", "export_presets.cfg",
    "scripts/main.gd", "data/preset_decks.json",
    "data/account_public.pem", "data/update_public.pem",
    "addons/share_export/deck_export.gd", "tests/AGENTS.md",
    "tests/support/mod_layers/manifest.json",
    "tests/support/mod_second/manifest.json", "tests/support/mod_second/draw.json",
    "work/.gdignore", "saves/.gdignore", "tts_mod/deck_builder.lua",
]
IGNORED_EXAMPLES = [
    "deck/private.mdeck", "saves/settings.json", "saves/lan/identity.bin",
    "replay/private.mreply", "training/private.training.json",
    "work/report.json", "work/backup/main.gd", "builds/Android/test.apk",
    ".godot/editor/layout.cfg", ".godot-toolchain/editor/tool.exe",
    ".codex-remote-attachments/upload.png", "output/report.pdf", "outputs/check.json",
    "recourse/MulticolourOnline/UnityPlayer.dll",
    "recourse/MulticolourOnline2.0/Multicolour2.exe",
    "tts_mod/Multicolour_Deck_Builder.json", "tts_mod/local_art_manifest.json",
    "release.exe", "release.msi", "release.apk", "release.aab", "release.pck", "private.jks", ".env",
    "tools/__pycache__/tool.pyc", "tests/support/__pycache__/fixture.pyc",
    "tests/support/run.log", "saves/decks.json.bak", ".vscode/settings.json",
]

def git(*args, data=None, allow_no_match=False):
    result = subprocess.run(["git", "-C", str(ROOT), *args], input=data, capture_output=True)
    if result.returncode and not (allow_no_match and result.returncode == 1):
        raise RuntimeError(result.stderr.decode("utf-8", errors="replace"))
    return [item.decode("utf-8") for item in result.stdout.split(b"\0") if item]

def main():
    tracked = set(git("ls-files", "-z"))
    unwanted = git("ls-files", "--cached", "--ignored", "--exclude-standard", "-z")
    probes = REQUIRED + IGNORED_EXAMPLES
    ignored = set(git("check-ignore", "--no-index", "-z", "--stdin",
                      data=("\0".join(probes) + "\0").encode("utf-8"), allow_no_match=True))
    problems = (["Tracked local artifact: " + p for p in unwanted]
                + ["Required source missing from index: " + p for p in REQUIRED if p not in tracked]
                + ["Required source is ignored: " + p for p in REQUIRED if p in ignored]
                + ["Local artifact is not ignored: " + p for p in IGNORED_EXAMPLES if p not in ignored])
    if problems:
        print("\n".join(problems))
        return 1
    print(f"Repository hygiene OK: {len(tracked)} tracked files; local artifacts excluded; required sources retained.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
