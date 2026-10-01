# 安卓横屏响应式 UI 验收（2026-09-29）

## 卡组编辑器双视图（2026-10-01）

安卓普通组卡使用 `scripts/android_deck_editor.gd`。分屏 1 左侧为带搜索的平铺卡图，右侧只有一个纵向卡组列表，以费用和卡名显示自机、主卡组与副卡组，不显示卡图。轻触卡牌打开左侧描述、右侧卡图的详情弹窗；详情提供加入主/副卡组、移出指定副本、更换自机与异画。手指滑动滚动列表，长按后拖动可添加、排序、交换或拖回卡库移除。卡库只加载可见区域附近的缩略图。

顶部“全屏卡组”开关进入分屏 2：隐藏卡库，主卡组固定 10 列 × 5 行，副卡组在其右侧固定 2 列 × 5 行；两区顶端对齐，按可用宽高缩放同尺寸卡牌并保留空卡位。主卡组边框恰好包裹卡牌网格，自机单独放大显示在左侧。卡组和规则集切换位于界面最上方，右侧只常驻保存、使用、套牌广场、上传套牌和菜单五项，全部完整显示且无需滚动。上传按钮独立进入上传流程；导入、导出、重命名、新建、清空、删除、排序、截图、教程及返回主菜单归入菜单。侧栏宽度计入控件固有最小宽度，避免右侧被截掉。常规 50 张主卡和 10 张副卡无需滚动；超过 50 张的测试卡组每页 50 张，通过上一页、下一页查看，保留绝对卡牌索引与拖放顺序。切换视图及窗口重排保留同一草稿、修改状态、搜索词、所选视图和主卡组页码。PC 编辑器和联机换备牌继续使用各自布局。

`tests/test_android_deck_editor.gd` 检查两个视图、详情、指定副本移除、搜索、鼠标与原生手指拖放、滚动、1280×720 / 2400×1080 安全区域。实际渲染预览在 `work/android-deck-collection.png`、`work/android-deck-details.png`、`work/android-deck-overview.png`。后文保留早期响应式改造记录，其旧编辑器布局说明不适用于当前普通安卓组卡。

## 原因与实现边界

`main.tscn` 本身只有一个全屏 Control，卡组编辑器和战斗 HUD 由脚本运行时创建。因此本次实际修改集中在构建这些节点的脚本、共用 Theme 和项目窗口配置，继续使用同一个主场景，没有复制 Android 场景，也没有设置 UI 根节点 scale。卡牌原画、游戏规则、AI、伤害结算和卡组合法性逻辑不变。

原布局以 1600×900 为画布：固定比例拉伸导致超宽安卓横屏两侧黑边；编辑器详情、卡组、卡库固定三栏，卡库名称与数量依赖手工坐标；战斗的 HUD、手牌步长、阶段操作和颜色盘触摸判定也依赖旧坐标。Android 上整体缩小后，按钮、字号和可用空间没有对应重排。

## 文件与节点

| 文件 | 修改内容 |
| --- | --- |
| `project.godot` | canvas_items 使用 expand，横屏方向；充分使用 18:9、19.5:9、20:9 横向空间。 |
| `scripts/ui_layout.gd`（新增） | 汇总 DPI、逻辑坐标换算、safe area、边距、字体、触摸尺寸、Theme、列宽和手牌布局。 |
| `scripts/deck_editor_layout.gd`（新增） | VBox/HBox/Margin/PanelContainer/动态 GridContainer；详情折叠；卡库最小宽度；主副卡组滚动与拖放几何。 |
| `scripts/battle_ui_layout.gd`（新增） | 顶部工具栏、生命值、阶段操作区、颜色盘与手牌区域统一计算。 |
| `scripts/menu_ui_layout.gd`（新增） | 对局准备和设置的 Container 布局，复用同套字号与操作尺寸。 |
| `scripts/main.gd` | 接入响应式布局和窗口变化；主菜单重排；卡库名称/余量改为容器；共用确认弹窗与卡牌选择弹层适配。 |
| `scripts/duel_view.gd` | HUD 与手牌滚动、关键阶段按钮、详情/颜色盘/设置/选项/伤害分配/牌堆弹层；触摸判定跟随实际节点。 |
| `scripts/duel_hand_card.gd` | 手机抬手选择、移动取消点击、长按查看，避免横向滚动误选手牌。 |
| `scripts/deck_card.gd` | 增加焦点与选中操作反馈。 |
| `scripts/card_name_search_panel.gd` | 卡牌搜索容器布局，图文分区和滚动详情，保证筛选与确认触摸尺寸。 |

## Android 与 PC 策略

