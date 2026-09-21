from pathlib import Path
import re
import hashlib

root=Path(r'C:\Users\tzx20\Documents\test')
logs=['v096-rules.log', 'v096-final-test_v096.log']
for case in ['test_v095_rules','test_v09_rules','test_v09_matches','test_v07_matches','test_v095_edges','test_v095','test_v094','test_v093','test_v092','test_v08','test_v082','test_v081','test_v09_ui','test_v06']:
    prefix='v096-final-' if case in ['test_v094','test_v081'] else 'v096-regression-'
    logs.append(prefix+case+'.log')
lines=[]
total=0
for filename in logs:
    text=(root/'work'/filename).read_text(encoding='utf-8-sig')
    matches=re.findall(r'(\d+) checks; (\d+) failures',text)
    assert matches, filename
    checks, failures=map(int,matches[-1])
    assert failures==0, filename
    errors=[line for line in text.splitlines() if any(tag in line for tag in ['SCRIPT ERROR','SHADER ERROR','Parse Error','ERROR:']) and 'Failed to read the root certificate store.' not in line]
    assert not errors,(filename,errors)
    total+=checks
    lines.append(f'{filename}: {checks} checks; {failures} failures')
digest=hashlib.sha256((root/'saves/decks.json').read_bytes()).hexdigest().upper()
assert digest=='C420771B0D716506CF3115B44C6DD99FA97B64B46F71B1AE2DC3570DCA01EB7A'
lines += [f'Total: {total} checks; 0 failures', 'Selected final logs contain no project script or shader errors.', 'Existing Windows root-certificate diagnostic remains.',f'saves/decks.json SHA256: {digest}',
    'Earlier failed v096-regression-test_v081.log is superseded by v096-final-test_v081.log. Its one-second fixed wait was replaced by waiting for combat animation completion; this accounts for the new required damage hold.',
    'Visual review: v096-pile-grid.png, v096-deck-tab.png, v096-hybrid-payment.png, v096-first-strike-negative-health.png, v096-damage-allocation-centered.png, v096-debug-destination.png, v094-trigger-order.png.']
(root/'work/v096-validation.txt').write_text('\n'.join(lines)+'\n',encoding='utf-8')
entry=f'''

## 2026-09-18 · v0.9.6 混色支付、先制伤判、区域标签与直接调试拖动

- 将设置之外的行动选择、同时触发排序、区域选牌、伤害分配和结果面板统一居中。标题随面板尺寸居中，少于三张的选项卡面也居中排列；伤害分配保持无边框，常驻对局按钮继续在右侧。
- 按用户确认更新封兽ぬえ：红／蓝／绿任意组合总计3点，另加1黑；牌色为红蓝绿黑，放入颜色盘时可选四色之一支付一点。新增color_cost.gd，卡牌JSON支持斜线混色组，自动支付搜索与手动预留、撤回、最终校验一致，不再使用3红＋1黑的暂定数据。
- 战斗伤害按独立damage_batch记录计算后的数值快照。碰撞后刷新双方数字，保留1秒，负血量不截断，再同步所有死亡单位离场。先制与普通伤判分别展示，死亡者不再参与后续伤判；普通伤判无人可造成伤害时直接结束。拒绝伤害窗口中的重复提交，避免先制被重复执行。动画期间暂停输入及自动推进，包括测试快速模式。
- 左侧卡片预览和右侧牌堆窗口开局关闭。移除常驻的牌库／墓地／除外按钮与调试双方牌库快捷按钮，直接点击战场上相应牌堆查看。右侧改为3列卡图、滚轮上下浏览，一屏至少9张完整卡图，不重复卡名和牌文；右键其他区域关闭，点击另一牌堆切换，普通牌库保持隐藏。
- 手卡区增加条件标签：只有墓地、除外或牌库当前存在合法可用卡牌时才显示。切换后直接点击对应卡面，沿用私有选目标、确认、支付、取消流程；可用动作消失后回到手牌。灵乌路空对应的Hell's Tokamak从牌库标签使用，旧open_deck_casts入口也转入标签，不再打开缺少取消出口的模态框。
- 用户补充灵乌路空“在场时就无法继续回合”。单独在场的探针未复现原始卡死；确认并移除了两个可能阻断推进的UI路径：旧牌库可用牌模态窗口、单纯牌堆浏览暂停自动执行权。新增实际鼠标验证灵乌路空在场、浏览牌库、结束主要阶段、取消牌库符卡和正常使用牌库符卡均可完成；规则测试同时覆盖其死亡群伤处理。没有据此宣称复现了用户原对局的唯一根因。
- 调试拖动可直接从手牌、场上永久物、自机和实体堆叠牌开始，也保留牌堆列表来源。按原合法性约束移到手牌、战场、颜色盘、墓地、除外、自机区或牌库；移入牌库一律放顶，同区域牌库拖放也可重排到顶。拖动卡图上方显示目的区域。保持静默换区，不付款、不新增堆叠、不触发进离场。空除外区仍可作为调试落点，放入后显示。
- 除外槽移到各自自机区下方，空时隐藏模型、数字及碰撞，有卡时显示；对手区域按其朝向镜像。
- 发现50张卡图已从新增卡片目录移动到demo素材，而JSON仍指向旧路径；按唯一同名素材修复50条图片路径。完整映射work/v096-relocated-art.json，65张卡图均验证存在；未移动、替换或重复生成素材。
- 更新使用说明、整体计划第30节、卡牌数据库编写说明及四张新增卡清单。修改前备份work/v096-backup/。原牌组文件保留，测试使用内存卡组，不保存或还原旧牌组。

最终验证{total}项零失败，详见work/v096-validation.txt。新增混色／先制／灵乌路空／牌顶／素材规则98项、真实图形交互57项；回归涵盖卡池、完整对局、区域与目标选择、三档响应、战斗、观察、组卡及长期运行。8场扩展卡池对局全部结束；长期图形场景463次动作、23回合完成，画面非纯黑或纯白且节点数量有界。长期压力测试缩短展示停留，独立图形测试保留正式1秒停留并检查0.6秒仍在场、1.15秒后离场。

旧阻挡测试以固定1秒等待整段战斗动画，新增长1秒停留后等待不足，导致读取尚未同步的测试对象；已改成等待动画完成并通过最终20项检查。混色费用初次断言的JSON浮点字典与整数字典整体比较不一致，改为检查实际各费用值；正常支付规则及UI混色支付均独立通过。最终选用日志无项目脚本或着色器错误，仅既有系统根证书读取诊断。

已实际查看最终牌堆网格、牌库标签、混色支付、负血量、居中伤害分配、居中触发排序及拖动目的区域截图。所有修改和输出均在test文件夹内。玩家saves/decks.json开发前后SHA256一致：{digest}。
'''
path=root/'开发者日志.md'
assert '## 2026-09-18 · v0.9.6 ' not in path.read_text(encoding='utf-8-sig')
with path.open('a',encoding='utf-8') as file: file.write(entry)
print('\n'.join(lines))
