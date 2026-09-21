from pathlib import Path
R=Path.cwd()
def edit(p,f):
 p=R/p;s=p.read_text(encoding='utf-8');p.write_text(f(s),encoding='utf-8')
edit('scripts/rules/catalogue_units.gd',lambda s:s.replace('e.Roster.plus(e,u,1,who);u.madness=int(u.get("madness",0))+1','e.Roster.Batch.counter(e,u,"madness",1,who)'))
edit('scripts/rules/catalogue_state.gd',lambda s:s.replace('var C=e.Cat;var who=c.owner;var n=0','var C=e.Cat;var who=c.owner;var n=int(c.get("madness",0))'))
edit('scripts/rules/duel_engine.gd',lambda s:s.replace('and "人类" not in cards[c.card_id].race: continue','and not Cat.race(self,c,"人类"): continue'))
edit('scripts/rules/catalogue_abilities.gd',lambda s:s.replace('queued.get("effect")==t.effect:\n    if t.effect','queued.get("effect")==t.effect and (t.effect!="spell-fdf-123" or queued.data.get("milled_owner",-1)==t.data.get("milled_owner",-1)):\n    if t.effect'))
# Captions for event channels that share a card's full text.
caption={
'cat:element_reveal':'牌库顶展示：移除该牌，并选择是否使用。','cat:flower_cast':'进入颜色盘：可以不支付颜色值使用本牌。','cat:god_damage':'神子造成伤害：对至多一个目标玩家造成等量伤害。','cat:hypnosis':'每位玩家弃一张牌，然后对手失去生命。','cat:imp_growth':'攻击：放置两个+1/+1与+1指示物。','cat:lie_damage':'硬币反面：对至多一个目标造成1点伤害。','cat:murder_dolls':'放置计时指示物：对至多一个目标单位造成等量伤害。','cat:night_timer':'对手单位死去：放置一个计时指示物。','cat:nuclear_return':'自机单位进场：可以支付1红1黑将本牌从墓地移回手上。','cat:rank_death':'该单位死去：失去3点生命。','cat:rank_return':'自机单位攻击：将本牌从墓地移回手上。','cat:sacrifice_recover':'牺牲单位：可支付1黄1黑抓牌并将本牌横置放入颜色盘。','cat:tengu_watch':'对手本回合攻击过你：可以检索天狗放进战场。','cat:top_free_damage':'从牌库顶进场：对目标其他单位造成等同于攻击力的伤害。','cat:unconscious_return':'硬币反面：将本牌从墓地移回手上。','cat:utsuho_return':'死去：在下个准备阶段将该牌移回战场。','cat:delayed':'结算延迟触发效果。'}
import json
p=R/'scripts/rules/catalogue_abilities.gd';s=p.read_text(encoding='utf-8').replace('const Spells=', 'const CAPTIONS='+json.dumps(caption,ensure_ascii=False)+'\nconst Spells=',1);p.write_text(s,encoding='utf-8')
edit('scripts/rules/excel_abilities.gd',lambda s:s.replace('static func text(info: Dictionary,k: String) -> String:\n','static func text(info: Dictionary,k: String) -> String:\n if Cat.CAPTIONS.has(k):return Cat.CAPTIONS[k]\n'))
p=R/'tests/test_v013_edges.gd';s=p.read_text(encoding='utf-8');pos=s.index(' print("V013_EDGES:')
s=s[:pos]+''' fresh();a=put("spell-fdn-032");a.timer=3;b=put("50");var base=e.stat(b,"power");mana();act(a,a.card_id,e.ref_target(b))
 expect(e.Cat.counter_total(e,[b])==1 and b.get("madness",0)==1 and e.stat(b,"power")==base+1,"madness is one named stat counter, not two counters")
 e.Cat.remove_counters(e,e.Cat.counter_refs(e,[b]));expect(e.stat(b,"power")==base and not b.get("madness",0)>0,"removing madness counter removes stat bonus and attack obligation")
'''+s[pos:];p.write_text(s,encoding='utf-8')
