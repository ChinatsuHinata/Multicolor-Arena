---
name: fx-effect
description: 为 Multicolor-Arena 开发、修改或验收香霖堂特效（单位入场 entrance / 闪卡 foil / 符卡使用 spell）。凡是提到"特效""入场特效""闪卡""符卡特效""fx/""生图素材""fx_showcase"或要给商品绑特效时使用。规定一个特效 = 一份清单 + 一个模块 + 一个素材目录，不动本体，并给出固定的开发与验收步骤。
---

# 香霖堂特效开发

权威来源是 `docs/特效开发方法论.md`（细节、接线原文）与 `fx/README.md`（速查）。本 skill 是执行版；两者冲突时以方法论文档和 `fx/` 下基底代码为准，并提醒用户同步。

## 核心原则

**一个特效 = 一个目录 + 一份清单 + 一个脚本，其余仓库文件一律不动。**

| 任务 | 允许改 | 禁止改 |
| --- | --- | --- |
| 新特效 / 改已有特效 | `fx/definitions/<id>.json`、`fx/modules/<id>/`、`fx/assets/<id>/` | 其它任何文件，包括别的特效目录 |
| 改基底（罕见，需用户确认） | `fx/fx_*.gd`、`fx/categories/*.gd` | 任何 `<id>` 目录 |
| 本体接线 | **已于 2026-10-24 完成，不再动** | `scripts/duel_table.gd`、`scripts/duel_view.gd`、`fx/fx_bridge.gd`、`scripts/rules/*` |

本体里不得出现任何特效 id、材质名、节点名。如果需求逼着你改接线，**先停下**，确认是不是品类选错了（例如"符卡在卡面上发光"是 `foil` 不是 `spell`）；只有新增第四个品类才需要动接线。

## 设计参考资料

定视觉方案（主色、形状母题、节奏）前先查两处，方案里写明取自哪条资料：

1. **卡牌数据库**（仓库内，权威）：`cards/<卡牌id>.json` 与卡图 `recourse/数据库/<卡牌id>.png`。
   - 读 `名称`、`类别`、`颜色`、`角色名`、`称号`、`符卡类型`、`完整说明`/`能力文字`、`能力绑定[].实现`；
   - 按名称或角色查 id：`grep -l '"角色名": "博丽灵梦"' cards/*.json`；
   - 演出要对上卡牌效果：反制、伤害、治疗、抽牌、指向目标等效果决定特效的方向、落点与收尾方式（例如带目标的伤害符卡用 `destination: "spell_target"`），不要做出与效果相反的观感；
   - 卡图用 Read 亲自看，特效主色与卡面配色协调，不遮挡读牌信息。
2. **THBWiki 东方百科**（https://thbwiki.cc/ ，外部，作风格参考）：
   - 查对应人物页（如 `https://thbwiki.cc/博丽灵梦`）与符卡页/符卡列表，取原作弹幕的形状、颜色、运动方式与角色母题（阴阳玉、御币、符札等）；
   - 用 WebFetch 或内置浏览器读页，只提炼设计要点写进规格，不整段搬运百科文字，不下载或直接使用百科图片作素材（素材按下文规格自行生图）；
   - 百科设定与卡牌数据冲突时，**以卡牌数据库为准**（效果、颜色、名称都看 `cards/`）。

## 固定流程

0. **查资料**：按上节读卡牌 json / 卡图与 THBWiki 人物、符卡页，定主色与母题。
1. **判品类**（选错全部返工）：
   - `entrance`：单位进场，挂花牌视觉根，400–700 ms；清单 `timing` 选时间点：`before`（单位牌出堆叠、正飞向战场时开播，可放到 900–1100 ms）或 `after`（缺省，卡牌落场后开播）；
   - `foil`：卡面持续流光，挂花牌视觉根，常驻不自动收尾；
   - `spell`：符卡结算（未被反制、目标未失效）时在台面演出，挂 `FxLayer_spell`，700–1200 ms。
2. **写清单** `fx/definitions/<id>.json`（目录不存在就建），定 `params` 初值。
3. **写模块** `fx/modules/<id>/effect.gd`，先只用纯色几何跑通验收，不等素材。
4. **跑单特效验收 + 预览截图**，确认读牌信息不被遮挡。
5. **要素材时**按下方规格生图 → 落到 `fx/assets/<id>/` → `--import` → 再跑一次单特效验收。
6. **全量 `test_fx_module` + 缩进检查**，再提交。

