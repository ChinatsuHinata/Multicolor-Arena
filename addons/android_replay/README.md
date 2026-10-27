# Android replay file opening

The normal Godot APK export template is extended with one independent Activity. Run
`powershell -File tools/build-android.ps1` to build/export, or run
`tools/build-android-replay-template.ps1` before exporting from the editor. Python 3,
the project's JDK 17 and Android SDK 35 are needed; no Gradle download is needed.
Generated debug/release templates stay in `.godot-toolchain/android_replay/` and are
never committed. The builder preserves the stock launcher, resources and package
settings; Godot performs its normal final signing. The manifest change requires a
new APK installation; downloading a resource update alone cannot add a file type.

`ReplayOpenActivity` accepts VIEW requests for `.mreply` and compatible `.replay`
files, including temporary content-URI grants. It copies bounded input to private
cache on a worker thread, checks the replay header, then brings the existing game
task forward (or starts it). Each delivery has an independent random name and an
atomic descriptor. The original file is never modified. The GDScript inbox checks
the descriptor/header again and emits `replay_received(path, display_name)`. The
main UI performs the complete `ReplayArchive.read()` check, persists the import,
and acknowledges the cached delivery. Requests not acknowledged survive restart.

Android cannot match a provider's DISPLAY_NAME in an intent filter. File managers
with opaque numeric content URIs usually send `application/octet-stream`, so a
content-only fallback handles that MIME type. The activity still requires a replay
extension and valid magic. Extension-specific paths and the dedicated
`application/x-multicolorarena-replay` MIME cover other managers; no unrestricted
`*/*` association is registered. Managers that supply an arbitrary MIME and an
opaque URI may require opening via a different file manager.

Native streaming regressions are in `tests/support/android_replay/CopyReplayTest.java`.
Template resource/index preservation and UTF-16 compatibility are checked by
`python tests/test_android_replay_template.py`. Queue, restart, acknowledgement and traversal tests are in
`tests/test_android_replay_inbox.gd`; main-UI import tests are in
`tests/test_external_replay_ui.gd`. Native intent resolution/cold/warm starts still
need an Android device or emulator. For testing a new APK, use a separate package
ID and app label so the installed production app and data are preserved.
