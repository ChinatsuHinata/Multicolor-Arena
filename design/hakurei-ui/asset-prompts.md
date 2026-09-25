# 黄昏 UI 生图资产

使用内置 GPT 生图引擎，以 `02-sunset-lacquer.png` 为风格参考。成品位于 `assets/hakurei_sunset/`；按钮和面板的原始生成图以 `source_` 开头，`tools/prepare_hakurei_assets.gd` 用 Godot 裁掉透明留白、缩放为九宫格贴图，并由同一生成图派生悬停和按下状态。

当前长纹饰 `button.png` 只用于较窄的页面标题栏；主菜单的“极彩”大标题框使用适合九宫格拉伸的 `panel.png`。菜单中的可点击大按钮由 `scripts/hakurei_skin.gd` 绘制，避免长牌匾在不同尺寸的控件里变形。

## 成品与提示词

- `shrine_backdrop.png`：16:9 博丽神社黄昏背景。提示词："Show Hakurei Shrine at dusk: a receding row of vermilion torii gates, two warm glowing lanterns near the outer left and right, cherry blossoms framing top corners, orange and pink clouds across an indigo sky, drifting sakura petals. Keep the middle clear and relatively dark for a game board or menu. Painterly Japanese fantasy game background. No board, cards, characters, UI, text, logo or watermark."
- `sunset_atmosphere.png`：战场桌垫下方的正方形风格背景。提示词："Top-down flat dark indigo-purple lacquer and translucent cloud-reflection surface, broad low-contrast warm sunset glow through the middle, subtle torii silhouettes and cherry branches in the reflection, tiny petals, restrained maroon edges. Background artwork only: absolutely no card slots, lane lines, rectangles, frame, emblem, UI, cards, perspective, text, logo or watermark."
- `source_button.png` → `button.png`：暗色长按钮。提示词："One perfectly horizontal long rectangular game UI button, straight-on flat view, deep indigo-purple lacquer fill, vermilion bevel, fine warm gold filigree outline, tiny blossom ornaments at both far ends, subtle sunset gleam, quiet empty center, genuinely transparent outside. Symmetric nine-slice-friendly design. No text, icons, scene or watermark."
- `source_button_accent.png` → `button_accent.png`：金色主操作按钮。提示词："Preserve the shape, lacquer border, gold filigree, end blossoms and transparent outside of the dark button reference; change the empty center to warm illuminated amber-gold lacquer with a gentle sunset sheen. Front-facing and flat. No text, icons, scene or watermark."
- `source_panel.png` → `panel.png`：组卡器、菜单通用面板。提示词："One square front-on lacquered game UI panel on a genuinely transparent background, dark plum-indigo quiet center, thin vermilion wood edge, pale gold trim, cherry blossom filigree only in four corners. Symmetric, crisp nine-slice-friendly frame. No perspective, text, controls, cards, scene or watermark."

## 战场布局约束

战场仍加载 `res://recourse/垫子3.png`。`assets/playmat_wide.gdshader` 用原图确定牌位、分区线和图案，再把 `sunset_atmosphere.png` 作为底色叠入；`scripts/duel_table.gd` 中的尺寸、牌位坐标、点击区域和视角保持原样。生图结果不定义战场布局。
