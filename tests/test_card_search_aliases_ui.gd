extends "res://tests/support/ui_base.gd"
const Aliases=preload("res://scripts/card_search_aliases.gd")

func find_search(node: Node):
 if node==null:return null
 if node is LineEdit:return node
 for child in node.get_children():
  var found=find_search(child)
  if found!=null:return found
 return null

func search_rows(term: String) -> Array:
 var search=find_search(view.modal_root)
 expect(search!=null,"card selection exposes a search input")
 if search==null:return []
 search.text=term;search.text_changed.emit(term)
 return search.get_parent().get_children().filter(func(child):return child is Button and child.visible)

func naming_checks():
 var before=JSON.stringify(e.pending)
 for pair in [["小妖梦","39"],["小猫车","character-ucs-038"],["红饼","165"],["蓝饼","167"],["绿饼","166"],["黄饼","164"],["黑饼","168"],["530","spell-fdf-085"],["165","165"],["旧地狱的宠物妖怪","character-ucs-038"]]:
  var rows=search_rows(pair[0])
  expect(rows.size()==1 and rows[0].text==e.cards[pair[1]].name,"name picker finds the precise card for "+pair[0])
 for term in ["炸弹人","夜雀","UU","小五符卡","饼","炮","密封"]:
  var query=Aliases.prepare_query(e.cards,term,Aliases.load_rules())
  var names=Aliases.matching_names(e.cards,query)
  var rows=search_rows(term)
  expect(not rows.is_empty() and rows.size()==names.size() and rows.all(func(row):return names.has(row.text)),"name picker applies the shared alias rule for "+term)
 expect(search_rows("不存在的卡牌别名").is_empty(),"unknown query hides all unrelated names")
 expect(search_rows("   ").size()==e.pending.options.size(),"blank query restores all legal names")
 expect(JSON.stringify(e.pending)==before,"searching never changes legal options or the pending effect")

func choose_name(term: String,id: String):
 var rows=search_rows(term)
 expect(rows.size()==1,"one name is selected through "+term)
 if rows.size()!=1:return
 rows[0].pressed.emit()
 expect(view.picker.ready() and view.picker.option().get("card_name","")==e.cards[id].name,"selection retains the official card name")
 view.confirm_trigger()
 if not e.stack.is_empty():resolve()

func enter_for_name(id: String):
 var source=e.make_card(id,0,"hand")
 e.enter_field(source,0);e.pump_choices();show_choices()
 return source

func show_choices():
 e.presentation_events.clear();view.reveal_player.reset();view.render()

