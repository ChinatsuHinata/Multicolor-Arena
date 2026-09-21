from pathlib import Path
import hashlib, json, re

root=Path(r'C:\Users\tzx20\Documents\test').resolve()
plan=json.loads((root/'work/v097-migration.json').read_text(encoding='utf-8'))
queue=root/'recourse/新增卡片'
current={p.relative_to(queue).as_posix():hashlib.sha256(p.read_bytes()).hexdigest().upper() for p in queue.rglob('*') if p.is_file()}
expected={name:hashval for name,hashval in plan['pending_before'].items() if name not in ['image177.png','image177.png.import']}
assert current==expected, 'Unregistered pending files changed'
for row in plan['moves']:
    source=Path(row['source']); target=Path(row['destination'])
    assert not source.exists() and target.is_file()
    assert hashlib.sha256(target.read_bytes()).hexdigest().upper()==row['sha256']
    before=json.loads((root/'work/v097-backup/cards'/f"{row['id']}.json").read_text(encoding='utf-8-sig'))
    after=json.loads(Path(row['definition']).read_text(encoding='utf-8-sig'))
    before.pop('图片'); after.pop('图片')
    assert before==after, f"Rule data changed: {row['id']}"
    sidecar=Path(str(target)+'.import')
    assert f'source_file="{row["image"]}"' in sidecar.read_text(encoding='utf-8-sig')
registered=json.loads(re.search(r'^const IDS=(\[[^\]]*\])',(root/'scripts/card_database.gd').read_text(encoding='utf-8-sig'),re.M)[1])
assert registered==plan['ids']
save_hash=hashlib.sha256((root/'saves/decks.json').read_bytes()).hexdigest().upper()
assert save_hash==plan['save_sha256']
log=(root/'work/v097-database.log').read_text(encoding='utf-8-sig')
assert '140 checks; 0 failures' in log
assert not [line for line in log.splitlines() if any(s in line for s in ['SCRIPT ERROR','SHADER ERROR','ERROR:']) and 'Failed to read the root certificate store.' not in line]
report=f'''v0.9.7 database migration
65 registered IDs unchanged.
65 images moved to recourse/数据库 using stable IDs; SHA256 unchanged.
65 definitions unchanged except image path; imported texture metadata source_file updated.
Existing registered card 177 recovered from pending folder, not a new card import.
{len(current)} other pending files ({sum(Path(name).suffix.lower() in ['.png','.jpg','.jpeg','.webp'] for name in current)} images) unchanged by file name and SHA256.
Godot: 140 checks; 0 failures; every registered texture loads; editor and battle tested with card 177.
No project script or shader errors; existing Windows certificate diagnostic only.
Saved decks unchanged: {save_hash}
Screenshot: work/v097-card177-editor.png; work/v097-card177-battle.png
Backup and move manifest: work/v097-backup; work/v097-migration.json
'''
(root/'work/v097-validation.txt').write_text(report,encoding='utf-8')

# Current import reference documents follow the authoritative moved images.
for filename in ['新增卡片导入清单-v0.9.md','新增卡片导入清单-v0.9.5.md']:
    path=root/'docs'/filename
    text=path.read_text(encoding='utf-8-sig')
    for row in plan['moves']:
        text=text.replace(row['old_image'],row['image'])
    if filename.endswith('v0.9.5.md'):
        text=text.replace('素材现已移至`recourse/demo素材`，本清单图片路径与v0.9.6同步。','素材现已归档至`recourse/数据库`，本清单图片路径与v0.9.7同步。')
    path.write_text(text,encoding='utf-8')

