# 当前功能测试

这里只保留验证当前游戏行为的专项测试。旧版本测试入口及配套 `.uid` 已清理，历史文档中的旧测试名称仅为当时的记录，不再作为验证命令。

测试按功能或卡牌命名。`support/` 保存规则、选牌、界面、响应与联机的公共辅助代码，不包含旧版本测试断言，也不单独运行。

常用入口：

| 功能 | 测试 |
| --- | --- |
| 卡库加载 | `test_database_load.gd` |
| 卡牌别名与各处搜索选牌 | `test_card_search_aliases.gd`、`test_card_search_aliases_ui.gd` |
| 对局规则 | `test_duel_rules.gd` |
| 八云蓝减费开关 | `test_ran_discount.gd`、`test_ran_discount_ui.gd` |
| 椛的宣称与支付限制 | `test_momiji.gd`、`test_momiji_ui.gd` |
| 符卡伤害预览 | `test_spell_damage_preview.gd`、`test_spell_damage_preview_ui.gd` |
| 额外条件提示 | `test_card_condition_hints.gd`、`test_card_condition_hints_ui.gd` |
| 阵雨与火的磨牌触发 | `test_rain_fire_mill.gd` |
| 响应与攻击快捷键 | `test_response_shortcut.gd`、`test_attack_shortcut.gd` |
| 联机状态保存与投影 | `test_network_state.gd` |
| 联机战斗悔棋与逐步回放 | `test_network_undo.gd` |
| 联机与断线恢复 | `test_network.gd`、`test_disconnect_wait_ui.gd` |
| 联机界面与主副卡组调整 | `test_network_ui.gd` |
| 卡组异画、选择界面与联机同步 | `test_alternate_art.gd`、`test_alternate_art_ui.gd`、`test_alternate_art_network.gd` |

在项目根目录选择与本次改动相关的入口运行，例如：

```powershell
& '.\.godot-toolchain\editor\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/test_ran_discount.gd
```

仅检查语法与加载关系时，在命令中加入 `--check-only`。不要批量运行历史版本测试，也不要为通过测试而恢复过时预期。
