extends "res://tests/support/ui_base.gd"
const Rules=preload("res://scripts/deck_rule_set.gd")
const ROSE="spell-ucs-011"

func frames(count: int=4):
 for i in range(count):await process_frame

func select_rule(rule: String):
 var choice=app.screen.find_child("DeckRuleSet",true,false) as OptionButton
 var index=Rules.IDS.find(rule)
 choice.select(index);choice.item_selected.emit(index)
 await frames()

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/deck-rule-sets-ui/"+str(Time.get_ticks_usec()))
 root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 for mobile in [false,true]:
  app=load("res://main.tscn").instantiate();app.is_android=mobile
  app.settings_path=Store.Paths.root_override+"/settings.json"
  app.account_session_path=Store.Paths.root_override+"/account.json"
  app.tutorial_local_directory=Store.Paths.root_override+"/tutorials"
  root.add_child(app);await frames()
  app.draft=Store.blank("独立规则集");app.draft.leader="70"
  app.draft.main=[ROSE,ROSE];app.draft.side=[ROSE,ROSE]
  app.query="Subterranean Rose"
  app.editor();await frames()
  var prefix="安卓" if mobile else "PC"
  var choice=app.screen.find_child("DeckRuleSet",true,false) as OptionButton
  expect(choice!=null and choice.item_count==Rules.IDS.size(),prefix+"组卡器提供全部规则集")
  expect(choice.get_item_text(Rules.IDS.find(Rules.RANKED)).contains("段位匹配"),prefix+"组卡器显示独立的段位匹配选项")
  expect(app.draft.rule_set==Rules.OFFICIAL and app.draft.main.size()+app.draft.side.size()==4,prefix+"官限打开后保留四张乐章")
  await select_rule(Rules.RANKED)
  expect(app.draft.rule_set==Rules.RANKED and app.draft.main==[ROSE,ROSE] and app.draft.side.is_empty(),prefix+"切换段位匹配自动按主副合计限二整理")
  app.selected=ROSE;app.add_to("side");await frames()
  expect(app.draft.side.is_empty(),prefix+"段位匹配无法从组卡器加入第三张乐章")
  await select_rule(Rules.OFFICIAL)
  app.selected=ROSE;app.add_to("side");app.add_to("side");await frames()
  expect(app.draft.main.size()+app.draft.side.size()==4,prefix+"切回官限可重新加入四张乐章")
  await select_rule(Rules.RANKED)
  var decoded=Store.decode(Store.encode(app.draft),false)
  expect(decoded.has("deck") and decoded.deck.rule_set==Rules.RANKED,prefix+"编辑器结果导出导入保留段位匹配规则")
  app.dirty=false;app.queue_free();await frames()
 print("DECK_RULE_SETS_UI: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
