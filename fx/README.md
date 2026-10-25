# fx/ —— 模块化特效层

完整方法论见 [`docs/特效开发方法论.md`](../docs/特效开发方法论.md)。这里只放速查。

当前未内置特效。三个品类的框架与对战接线保留；清单目录为空或不存在时不会播放特效。

## 加一个特效

1. `fx/definitions/<id>.json` —— 按方法论中的清单示例填写 `id` / `category` / `script` / `params`，目录不存在时先创建。
2. `fx/modules/<id>/effect.gd` —— 继承对应品类基类，实现 `_build()` 与 `_frame(delta)`。
3. `fx/assets/<id>/` —— 需要生图素材时放这里，模块用 `texture("ring.png")` 取。

不需要改其它任何文件。

## 三个品类基类

| 品类 | 基类 | 挂在哪 | 关键约束 |
| --- | --- | --- | --- |
| `entrance` | `categories/fx_entrance_module.gd` | 花牌视觉根 | 只加子节点，不改卡面材质与碰撞 |
| `foil` | `categories/fx_foil_module.gd` | 花牌视觉根 | 平面 y ∈ [0.019, 0.055]，不替换 Face |
| `spell` | `categories/fx_spell_module.gd` | `FxLayer_spell` | 中心取 `ctx.center`，不碰卡牌与结算 |

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
