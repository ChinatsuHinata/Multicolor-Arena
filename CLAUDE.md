# Multicolor-Arena 协作约定

## UI 工作：Claude 设计 + Codex 工程

界面相关的改动默认走两段式，不要把设计决策丢给 Codex，也不要把大批量机械改动留给自己逐行敲。

**第一段 — Claude 定设计**
- 定版式、间距、配色、层级、动效意图，以及"为什么这样改"。可以参考现有风格文件（`scripts/ui_palette.gd`、`scripts/sakura_backdrop.gd`）保持一致性。
- 产出可执行规格：目标文件、要改的函数/节点、具体数值（颜色 hex、像素、字号、缓动时长）、必须保持不变的东西。
- 规格写给 Codex 看，不是写给用户看：不含抒情描述，每条都能对照代码核对。
- 需要视觉确认时先自己出效果或截图，再进第二段。

**第二段 — Codex 落地实现**
- 用 `codex` 子代理（定义见 `.claude/agents/codex.md`），只给规格，不给"你看着办"。
- Codex 负责改文件、跑测试、报结果；不做界面设计决策。规格有歧义时它会按自己的理解实现，所以数值要写死。

**收尾 — Claude 验收**
- 读 Codex 的报告，检查改了哪些文件、测试通过项数、有没有触碰禁区。
- 界面类改动自己跑一次测试或看截图，不只看"已通过"三个字。

## Codex 子代理调用

必须走项目启动脚本，不要直接调 PATH 里的旧 `codex exec`：

```bash
powershell.exe -NoProfile -File tools/invoke-codex.ps1 -Check                      # 只读自检
powershell.exe -NoProfile -File tools/invoke-codex.ps1 -PromptFile work/codex-<主题>.txt -OutputFile work/codex-<主题>.txt
```

- 已验证组合（2026-10-22）：Codex CLI `0.163.0-alpha.10.2`、模型 `gpt-6.1-sol`、推理强度 `xhigh`、沙箱 `workspace-write`；只读分析与自检用 `-Sandbox read-only`。
- 长任务放后台跑，每个任务用独立的 `-OutputFile`。退出码非 0 即失败，"已启动"不等于"已完成"。
- 子代理启动若被权限分类器拦下，由主会话直接执行同一条 powershell 命令完成任务，不要在子代理上反复重试。
- 中文路径在控制台会显示成乱码（`D:\Ҷ����Ϸ\...`），是代码页问题，不影响实际读写。

## 仓库约束（写进每条 Codex 提示词）

- GDScript 缩进为**每级 1 个空格**，禁止 Tab；不要对既有 `.gd` 做整体格式化。
- 改完运行 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/check-gdscript-indent.ps1`。
- 测试用 `.godot-toolchain/editor/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/<name>.gd`。
- 不要改 `net/rules_manifest.json` 的联机指纹；不要改 `saves/`、`deck/` 里的玩家数据。
- 安卓与 PC 共用默认开启、可在设置关闭的樱花主题；保持各自布局与触控适配，不要把桌面固定坐标套到安卓界面。
- 新增脚本的 `.uid` 由 Godot 运行时生成，不要手写。
