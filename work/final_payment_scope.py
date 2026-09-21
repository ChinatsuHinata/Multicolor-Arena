from pathlib import Path
p=Path(r'C:\Users\tzx20\Documents\test')
f=p/'scripts/duel_view.gd';s=f.read_text(encoding='utf-8-sig').replace(' if auto_pay and solution.ways==1:', ' if auto_pay and (solution.ways==1 or engine.cards[c.card_id].kind!="符卡"):');f.write_text(s,encoding='utf-8')
f=p/'使用说明.md';s=f.read_text(encoding='utf-8-sig').replace('只有一种合法付费方案时直接支付；存在选择时弹出','符卡只有一种合法付费方案时直接支付；存在选择时弹出').replace('自动选择优先使用道具、单色资源，保留双色资源和一次性红薯。','其他牌按设置直接自动付费或手选。自动选择优先使用道具、单色资源，保留双色资源和一次性红薯。');f.write_text(s,encoding='utf-8')
f=p/'docs/游戏整体开发计划.md';s=f.read_text(encoding='utf-8-sig').replace('唯一合法方案直接支付，多方案询问自动或手选。','符卡唯一合法方案直接支付，多方案询问自动或手选；其他牌按自动开关处理。');f.write_text(s,encoding='utf-8')
f=p/'开发者日志.md';s=f.read_text(encoding='utf-8-sig').replace('自动付费默认开。唯一付款方案直接提交，多方案询问；','自动付费默认开。符卡唯一付款方案直接提交，多方案询问；其他牌按开关直接自动或手选。');f.write_text(s,encoding='utf-8')
