Noto Sans SC variable font from [Google Fonts](https://github.com/google/fonts/tree/main/ofl/notosanssc).
It is distributed under the SIL Open Font License 1.1 in `OFL-NotoSansSC.txt`.

The game uses this bundled font on Android because Godot's `SystemFont` is not implemented there. It covers Chinese text and punctuation consistently across devices.

Android UI and 3D text use `NotoSansSC-Regular.tres`, which selects normal weight 400 explicitly. The variable font's default is thin weight 100.