- Android：用屏幕 DPI 与 viewport 换算约 48dp 最小触摸高度/主要按钮宽度；正文约 16dp、辅助信息约 14dp，并设置逻辑字号下限，标题更大。safe area 从 DisplayServer 获取，换算后再留圆角/手势边距；系统返回的安全区域变化时重新布局。
- 编辑器：先保护六个触摸颜色筛选与卡库宽度，把余量给中央卡组。容不下三栏时隐藏常驻详情，改为“卡牌详情”弹层。主卡组列数随宽度变化，内容滚动；保存/使用常驻，导入导出等收进“更多”。名称可换行，数量独立占位。没有靠继续缩小字体维持三栏。
- 战斗：顶部集中回合/响应/观察/菜单；左侧生命值与颜色盘，底部中央手牌，右下阶段操作及后退。手牌先调整尺寸，再横向滚动，24 张不越界。费用、颜色和选择框突出，正文通过详情阅读。
- PC：2026-09-29 回卷至改造前的 1600×900 固定画布及原主菜单、设置、对局准备、组卡和战斗 HUD 布局；安卓继续使用响应式布局。现有试验 AI 和回放训练开关保留在 PC 原布局中。
- Theme：深色底、金色关键操作，弱化普通面板边框；pressed、selected、focus 有反馈。AcceptDialog 弹出会重置内部按钮最小尺寸，因此其按钮保留文字固有宽度，避免省略模式导致只剩窄条。

## 自动运行与截图

Godot 4.7.2，Windows Compatibility/NVIDIA 渲染。所有截图取自实际生产主场景。Android 分支测试传入等效 DPI 与左右/底部安全区域，既检查矩形位置，也发送触摸拖动事件。

| 分辨率 | 比例 | 编辑器 / 战斗 / 24 张手牌 |
| --- | --- | --- |
| 1920×1080 | 16:9 | Android 响应式通过；PC 使用原固定画布 |
| 2400×1080 | 20:9 | Android 响应式通过；PC 使用原固定画布 |
| 2340×1080 | 19.5:9 | Android 响应式通过；PC 使用原固定画布 |
| 1280×720 | 16:9 | Android 响应式通过，详情自动折叠；PC 使用原固定画布 |
| 2160×1080 | 18:9 | Android 补充交互、弹层与截图检查通过 |

| 测试入口 | 结果 |
| --- | --- |
| `tests/test_responsive_ui.gd`（新增） | 回卷前四尺寸×双平台通过；回卷后仅检验 Android 响应式布局。 |
| `tests/test_desktop_ui_rollback.gd`（新增） | 检验 PC 原画布、主菜单、设置、对局准备、组卡和战斗 HUD 的关键位置。 |
| `tests/test_responsive_interactions.gd`（新增） | 25 检查，0 失败：确认弹窗、自机搜索、手牌选择、详情、颜色盘原生触摸、设置、活跃对局缩放、牌堆、帮助、伤害分配。 |
| `tests/test_deck_editor.gd` | 21 检查，0 失败：按新菜单访问导入导出与重命名；实际窗口验证剪贴板。 |
| `tests/test_deck_drag_order.gd` | 11 检查，0 失败：响应式网格插入与跨组空白处拖放，保存顺序。 |
| `tests/test_card_view.gd` | 44 检查，0 失败：全 viewport 战场、观察与视角工具。 |
| `tests/test_card_search_aliases_ui.gd` | 215 检查，0 失败：容器嵌套后的名称搜索和卡牌选择回归。 |
| `tests/test_card_name_target_picker_ui.gd` | 18 检查，0 失败：目标选择、确认与原有费用支付语义。 |

运行示例：

```powershell
& .godot-toolchain/editor/Godot_v4.7.2-stable_win64_console.exe --path . --script tests/test_responsive_ui.gd
& .godot-toolchain/editor/Godot_v4.7.2-stable_win64_console.exe --path . --script tests/test_responsive_interactions.gd
& tools/build-android.ps1 -OutputPath builds/Android-debug/MulticolorArena-responsive-debug.apk
```

截图与完整日志在 `work/android-responsive/`。矩阵截图名为 `android-宽x高-editor.png` / `battle.png` / `hand24.png`，PC 同理。测试使用隔离的卡组存储。手牌上方提示最终居中，避免压到左侧自机卡；该文字对齐微调后追加 2340×1080 渲染复测，108 检查、0 失败。Windows 系统证书读取提示属于环境日志，本次无 GDScript 解析错误。

## Android 实际运行与仍需实机验证

已构建并签名校验 Android arm64 + x86_64 debug APK，安装到本机 AOSP Android 15 / API 35 模拟器，使用 host GPU 运行真实 Android 代码路径。验证 1280×720 / density 240 与 2340×1080 / density 360 的菜单、编辑器、详情、投点确认与起手调度；实际切换分辨率后保留对局。截图前缀为 `emulator-final-`（详情初轮验证为 `emulator-details-1280.png`）。安装包位置：`builds/Android-debug/MulticolorArena-responsive-debug.apk`。

仍需用户手机实测：不同厂商刘海/挖孔与沉浸式 safe area 上报；系统手势和游戏后退手势竞争；中文输入法弹出/收回；长按、滚动、卡组拖放的手指体验；低端 GPU 的启动、卡图加载和战场帧率。模拟器与桌面 DPI 模拟不能替代这些硬件差异。

本轮验收覆盖编辑器、战斗 HUD 和相关高频弹层。联机房间、回放管理等较低频页面仍有旧版固定坐标；已隔离主题，防止本次字号增大挤压其原有布局，未宣称全项目所有页面都完成响应式改造。
