from pathlib import Path
import json,re,hashlib
R=Path(__file__).resolve().parents[1];O=R/'work/v014';B=R/'work/v014-backup'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
tests=[];matches=[]
for p in sorted(O.glob('*.log')):
 s=p.read_text(encoding='utf-8');errors=[l for l in s.splitlines() if ('ERROR:' in l or 'SCRIPT ERROR' in l) and 'root certificate' not in l]
 assert not errors,(p.name,errors)
 found=re.findall(r'(\d+) checks; (?:0|\[\]) failures',s)
 if found:tests.append({'log':p.name,'checks':int(found[-1]),'failures':0})
 elif '_matches' in p.name:
  found=re.search(r'MATCHES: (\d+).*?; 0 unfinished',s);assert found,p.name
  matches.append({'log':p.name,'completed':int(found[1]),'unfinished':0})
 else:assert p.name=='test_v013_load.log' and 'DATABASE 486' in s and 'ENGINE OK 494' in s
checks=sum(t['checks'] for t in tests);games=sum(t['completed'] for t in matches)
assert checks==1063 and games==20,(checks,games)
preserved={}
for rel in ['saves/decks.json','data/test_precons.json']:
 assert sha(R/rel)==sha(B/rel),rel
 preserved[rel]=sha(R/rel)