func cast_for_name(id: String,target: Dictionary={}):
 e.debug_enabled=true;e.debug_free_payment=true
 var spell=put(id,"hand")
 var options=e.targets_for(id,0,spell.uid)
 if target.is_empty() and not options.is_empty():target=options[0]
 var error=e.commit_cast(0,spell.uid,target,[])
 expect(error.is_empty(),"cast reaches naming effect: "+id+" "+error)
 resolve();show_choices()

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/card-search-aliases-ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.draft=Store.blank("别名搜索测试");app.draft.leader="70";app.editor()
 for pair in [["小妖梦",["39"]],["小猫车",["character-ucs-038"]],["炸弹人",["78","character-fdn-042"]],["夜雀",["22","character-fdf-094"]],["红饼",["165"]],["蓝饼",["167"]],["绿饼",["166"]],["黄饼",["164"]],["黑饼",["168"]],["红饼道具",["165"]]]:
  app.query=pair[0]
  var ids=app.library_ids();ids.sort();pair[1].sort()
  expect(ids==pair[1],"editor finds "+pair[0])
 app.query="红蓝单位"
 expect(not app.library_ids().is_empty() and app.library_ids().all(func(id):return Store.CARDS[id].kind in ["单位","自机"] and "红" in Store.CARDS[id].colors and "蓝" in Store.CARDS[id].colors),"editor retains combined category and color filters")
 app.open_leader_picker()
 var dialog=app.get_node("LeaderPicker")
 var leader_search=dialog.get_node("LeaderPickerSearch")
 leader_search.text="炸弹人";leader_search.text_changed.emit(leader_search.text)
 var grid=dialog.find_child("LeaderChoices",true,false)
 expect(grid.get_child_count()==1 and grid.get_child(0).get_meta("card_id","")=="78","leader picker resolves aliases within legal leaders")
 dialog.queue_free();await process_frame
 app.load_test_decks();app.debug_mode=true;app.begin_battle(true)
 view=app.duel_view;view.set_process(false);e=view.engine
 clean(true);view.render()
 for who in [0,1]:
  for pair in [["小妖梦","39"],["小猫车","character-ucs-038"],["红饼","165"],["黑饼","168"]]:
   view.open_debug_card_picker(who,"hand")
   var search=find_search(view.modal_root)
   search.text=pair[0];search.text_changed.emit(search.text)
   var panel=view.modal_root.get_child(0)
   var rows=[]
   for child in panel.get_children():
    if child is ScrollContainer:rows=child.get_child(0).get_children()
   expect(rows.size()==1 and ("["+pair[1]+"]") in rows[0].text,"debug picker finds "+pair[0]+" for player "+str(who))
   if rows.size()==1:rows[0].pressed.emit()
   expect(e.players[who].hand.any(func(c):return c.card_id==pair[1]),"debug alias adds the selected card to the selected player")
   e.presentation_events.clear();view.reveal_player.reset()
 clean();var momiji=enter_for_name("character-fdf-101")
 expect(e.pending.get("trigger",{}).get("effect","")=="cat:momiji_name","Momiji opens the real declaration")
 naming_checks();choose_name("红饼","165")
 expect(momiji.get("locked_name","")==e.cards["165"].name,"Momiji declares the resolved mana-item name")
 clean();var red=put("165","field");var enemy_red=put("165","field",1);var blue=put("167","field")
 cast_for_name("new-loc-004")
 expect(e.pending.get("trigger",{}).get("effect","")=="n21:deer_name","deer shot opens its real name choice")
 choose_name("红饼","165")
 expect(red.zone=="grave" and enemy_red.zone=="grave" and blue.zone=="field","deer shot destroys only the named item on both sides")
 clean();red=put("165","grave");blue=put("167","grave");enter_for_name("new-spx-005")
 expect(e.pending.get("trigger",{}).get("effect","")=="n21:SPX-005","Yukari opens her real name choice")
 choose_name("红饼","165")
 expect(red.zone=="field" and blue.zone=="grave","Yukari returns the officially named item")
 clean();put("character-ucs-036","field");var target=put("53","field",1);put("39","hand",1);put("164","deck",1)
 cast_for_name("spell-fdf-032",e.ref_target(target))
 expect(e.pending.get("trigger",{}).get("effect","")=="cat:brain_name","Brain Fingerprint also opens the shared name picker")
 choose_name("小妖梦","39")
 expect(target.zone=="grave","another naming effect resolves the three-cost Youmu alias")
 clean();var small=put("39","grave");var large=put("87","grave")
 var query=Aliases.prepare_query(e.cards,"小妖梦",Aliases.load_rules())
 expect(view.choice_matches_query({"kind":"target","value":e.Pack.ref(e,small)},"",query,{}),"card-reference choices resolve aliases")
 expect(not view.choice_matches_query({"kind":"target","value":e.Pack.ref(e,large)},"小妖梦",query,{}),"exclusive aliases reject a different referenced card")
 query=Aliases.prepare_query(e.cards,"红饼",Aliases.load_rules())
 expect(view.choice_matches_query({"kind":"target","value":{"outside_id":"165"}},"",query,{}),"outside-card choices also resolve aliases")
 expect(not view.choice_matches_query({"kind":"target","value":{"outside_id":"167"}},"红饼",query,{}),"exclusive aliases do not include unrelated outside cards")
 query=Aliases.prepare_query(e.cards,"支付",Aliases.load_rules())
 expect(view.choice_matches_query({"kind":"mode","value":"支付费用"},"支付费用",query,{}),"non-card effect choices retain ordinary text search")
 print("CARD_SEARCH_ALIASES_UI: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
