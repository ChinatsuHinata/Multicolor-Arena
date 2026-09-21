from pathlib import Path
r=Path(r'C:\Users\tzx20\Documents\test');p=r/'scripts/main.gd';s=p.read_text(encoding='utf-8-sig')
s=s.replace('var battle = {}','var battle = {}\nvar duel_view')
s=s.replace('func texture(id: String) -> Texture2D:\n','func texture(id: String) -> Texture2D:\n if id=="potato": return load("res://assets/potato.svg")\n')
s=s.replace(' var resource = load("res://recourse/demo素材/" + Store.CARDS[id].file) as Texture2D',' var resource = load(Store.CARDS[id].image) as Texture2D')
a=s.index('func begin_battle(first: bool):');b=s.index('\nfunc draw_card(',a)
s=s[:a]+'''func begin_battle(first: bool):
 clear_page("battle")
 duel_view=preload("res://scripts/duel_view.gd").new()
 duel_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 screen.add_child(duel_view)
 duel_view.begin(self,decks[player_choice],decks[ai_choice],0 if first else 1)

func load_test_decks():
 for id in ["demo_reimu","demo_marisa"]:
  for d in decks.duplicate():
   if d.id==id: decks.erase(d)
 var reimu=Store.blank("测试 · 灵梦")
 reimu.id="demo_reimu"; reimu.leader="70"
 var marisa=Store.blank("测试 · 魔理沙")
 marisa.id="demo_marisa"; marisa.leader="68"
 for i in range(10):
  reimu.main.append_array(["165","164","70","100","170"])
  marisa.main.append_array(["167","164","68","99","170"])
 player_choice=decks.size(); ai_choice=decks.size()+1
 decks.append(reimu); decks.append(marisa)
 skip_check=true; ai_one=true
 setup()
'''+s[b:]
s=s.replace(' button(screen,"编辑牌组",Rect2(1080,730,250,50),editor)',' button(screen,"编辑牌组",Rect2(1080,730,250,50),editor)\n button(screen,"载入测试卡组",Rect2(80,730,270,50),load_test_decks)')
a=s.index('func card_description(id: String)');b=s.index('\nfunc make_drop_zone',a)
s=s[:a]+'''func card_description(id: String) -> String:
 return Store.CARDS[id].rules_text
'''+s[b:]
p.write_text(s,encoding='utf-8')
p=r/'assets/potato.svg';s=p.read_text(encoding='utf-8-sig').replace('font-size=" forty"','font-size="40"');p.write_text(s,encoding='utf-8')
