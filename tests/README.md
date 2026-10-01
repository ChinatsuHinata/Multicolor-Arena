# 当前功能测试

这里只保留验证当前游戏行为的专项测试。旧版本测试入口及配套 `.uid` 已清理，历史文档中的旧测试名称仅为当时的记录，不再作为验证命令。

测试按功能或卡牌命名。`support/` 保存规则、选牌、界面、响应与联机的公共辅助代码，不包含旧版本测试断言，也不单独运行。

常用入口：

| 功能 | 测试 |
| --- | --- |
| 套牌广场登录、上传、异画、搜索、编辑器更新、所属玩家权限及下载 | `test_deck_plaza.gd`、`test_deck_plaza_store.py` |
| 卡库加载 | `test_database_load.gd` |
| 组卡器卡牌排序与主副卡交换 | `test_deck_drag_order.gd` |
| 组卡双列无滚动菜单、战斗置顶弹窗、背景点击／触摸／快捷键隔离及关闭恢复 | `test_menu_modal.gd` |
| 安卓图鉴单行三卡、翻页与筛选、搜索与页码保留、详情余量与自机单位加牌、右侧列表长按移除、卡组页拖动及返回菜单 | `test_android_deck_editor.gd` |
| 安卓高密度横屏底部翻页箭头与主副卡组按钮、安全区域、颜色筛选独立滑动及触摸操作 | `test_android_deck_density.gd` |
| PC 组卡器原有三栏布局、滚动卡库、横向颜色按钮、类型选项与搜索行为 | `test_desktop_ui_rollback.gd` |
| 安卓右侧主卡组上下滑动、慢速和斜向手势、滚动边界及短列表误拖拽 | `test_android_deck_scroll.gd` |
| 安卓卡牌轻触详情、手牌长按与记录排版 | `test_android_card_details.gd` |
| 卡牌别名与各处搜索选牌 | `test_card_search_aliases.gd`、`test_card_search_aliases_ui.gd` |
| 对局规则 | `test_duel_rules.gd` |
| 全部复制效应的指示物、负指示物与白莲 X 费反制支付 | `test_copy_counters.gd`、`test_minus_counters.gd` |
| 云集雾散目标加费、冰之勇者横置、猫车消灭、妖梦决斗与支付界面 | `test_mist_target_tax.gd`、`test_mist_unit_abilities.gd`、`test_mist_target_tax_ui.gd` |
| 赤眼催眠重选目标、凤翼天翔使用时分配伤害、铃仙乐章幻象存活与名称提示 | `test_reisen.gd`、`test_reisen_ui.gd` |
| 摩多罗的牌库顶预览与自机牌颜色约束 | `test_okina_color_bypass.gd`、`test_okina_ui.gd` |
| 奇迹前缀限制与衍生物同时制造 | `test_miracle.gd`、`test_token_creation.gd` |
| 蕾米速攻专用 AI | `test_remilia_aggro_ai.gd` |
| AI 小蕾米回手、重新登场与死亡去向 | `test_remilia_return_ai.gd` |
| 蕾米前期凭依保留展开、结晶大单位与保护直伤 | `test_remilia_resource_ai.gd` |
| 不夜城小单位吸血、核心击杀线、灵梦对策协调与玩家斩杀 | `test_remilia_red_ai.gd` |
| 人类标注对应的 AI 决策与真实录像复现 | `test_ai_human_annotations.gd` |
| 可建模局面、真实动作环境、隐藏信息与条件神枪留费 | `test_ai_environment.gd` |
| 按对手自机分类、实验模型选择与通用回退 | `test_ai_matchups.gd`、`tools/ai/test_matchup_models.py` |
| 发行 AI 自机对策、灵梦封印留费／凭依夜王、系缚阵牺牲 | `test_release_counterplay.gd` |
| 灵梦小单位试探、实伤补枪与夜王兑换核心 | `test_reimu_probe_ai.gd` |
| 本机试验 AI 开关、实战调用与安装版禁用 | `test_experimental_ai.gd`、`test_experimental_ai_ui.gd` |
| 八云蓝减费开关 | `test_ran_discount.gd`、`test_ran_discount_ui.gd` |
| 杀人玩偶空场自动跳过开关、独立状态及联机同步 | `test_murder_dolls_skip.gd`、`test_murder_dolls_skip_ui.gd`（加 `-- --android` 验证安卓界面） |
| 颜色盘诅咒任意减费、废线支付与联机校验 | `test_curse_discount.gd`、`test_curse_discount_ui.gd` |
| 椛的宣称与支付限制 | `test_momiji.gd`、`test_momiji_ui.gd` |
| 符卡伤害预览 | `test_spell_damage_preview.gd`、`test_spell_damage_preview_ui.gd` |
| 游星弹幕与平安京卡图 | `test_wandering_barrage.gd`、`test_unknown_card_art_ui.gd` |
| 额外条件提示 | `test_card_condition_hints.gd`、`test_card_condition_hints_ui.gd` |
| 阵雨与火的磨牌触发 | `test_rain_fire_mill.gd` |
| 测谎仪抓牌、低费使用与非抓牌入手 | `test_lie_detector.gd` |
| 响应与攻击快捷键 | `test_response_shortcut.gd`、`test_attack_shortcut.gd` |
| 安卓触控、返回及桌面差异 | `test_android_controls.gd` |
| 安卓战斗选项空间、莉莉黑颜色选择与堆叠区避让底部操作 | `test_android_battle_choices.gd`、`test_android_battle_layout.gd` |
| 安卓弹窗容量、60 个长选项、40 项右侧菜单、联机堆叠避让及空颜色盘提示 | `test_android_popup_capacity.gd` |
| 联机状态保存与投影 | `test_network_state.gd` |
| 联机战斗悔棋与逐步回放 | `test_network_undo.gd` |
| 回放双方完整手牌与结束后同步 | `test_replay_hands.gd`、`test_replay_hands_ui.gd` |
| 回放训练标注、文件与界面 | `test_replay_training.gd`、`test_replay_training_ui.gd` |
| 联机与断线恢复 | `test_network.gd`、`test_disconnect_wait_ui.gd` |
| 双端移除网络聊天、旧聊天消息忽略及局域网／云端玩家和观战界面 | `test_network_chat_removed.gd`、`test_network_chat_removed_ui.gd` |
| 联机界面与主副卡组调整 | `test_network_ui.gd` |
| 卡组异画、选择界面与联机同步 | `test_alternate_art.gd`、`test_alternate_art_ui.gd`、`test_alternate_art_network.gd` |

在项目根目录选择与本次改动相关的入口运行，例如：

```powershell
& '.\.godot-toolchain\editor\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/test_ran_discount.gd
```

新增发行卡组补发：`test_bundled_deck_updates.gd` 覆盖旧目录、空卡组目录、已有改名/修改卡组、重复启动与主动删除；`test_card_search_aliases.gd`、`test_card_search_aliases_ui.gd` 覆盖转转、夜雀及烤八目鳗。`tools/check-release-package.ps1` 对实际 PCK 验证卡组、升级清单、AI 脚本加载与蕾米调度行动。

正式模板的卡组交付和人机界面检查使用 `tools/check-release-runtime.ps1 -ExePath <导出的EXE路径>`；它将 EXE 的原样副本与隔离验证入口放在 `work/release-deck-runtime/`，挂载未修改的游戏 PCK，执行 `test_release_deck_runtime.gd`，不读写玩家安装目录。

仅检查语法与加载关系时，在命令中加入 `--check-only`。不要批量运行历史版本测试，也不要为通过测试而恢复过时预期。