result={'version':'v0.14','date':'2026-09-19','checks':checks,'failures':0,'tests':tests,'matches':matches,'complete_matches':games,'saved_files_unchanged':preserved,'database_cards':486,'new_card_definitions':0,'presentation_hold_seconds':1.0,'melodies_covered':13,'screenshots_reviewed':['battlefield-layout.png','settings-center.png','hand-reveal.png','top-reveal.png','bottom-reveal.png'],'project_errors':[],'environment_diagnostics':['Windows root certificate store read warning']}
(O/'validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def append(rel,s):
 p=R/rel;old=p.read_text(encoding='utf-8-sig');assert s.splitlines()[0] not in old
 p.write_text(old.rstrip()+'\n\n'+s.strip()+'\n',encoding='utf-8')
p=R/'使用说明.md';s=p.read_text(encoding='utf-8-sig')
s=s.replace('# 极彩 Multicolour · v0.13','# 极彩 Multicolour · v0.14',1)
s=s.replace('可右键看牌、查看墓地或缩放','可右键看牌、查看墓地；镜头固定在最近档')
s=s.replace('右侧出现3列卡图','右侧出现与左侧预览等大的2列卡图')
s=s.replace('关键词不附加解释，无能力牌留空。','关键词不附加解释，无能力牌留空。实际实例拥有的指示物显示在原文之后，属性指示物合并为“+X/+X/+X”或“-X/-X”，其他指示物按名称和数量显示。')
s=s.replace('- `scripts/duel_hand_card.gd`：','- `scripts/duel_reveal.gd`：公开展示队列、逐张翻牌、一秒正面停留和临时手牌公开。\n- `scripts/duel_hand_card.gd`：')
p.write_text(s,encoding='utf-8')
append('使用说明.md','''## v0.14 展示与战场布局

展示的牌逐张播放，正面完整停留1秒。展示手牌时仅对应牌临时公开，随后恢复原来的隐藏状态；牌库顶/底每次均翻牌，重复展示同一张也重新播放。牌库底从最底下的一张开始展示。展示期间暂停自动推进及提交新行动，播放完后继续原有目标选择、支付或结算。

战场与手牌区水平居中，镜头固定最近档，滚轮只滚动牌堆等窗口。左右查看窗口均为218×660，右侧每行2张卡，调试模式也可完整看到4行。顶部对手手牌独立排列，不遮挡场地。

双方单位在中央前排；道具在各自后排左半边，结界与时符在后排右半边横放；颜色盘在最后一排。这四类使用同一张卡尺寸。乐章横放于中央两侧，我方使用右侧，对方使用左侧。场上只留一个乐章，所以两侧不会各放一个生效乐章。

按2.34f，新乐章生效进场时，无论旧乐章由谁操控，均将其作为规则动作送到原拥有者墓地。这个替换不入堆叠，不属于消灭；新乐章被反制时不替换旧乐章。调试直接摆放也保持唯一性，同时继续不触发进离场效果。

左侧预览新增完整指示物列表，包括属性、自机、计时、贫穷、惊吓、勇气、梦违、狂乱和各色指示物。改变数量、移除指示物或换区时自动刷新。
''')
append('docs/游戏整体开发计划.md',f'''## 37. v0.14：展示队列与固定战场布局

展示从文字记录提升为独立表现状态。规则层 `reveal_card` 保存公开卡的实例快照、区域和事件序号；视图通过 `duel_reveal.gd` 逐张消费，翻面后停留1秒。规则效果仍同步确定结果，表现期间冻结对战输入/人机推进，结束后恢复原待决选择。动画不额外换区、改费用或永久公开隐藏牌；已经换区的对象也能根据原快照从正确位置展示。

布局集中在 `duel_view.gd` 的 STAGE/HAND/INSPECTION/SIDEBAR 和 `duel_table.gd` 的 FIELD_SCALE、field_group、field_position。战场与手牌水平中心均为800，左右查看区尺寸相同；固定最近距离0.77，视角35度并调整取景目标，确保完整桌垫和颜色盘都在视野内。单位、道具、结界/时符、颜色盘按用户示意图分区，卡片统一大小，结界/时符和乐章默认横放。

乐章唯一性集中为 `enter_field` / 批量进场入口中的 `replace_melody`，覆盖全部13种乐章。规则动作立即执行但保留正确的离场通知；反制未生效的乐章不替换。调试摆放执行无触发版本。预览由实例指示物快照构建，显示合计属性修正和命名计数。

本轮{checks}项检查通过，20场自动对局结束，包含真实输入、逐张停留计时、底牌顺序、公开后重新隐藏、展示期间防操作、乐章反制/所有权、固定镜头全图可见和旧战斗回归。未来新增“展示”效果必须使用统一入口；单纯允许某玩家查看隐藏牌的权限不等同于向所有人公开展示。
''')
append('开发者日志.md',f'''## 2026-09-19 · v0.14 展示动画、战场分区与乐章唯一性

- 按用户两张示意图调整：战场/手牌居中，左右查看框统一218×660，右侧从3列改为2列；对手手牌缩小并独立排在场地上方。镜头固定最近距离0.77，取消滚轮缩放，微调视角和观察目标。初次截图发现颜色盘下缘被裁切，调整后通过桌垫四角及16张双方颜色盘卡完整可见检查。
- 单位、道具、结界/时符、颜色盘统一FIELD_SCALE=0.76。中央单位前排、己方道具后排左侧、结界/时符后排右侧横放、颜色盘最后一排；对手镜像布置。乐章独立横放在中央两侧，我方右、对方左。自机与牌库仍贴合印刷位置。
- 新增duel_reveal.gd。各批旧卡和新卡的公开展示统一走reveal_card快照队列；每张翻开后正面停留1秒，重复展示不去重。手牌只临时公开被展示的一张；牌库顶/底有翻出动画，底部按实际最底牌开始。期间阻止其他行动和人机推进，结束后恢复原选择；不修改卡牌区域或赋予永久查看权限。
- 将2.34f落实到通用乐章进场，不再只由红色幻想乡处理。覆盖13种乐章：任一新乐章生效即以规则动作替换全场旧乐章，送入原拥有者墓地；不作为消灭，不另入堆叠，被反制的新乐章不替换。正常、效果批量进场和调试摆放均维护唯一性，调试继续不触发效果。
- 左侧卡牌原文之后展示实例上全部已实现的指示物。正属性合并为+X/+X/+X，负属性为-X/-X；自机、计时、贫穷、惊吓、勇气、梦违、狂乱、颜色按名称和数量列出。缓存签名包含全部指示物，原实例数量改变也刷新。
- 新增规则55项、真实图形UI49项；连同旧规则、复杂效果、支付、选牌、调试、先制和界面回归共{checks}项零失败，20场自动对局完整结束。原测试对3列、9张可见卡和可缩放镜头的断言按本次明确要求更新为2列、4行和固定镜头；旧UI等待函数等待公开展示完毕后再继续操作。初始测试夹具缺少modifiers初始化和put参数已修正并重跑。最终没有项目脚本、资源或着色器错误，仅既有Windows根证书诊断。
- 已查看战场布局、设置居中、手牌展示、牌库顶/底展示截图。验证汇总work/v014/validation.json，备份work/v014-backup。更新使用说明与整体计划第37节。数据库仍486条，卡图索引检查通过；原六副卡组、两套预组模板逐字节未变。所有文件操作、测试与记录均在test内。
''')
print(json.dumps({'checks':checks,'complete_matches':games,'saved_files_unchanged':True,'documents_updated':3},ensure_ascii=False))
