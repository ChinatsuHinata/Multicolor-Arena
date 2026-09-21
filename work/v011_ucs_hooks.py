from pathlib import Path
R=Path(__file__).resolve().parents[1]
def patch(path,changes):
 p=R/path;s=p.read_text(encoding='utf-8-sig')
 for old,new in changes:
  assert old in s,(path,old);s=s.replace(old,new)
 p.write_text(s,encoding='utf-8')
patch('scripts/rules/duel_engine.gd',[
 ('func shuffle(cards_to_shuffle: Array):','func flip_coin(who: int) -> bool:\n var heads=rng.randi_range(0,1)==1\n Roster.on_coin(self,who)\n return heads\nfunc shuffle(cards_to_shuffle: Array):'),
 ('"minus_counters","freeze_until"','"minus_counters","scare","freeze_until"'),
 ('if source_uid>=0:\n   for spec','if source_uid>=0 and Roster.free_cast(self,find_card(source_uid),acting):extended=extended.filter(func(t):return int(t.get("x",0))==0)\n  if source_uid>=0:\n   for spec'),
 (' if not payment_valid(who,cast_cost(who,c,target),plan):',' if Roster.free_cast(self,c,who) and int(target.get("x",0))!=0:return "不支付颜色值使用时，X为0"\n if not payment_valid(who,cast_cost(who,c,target),plan):'),
 ('  if c.tapped: continue\n  if Roster.has','  if c.tapped: continue\n  if Roster.enabled(self,attacker,"kogasa_boost") and c.get("scare",0)>0:continue\n  if Roster.has'),
 (' note("发动 "+cards[c.card_id].name+"的异能")\n return ""',' note("发动 "+cards[c.card_id].name+"的异能")\n Roster.on_ability_announced(self,stack.back());pump_choices()\n return ""'),
 (' note(t.name+" · 触发能力",history_art(t.source))\n return entry.id',' note(t.name+" · 触发能力",history_art(t.source))\n if not target.is_empty():Roster.on_ability_announced(self,entry)\n return entry.id'),
 ('entry.target=target.duplicate(true); entry.erase("awaiting_target"); return','entry.target=target.duplicate(true); entry.erase("awaiting_target");Roster.on_ability_announced(self,entry); return'),
 (' next_stack+=1; passes=0; priority=1-who; note("发动 "+cards[c.card_id].name); judge(); pump_choices()',' Roster.on_ability_announced(self,stack.back())\n next_stack+=1; passes=0; priority=1-who; note("发动 "+cards[c.card_id].name); judge(); pump_choices()'),
 ('Roster.key(cards[id],Roster.SPELLS)','Roster.key(cards[id],Roster.SPELLS+Roster.UCS_SPELLS)'),
])
patch('scripts/rules/precon_abilities.gd',[( 'var heads=e.rng.randi_range(0,1)==1','var heads=e.flip_coin(who)')])
patch('scripts/main.gd',[( ' if id in ["token_ufo","token_halfghost"]:', ' if id=="token_halfghost" and Store.CARDS.has("token-ucs-099"):return texture("token-ucs-099")\n if id in ["token_ufo","token_halfghost"]:')])
patch('scripts/rules/excel_abilities.gd',[( 'var k=key(e.cards[c.card_id],SPELLS);var choices=', 'var k=key(e.cards[c.card_id],SPELLS+UCS_SPELLS);var choices=')])
patch('tests/test_v011_ui.gd',[( 'var m=put("164","palette");put("164","palette")','put("164","palette");put("165","palette");put("165","palette")')])
patch('tests/test_v011_rules.gd',[( 'all.size()==235,"235 validated definitions load"','all.size()==251,"251 validated definitions load"')])
patch('tests/test_v010_rules.gd',[( '.size()==8,"original pool','.size()>=8,"original pool')])
patch('tests/test_v097_database.gd',[( 'cards.size()==132','cards.size()==251'),('cards.size()!=132','cards.size()!=251')])
print('UCS hooks installed')