按本仓库 CLAUDE.md：视觉设计（版式、配色、时长、缓动）由 Claude 定成写死数值的规格；大批量落地可交给 `codex` 子代理，提示词里必须附仓库约束（1 空格缩进、禁 Tab、不改 `net/rules_manifest.json` / `saves/` / `deck/`、`.uid` 与 `.import` 不手写）。

## 清单格式

```json
{
  "id": "sakura_ring",
  "category": "entrance",
  "name": "樱环入场",
  "description": "一句话给商店与日志看。",
  "script": "res://fx/modules/sakura_ring/effect.gd",
  "budget_ms": 620,
  "priority": 10,
  "free": true,
  "asset_dir": "res://fx/assets/sakura_ring/",
  "cards": ["70"],
  "timing": "after",
  "params": { "petals": 14, "color": "#f9c9d8" }
}
```

`fx/fx_manifest.gd` 校验（违规进 `errors`，不崩溃）：
- `id` = 文件名，2–40 位 `a-z0-9_`；`category` ∈ `entrance|foil|spell`；
- `script` 必须在 `res://fx/modules/` 下且文件存在；`asset_dir` 必须在 `res://fx/assets/` 下；
- `budget_ms` 50–5000，缺省 700（foil 不用）；`free` 为 bool；`params` 为对象；
- `cards`（可选）：卡牌 id 字符串的非空数组，只让这些卡触发；省略 = 所有卡。由 `fx_registry.enabled(category, products, card_id)` 筛选，模块里不要自己比对 `ctx.card_id`；`allow_all` 预览忽略筛选；
- `timing`（可选，仅 entrance）：`before` | `after`，缺省 `after`；
- `flight`（可选，仅 entrance 且 `timing: before`）：`none`（缺省）| `track`（模块用 `flight_local(t)` 追踪对抗区→战场飞行的卡牌位姿）| `proxy`（再由基底画一张 3D 代理卡 `FlightProxy` 接管飞行画面，本体隐藏 2D 飞行贴图，阴阳玉等可绕到卡前/卡后；占 1 节点，模块自身 ≤63）。API：`flight_seconds()`、`flight_global(t)`、`flight_local(t)`、`in_flight()`、`card_landed()`，细节见 `fx/README.md`；`flight_ms`/`flight_ease`（仅 proxy）可放慢并改写这段飞行。
- 角色符卡（仅 spell）：`"character_spell": true`、`"character": "<角色名>"`、`"origin": "character"|"none"`、`"destination": "spell_target"|"none"`；起点排序：套牌自机 > 自机单位 > 颜色值高 > 卡牌 id 小（再按 uid 小）；
- `hold_ms`（仅 spell）：0–5000，缺省为整段 budget；在此之前演出队列停住，目标死亡、区域移动等动画结算后才显示。
- **视觉参数只放 `params`**，调色/数量/半径改这里，不改脚本。
- 收费：加 `shop_product: "<商品id>"`，或在 `data/shop.json` 商品上写 `"fx": "<特效id>"`。启用判定在 `fx_registry.enabled()`，只读 `battle_loadout()` 冻结快照。联机不校验特效商品（扩展 `MCA:fx:` 签名域属协议改动，不是特效任务）。

## 模块契约

继承品类基类，只实现 `_build() -> bool` 与 `_frame(delta)`：

```
configure(def, ctx) → start() → [advance(delta) …] → stop()
```

- 所有节点建在 `holder` 下（基类建的 `Fx_<id>`），总数 ≤ 64，超了 `start()` 失败。
- **时间只用 `elapsed` / `progress()`**（foil 用 `phase()`）；禁止 `Time.get_ticks_*`，着色器禁止用 `TIME` 当主时钟，改传 uniform。
- **随机只用 `rng`**（基类按 `id:uid` 播种）；禁止全局 `randf()`。
- **缺素材必须能跑**：`texture()` / `sprite_plane()` 找不到文件返回 null 并记 warning，模块退回纯几何/纯色。
- 模块里不得出现 `duel_table`、`duel_view`、`main.gd`、`scripts/rules`、`CARD_SIZE`、`Time.get_ticks`（测试会 grep）。尺寸用 `card_size()`。
- 基类辅助：`additive_material(color)`、`make_plane(parent, at, size, mat)`、`sprite_plane(parent, at, size, file, tint, uv_scale)`、`texture(file)`。

