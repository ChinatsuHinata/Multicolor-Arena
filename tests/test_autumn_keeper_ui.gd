extends "res://tests/support/ui_base.gd"

const AUTUMN="new-loc-006"

func frames(count: int=8):
 for i in range(count):await process_frame

func text_in(node: Node) -> String:
 var result=node.text if node is Label else ""
 for child in node.get_children():result+="\n"+text_in(child)
 return result

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/autumn-keeper-ui/"+str(Time.get_ticks_usec()))
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1600,900)
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 for mobile in [false,true]:
  app=load("res://main.tscn").instantiate();app.is_android=mobile
  app.settings_path=Store.Paths.root_override+"/settings.json";app.tutorial_local_directory=Store.Paths.root_override+"/tutorials"
  root.add_child(app);await frames()
  var prefix="安卓" if mobile else "PC"
  app.draft=Store.blank("幻想ノ秋司 · 官限");app.draft.leader="74"
  app.editor();app.query="幻想ノ秋司";app.update_library();await frames()
  expect(app.library_ids()==[AUTUMN] and app.library_rows.has(AUTUMN),prefix+"官限组卡器按牌名找到秋司")
  app.selected=AUTUMN;app.update_preview()
  if mobile:app.editor_ui.show_details(AUTUMN)
  await frames()
  var art=app.preview.find_child("CardDetailsArt",true,false) if mobile else app.preview.get_child(0).get_child(0)
  expect(art is TextureRect and art.texture!=null and art.texture==app.preview_texture(AUTUMN),prefix+"详情使用导入的原始卡图")
  expect(text_in(app.preview).contains("没有人类牌才能使用") and text_in(app.preview).contains("颜色值不大于4") and text_in(app.preview).contains("移回拥有者手上"),prefix+"详情显示完整条件及回手效果")
  if "--render" in OS.get_cmdline_user_args():await capture("autumn-keeper-"+("android" if mobile else "pc"))
  if mobile:app.editor_ui.close_details()
  app.add_to("main");await frames()
  app.add_to("side");await frames()
  expect(app.draft.main==[AUTUMN] and app.draft.side==[AUTUMN],prefix+"可从官限编辑器加入主卡组和备牌")
  expect(Store.validate(app.draft,false,Store.RuleSet.OFFICIAL).is_empty(),prefix+"编辑器结果通过官限验证")
  app.queue_free();await frames()
 print("AUTUMN_KEEPER_UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
