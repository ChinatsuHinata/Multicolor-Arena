# fx/ —— 模块化特效层

完整方法论见 [`docs/特效开发方法论.md`](../docs/特效开发方法论.md)。这里只放速查。

当前内置灵梦入场「阴阳玉·聚散」和符卡「梦想妙珠」两个特效，均为香霖堂的免费商品。登录领取后默认启用，可在「我的商品」关闭，下一场对战生效；联机按服务器核验的双方装备分别播放。清单中的 `free` 表示无需领取即可播放，与商品的免费价格不同。

## 加一个特效

0. 设计参考：卡牌数据库 `cards/<卡牌id>.json` + 卡图 `recourse/数据库/<卡牌id>.png`（权威，效果与配色以此为准），以及 [THBWiki 东方百科](https://thbwiki.cc/) 对应人物 / 符卡页（弹幕形状、配色、母题）。详见方法论第 10 节。

1. `fx/definitions/<id>.json` —— 按方法论中的清单示例填写 `id` / `category` / `script` / `params`，目录不存在时先创建。
   - 只给部分卡用：加 `"cards": ["<卡牌id>", …]`，省略即所有卡。
   - 入场时间点：`"timing": "before"`（单位牌出堆叠、飞向战场时开播）或 `"after"`（缺省，落场后开播）。
   - 角色符卡（仅 `spell`）：`"character_spell": true`、`"character": "<角色名>"`、`"origin": "character"|"none"`、`"destination": "spell_target"|"none"`；起点排序：套牌自机 > 自机单位 > 颜色值高 > 卡牌 id 小（再按 uid 小）。
   - 演出占用（仅 `spell`）：`"hold_ms"` 0–5000，缺省为整段 `budget_ms`。特效播到这个时刻之前公开演出队列停住，目标死亡、区域移动要等动画结算后才显示。
2. `fx/modules/<id>/effect.gd` —— 继承对应品类基类，实现 `_build()` 与 `_frame(delta)`。
3. `fx/assets/<id>/` —— 需要生图素材时放这里，模块用 `texture("ring.png")` 取。

不需要改其它任何文件。

## 三个品类基类

| 品类 | 基类 | 挂在哪 | 关键约束 |
| --- | --- | --- | --- |
| `entrance` | `categories/fx_entrance_module.gd` | 花牌视觉根 | 只加子节点，不改卡面材质与碰撞 |
| `foil` | `categories/fx_foil_module.gd` | 花牌视觉根 | 平面 y ∈ [0.019, 0.055]，不替换 Face |
| `spell` | `categories/fx_spell_module.gd` | `FxLayer_spell` | 中心取 `ctx.center`，不碰卡牌与结算 |

### 飞行追踪（flight）

清单 `flight` 仅用于 `entrance`：`none`（缺省）、`track`（追踪）、`proxy`（用 3D 代理卡接管飞行画面）。`track` / `proxy` 必须配 `timing: "before"`。同一次播放只由优先级最高的可接管模块创建代理卡。

`ctx.flight` 是可选字典，键也全部可选：`from` 为含缩放的全局 `Transform3D` 起点，`to` 为全局终点（缺省 `ctx.landing`），`seconds` 为时长（缺省 `travel_seconds()`），`ease` 为 `cubic_in_out`（缺省）、`sine_in_out` 或 `linear`，`texture` 为 `Texture2D` 卡面，`color` 为无贴图时的纯色 `Color`。无 `from` 时实时追踪有效且在树内的 `ctx.node`，再退回落点。

基底 API：`flight_seconds()` 返回飞行时长（非 before 为 0）；`flight_global(t)` / `flight_local(t=-1)` 返回全局 / holder 本地位姿；`in_flight(t=-1)` 判断是否仍在飞行；负的默认时间使用 `elapsed`。`owns_flight()` 判断是否持有代理卡；`card_landed()` 标记落场并隐藏代理卡。holder 保持钉在落点，代理卡到达后停留，直到落场通知或模块收尾。`FlightProxy` 占 1 节点，在模块建造检查之后创建，所以 `flight=proxy` 模块自身节点须 ≤63。

清单 `flight_ms`（200–2000 ms）仅适用于 `flight: "proxy"`，本体据此放慢该牌飞行；`unit_departing` 返回接管飞行的秒数，未接管返回 0.0。`flight_ease` 也仅适用于 proxy，取值为 `cubic_in_out`、`sine_in_out`、`linear`。

本体由 `duel_reveal` 把 source（SubViewport 像素 `point` / `pixel_height` 与 `texture`）传给 `unit_departing`；返回值 >0 时隐藏 2D 飞行贴图，并用返回的秒数做该牌飞行补间。`sync()` 建好落场的 3D 卡后调用桥的 `unit_landed(uid)`，经舞台通知模块隐藏代理卡；桥的 `owns_flight(modules)` 汇总接管结果，`flight_seconds(modules)` 返回接管模块的最长飞行秒数。

## 验收

```bash
Godot --headless --path . --script tests/test_fx_module.gd -- --only=<id>
Godot --headless --path . --script fx/fx_showcase.gd -- --only=<id> --png=work/fx/<id>.png
```

## 基底文件

- `fx_manifest.gd` 清单校验（`validate` / `load_all`）
- `fx_registry.gd` 发现、实例化、启用判定（`enabled(category, products)`）
- `fx_module.gd` 生命周期、预算、节点上限、确定性时钟、素材加载
- `fx_stage.gd` 每场一个舞台，三个命名层
- `fx_bridge.gd` 本体唯一接口：`unit_entered` / `card_face_built` / `spell_resolved`
- `fx_showcase.gd` 单特效预览与截图

改这些文件属于"改基底"，需同时跑全量 `test_fx_module`。