with (root/'docs/游戏整体开发计划.md').open('a',encoding='utf-8') as f:
    f.write('''

## 31. v0.9.7：待处理素材与运行时数据库分离

本轮只重构现有65种卡的图片归档与校验，不导入新增卡片目录的待处理卡牌，卡牌规则、ID和存档格式均保持不变。

| 阶段 | 位置与职责 | 进入下一步的条件 |
|---|---|---|
| 待处理 | `recourse/新增卡片/` 存放准备写入游戏的原始图片，不被运行时扫描 | 用户给出导入范围后确定卡牌稳定ID |
| 卡图归档 | 先把指定图片移动至 `recourse/数据库/ID.扩展名`，同步Godot导入配置 | 图片存在且内容校验通过 |
| 规则编写 | `cards/ID.json` 定义资料、费用、图片路径与能力绑定；GDScript实现效果 | 规则与实际交互验证通过 |
| 登记可用 | `card_database.gd` 的IDS登记；清单记录现有卡图路径和SHA256 | 组卡器、对战共用同一数据库 |

运行时拒绝直接引用待处理区或旧demo素材路径，缺失图片报错显示具体图片路径。检查脚本只遍历已登记ID，不扫描或导入新增卡片。数据库卡图使用稳定ID命名，以免原素材文件名和临时目录变动影响游戏。

177号卡已经在原65种卡池内，其图片被放回待处理区导致旧引用失效。本次将其归位到数据库，不算新增卡导入。其余待处理文件保持原样；后续导入仍等待用户指令。文件移动清单与备份分别在work/v097-migration.json和work/v097-backup。
''')

with (root/'docs/卡牌数据库与编写说明.md').open('a',encoding='utf-8') as f:
    f.write('''

## v0.9.7：正式卡图数据库

本节取代旧章节中的demo素材、原新增卡片图片目录约定。正式卡图位于`recourse/数据库/`，以卡牌ID命名；JSON仍在`cards/`，ID登记方式保持不变。素材内容未重采样或覆盖，Godot原有显示归一流程继续生效。

`DEFINITION_DIRECTORY`与`ART_DIRECTORY`集中声明目录。`validate_definition`先检查图片已归档且文件名对应ID，再检查原文件和Godot纹理资源存在；错误包含图片实际路径。不再将待导入文件夹作为运行时卡图来源，也不按同名图片偷偷回退到其他目录。

`tools/check_card_database.py`校验已登记ID、实际文件和`卡图索引.json`中的SHA256，`--write-index`只重建现有卡牌索引。首次入库时必须先移动卡图，再编写规则和登记卡牌；修改规则不能只修改显示原文。新增卡片待处理区本轮暂停导入。
''')

with (root/'开发者日志.md').open('a',encoding='utf-8') as f:
    f.write(f'''

## 2026-09-18 · v0.9.7 卡图数据库归档与177号缺图修复

- 用户要求重构数据库，新增卡片目录作为待写入游戏的素材区，且暂不导入其中的新卡。本轮仅迁移现有65种已登记卡牌，未增加或删除ID、卡牌规则、能力绑定。
- 定位截图错误：cards/177.json仍引用demo素材/image177.png，而原图现在位于新增卡片/image177.png。将这张已登记卡的图片归位，不把它作为新卡再次导入；其余待处理文件全部保持原样。
- 新建recourse/数据库，将64张demo素材卡图和上述177号图移动到此处，按稳定ID命名；同步65份JSON图片引用和Godot导入配置source_file。移动前逐一验证源、目标均在test内、目标未占用、文件SHA256符合清单；移动后65张图片内容哈希不变。未对素材重采样或重画。
- card_database.gd新增集中目录常量，并拒绝直接引用待导入或旧演示目录；要求图片文件名匹配ID。缺图报错包含实际路径，避免只有“图片不存在”无法定位。保持原JSON格式、显式IDS登记及组卡器/对战共用定义方式。
- 建立卡图索引.json（ID、卡名、JSON、图片和SHA256）与数据库README，新增tools/check_card_database.py；默认只读核对，--write-index只更新已登记清单，不扫描待导入目录、不增加卡牌。更新使用说明、编写流程、整体计划第31节和卡图清单路径，明确以后先移动指定卡图再编写规则、测试、登记。
- 备份work/v097-backup，迁移清单work/v097-migration.json。验证全部65份JSON除图片字段外内容与迁移前相同；其余{len(current)}个待处理文件（52张图片及相关配置）名称和内容哈希完全一致。

Godot实测140项零失败：全部65张卡图能实际加载为纹理、卡池无错误、主界面不再出现截图提示、组卡器能预览177号卡，并从手牌正常发动该卡、进入堆叠并结算原有效果。检查待处理路径被拒绝、缺失文件报错含精确路径。已查看work/v097-card177-editor.png，详细验证见work/v097-validation.txt及work/v097-database.log。最终无项目脚本或着色器错误，仅既有系统根证书诊断。

所有变更和验证输出位于test内。玩家saves/decks.json前后SHA256一致：{save_hash}。未修改、保存或恢复玩家卡组；没有开始导入待处理的新卡。
''')
print(report)