| 品类 | 基类 `extends` | 辅助 | 硬约束 |
| --- | --- | --- | --- |
| entrance | `res://fx/categories/fx_entrance_module.gd` | `envelope()` 0→1→0、`radial_plane(scale, y, mat)`、`land_seconds()`（落场时刻：before 为飞行时长 `ctx.travel`，after 为 0）；有 `ctx.landing` 时 holder 自动钉在落点 | 只加子节点；不改 `Face`/`Halo`/`Outline`/`SummoningMist` 材质与 `Hit` 碰撞；建议 y 0~0.02 |
| foil | `res://fx/categories/fx_foil_module.gd` | `phase()` 0..1（周期 `params.cycle`，默认 2.4 s）、`foil_plane(scale, y, mat)` | 平面 y ∈ [0.019, 0.055]；不替换 `Face.material_override`、不读写卡图；透明度建议 ≤ 0.6 |
| spell | `res://fx/categories/fx_spell_module.gd` | `burst()`、`center()`、`spell_plane(scale, y, mat)` | 挂 `FxLayer_spell`；位置取 `ctx.center` 并自己应用到 `holder`；不碰卡牌、堆叠、结算 |

GDScript 缩进每级 1 个空格。最小模块骨架（entrance）：

```gdscript
extends "res://fx/categories/fx_entrance_module.gd"

var ring: MeshInstance3D

func _build() -> bool:
 var tint=Color(str(params.get("color","#f9c9d8")))
 # 缺 ring.png 时 sprite_plane 退回纯色加法平面，满足无素材降级
 ring=sprite_plane(holder,Vector3(0.0,0.01,0.0),card_size()*1.2,"ring.png",tint)
 return true

func _frame(_delta: float) -> void:
 var e=envelope()
 ring.scale=Vector3.ONE*(0.6+0.6*progress())
 var m: StandardMaterial3D=ring.material_override
 m.albedo_color.a=e
```

## 生图素材

只落在 `fx/assets/<id>/`，模块按固定文件名取，换图不改代码：

| 文件 | 用途 | 规格 |
| --- | --- | --- |
| `ring.png` | 环/光圈 | 512×512，正中，边缘全透明，径向对称 |
| `sprite.png` | 花瓣/火星/符文 | 256×256，居中，留 8 px 透明边 |
| `sweep.png` | 扫光带 | 1024×256，左右无缝平铺 |
| `burst.png` | 爆点/闪白 | 512×512，中心径向 |

提示词写死：纯黑或透明背景，无背景/文字/边框；单一元素居中占 60–80%；不画运动模糊与拖影；只用主色樱 `#f9c9d8`、绯 `#e2604f`、金 `#e9c175`、白 `#fbf2f0`，其它色靠 `tint`。落盘后运行 `--import` 生成 `.import`，不手写。

## 验收命令

`GODOT=.godot-toolchain/editor/Godot_v4.7.2-stable_win64_console.exe`

```bash
$GODOT --headless --path . --script tests/test_fx_module.gd -- --only=<id>     # 本特效
$GODOT --headless --path . --script tests/test_fx_module.gd                    # 全量清单
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/check-gdscript-indent.ps1
$GODOT --path . --script fx/fx_showcase.gd -- --only=<id> --png=work/fx/<id>.png  # 预览截图（非 headless，可加 --at=<秒>）
$GODOT --headless --path . --import                                            # 新增素材后
```

`tests/test_fx_integration.gd` 只在改了基底（`fx/fx_*.gd`、`fx/categories/*`）或本体接线时跑；新增特效**不跑**。

截图生成后用 Read 打开 PNG 亲自看，不只看测试"通过"。

## 交付前核对

- [ ] 清单过 `Manifest.validate`，`id` 与文件名一致
- [ ] 节点 ≤ 64，全部在 `holder` 下
- [ ] 无本体引用；时间只用 `elapsed`，随机只用 `rng`
- [ ] 删掉素材仍能跑（纯几何降级，不报错不空白）
- [ ] entrance/spell 到 `budget` 自动收尾，父节点无残留
- [ ] foil 平面全在 y ∈ [0.019, 0.055]，未替换 `Face` 材质
- [ ] spell 挂在 `FxLayer_spell`，中心来自 `ctx.center`
- [ ] 跑两次画面一致（确定性）
- [ ] 预览截图里卡面信息清晰可读
- [ ] `git status` 的改动只落在 `fx/definitions/<id>.json`、`fx/modules/<id>/`、`fx/assets/<id>/`（以及 Godot 生成的 `.uid` / `.import`）

单特效验收不以"全仓库测试全绿"为标准，那是合入前的整体回归。
