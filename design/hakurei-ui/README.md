# 博丽神社战场 UI 探索

此目录属于隔离工作树 `work/hakurei-ui-worktree`。代码版先同步了创建工作树时主工作区中尚未提交的对局源码，再调整战场配色；主工作区没有应用这些主题改动。

## 手动测试

1. 双击隔离工作树根目录中的 `运行神社UI测试.cmd`，直接启动测试版游戏。窗口标题含「博丽神社 UI 测试」。
2. 选择「人机对战」，选用隔离副本中已有的「预组-灵梦」和「预组-魔理沙」。勾选「测试模式（手动控制双方）」，如只想检查视觉可同时勾选「无需付费」，再点击「开始对战」并选择先后手。
3. 在战场中检查桌垫、手牌高亮、可选目标蓝边、已选目标金边、右侧操作按钮、卡牌预览和堆叠。
4. 如需在 Godot 编辑器中检查，双击隔离目录的 `启动Godot.cmd`，再按 F5 运行。两个启动脚本都使用主目录已有的 Godot 4.7.2 程序，但 `--path` 指向隔离工作树。

此测试项目的 `res://saves` 位于隔离工作树，`user://` 也使用独立的 `极彩 Multicolour - Hakurei UI Test` 目录。主版本项目文件和玩家数据目录不会由上述测试入口写入。

## 实机版本

- `00-implemented-preview.png`：Godot 实机截图，保留当前桌垫、牌位与操作布局。
- `scripts/main.gd`：仅在战场页使用深紫面板、朱红强调、云白文字和浅金按钮。
- `scripts/duel_view.gd`、`scripts/duel_stack.gd`、`scripts/duel_hand_card.gd`：调整生命、卡牌预览、手牌、堆叠与选中提示配色。
- `scripts/duel_table.gd`、`assets/playmat_wide.gdshader`：把深蓝桌垫映射到靛紫、天空蓝、云白与鸟居红。
- `net/chat_panel.gd`：联机聊天面板沿用战场配色。

## GPT 生图方向

三张图均以实机截图作为布局参考，以 `recourse/数据库/170.png` 的「博丽神社」卡图作为颜色与材质参考。它们是方案草图，卡名和数值不作为实现依据。

1. `01-spring-morning.png`：晴空蓝与云白的明亮春日桌面，鸟居红边框、浅金主操作按钮、青色合法目标提示。
2. `02-sunset-lacquer.png`：黄昏云光照在靛紫桌面上，以漆木红边框、和纸嵌板与暖金操作提示形成较暗的长局对战方案。
3. `03-washi-ink.png`：和纸白桌面、细朱红分区线、浅蓝云纹，以高对比深色文字和简洁侧栏突出卡牌。

## 验证

Godot 4.7.2 实机成功渲染 `00-implemented-preview.png`；`tests/test_2d_unit_layout.gd` 的 30 项检查通过。截图与测试均在隔离工作树内生成。

## 黄昏主题资产接入

`feature/hakurei-sunset-ui` 分支已接入 GPT 生图背景、按钮和面板，原始图、成品路径和提示词见 [asset-prompts.md](asset-prompts.md)。战场牌位与分区仍由原版桌垫控制。实机截图保存在 `work/hakurei-sunset-captures/`，可运行 `tests/capture_hakurei_sunset.gd` 重拍主菜单、组卡器和战场。
