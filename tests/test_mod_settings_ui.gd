extends "res://tests/support/ui_base.gd"
const Registry=preload("res://scripts/rules/mod_registry.gd")
const Settings=preload("res://scripts/mod_settings.gd")
const Session=preload("res://net/lan_session.gd")
const Series=preload("res://net/series_controller.gd")
const ImportFixture=preload("res://tests/support/mod_import_fixture.gd")
func inactive_card(id: String) -> bool:
 if not Store.CARDS.get(id,{}).get("inactive_mod",false) or Registry.shared().packs.has(id.get_slice("/",0)):return false
 return Store.RuleSet.IDS.all(func(rule):return not Store.RuleSet.allowed(id,Store.CARDS[id],rule))
func capture_mod_ui(filename: String):
 if "--render" not in OS.get_cmdline_user_args():return
 await process_frame;await RenderingServer.frame_post_draw
 var folder=ProjectSettings.globalize_path("res://work/mod-settings-ui-screenshots")
 DirAccess.make_dir_recursive_absolute(folder)
 root.get_texture().get_image().save_png(folder.path_join(filename+".png"))
func run():
 var fixture="res://work/mod-settings-ui/"+str(Time.get_ticks_usec())
 Store.Paths.root_override=ProjectSettings.globalize_path(fixture)
 DirAccess.make_dir_recursive_absolute(Store.Paths.root_override.path_join("tutorials"))
 Registry._shared=Registry.new()
 var config=[{"path":ProjectSettings.globalize_path("res://examples/testmod"),"enabled":false}]
 expect(Settings.apply_configuration(config).is_empty(),"save disabled external pack")
 expect(inactive_card("testmod/utsuho"),"disabled pack retains read-only cards without enabling play")
 app=load("res://main.tscn").instantiate();app.settings_path=fixture+"/settings.json";app.account_session_path=fixture+"/account.json";app.tutorial_local_directory=fixture+"/tutorials";root.add_child(app);await process_frame
 var original_root=Store.Paths.root_override
 for mobile in [false,true]:
  Store.Paths.root_override=original_root.path_join("import-"+str(mobile));Store.Paths.initialize()
  expect(Settings.apply_configuration([]).is_empty(),"empty import fixture "+str(mobile))
  app.is_android=mobile;app.refresh_ui_metrics();app.mod_settings();await process_frame
  var status=app.screen.find_child("ModStatus",true,false)
  expect(app.screen.find_child("ImportModFile",true,false)!=null and find_button(app.screen,"添加模组目录…")==null,"settings offers file import "+str(mobile))
  var archive=ImportFixture.package(Store.Paths.root_override.path_join("sample.zip"),ImportFixture.files(),"second.cards/")
  var picker=Settings.create_picker(app)
  expect(picker.file_mode==FileDialog.FILE_MODE_OPEN_FILE and picker.use_native_dialog and picker.filters[0].begins_with("*.zip"),"native ZIP file picker "+str(mobile))
  app.mod_settings();await process_frame
  picker.file_selected.emit(archive);await process_frame
  expect(app.screen.find_child("Mod_second_cards",true,false)!=null and Registry.configuration()[0].path==Registry.install_root().path_join("second.cards"),"file import refreshes installed local pack "+str(mobile))
  expect(inactive_card("second.cards/draw"),"import retains read-only cards without enabling scripts "+str(mobile))
  var toggle=app.screen.find_child("Mod_second_cards",true,false);toggle.button_pressed=true
  find_button(app.screen,"应用选择").pressed.emit();await process_frame
  expect(Store.CARDS.has("second.cards/draw"),"imported pack enables through settings "+str(mobile))
  status=app.screen.find_child("ModStatus",true,false);picker=Settings.create_picker(app)
  picker.file_selected.emit(archive);await process_frame
  expect(status.text.contains("相同模组") and Registry.configuration().size()==1 and Store.CARDS.has("second.cards/draw"),"duplicate rejected without losing enabled cards "+str(mobile))
  var broken=ImportFixture.change(ImportFixture.files(),"manifest.json","id","invalid.cards")
  broken=ImportFixture.change(broken,"manifest.json","api",999)
  var invalid=ImportFixture.package(Store.Paths.root_override.path_join("invalid.zip"),broken)
  picker=Settings.create_picker(app);picker.file_selected.emit(invalid);await process_frame
  expect(status.text.contains("不规范") and Registry.configuration().size()==1,"malformed pack rejected with visible reason "+str(mobile))
  var upgraded=ImportFixture.change(ImportFixture.files(),"manifest.json","version","1.1.0")
  upgraded=ImportFixture.change(upgraded,"draw.json","名称","新版双抽")
  var update_archive=ImportFixture.package(Store.Paths.root_override.path_join("update.zip"),upgraded)
  toggle.button_pressed=false
  app.textures["mod-cache-test"]=null
  picker=Settings.create_picker(app);picker.file_selected.emit(update_archive);await process_frame
  status=app.screen.find_child("ModStatus",true,false);toggle=app.screen.find_child("Mod_second_cards",true,false)
  expect(status.text.contains("已更新") and toggle.text.contains("1.1.0") and Registry.configuration()[0].enabled and Store.CARDS["second.cards/draw"].name.contains("新版双抽"),"new ZIP replaces and reloads enabled mod "+str(mobile))
  expect(not toggle.button_pressed and not app.textures.has("mod-cache-test"),"update retains pending choice and invalidates artwork cache "+str(mobile))
  app.mod_settings();await process_frame
  toggle=app.screen.find_child("Mod_second_cards",true,false)
  expect(not toggle.button_pressed,"page rebuild keeps unapplied mod choice "+str(mobile))
  await capture_mod_ui("mods-"+str(mobile))
  find_button(app.screen,"返回").pressed.emit();await process_frame
  var dialog=app.find_child("ModUnsavedChanges",false,false)
  expect(dialog!=null and app.page=="mods","back detects unapplied mod choice "+str(mobile))
  await capture_mod_ui("unsaved-"+str(mobile))
  dialog.canceled.emit();await process_frame
  expect(app.page=="mods" and Registry.configuration()[0].enabled and not toggle.button_pressed,"cancel keeps draft and current loading "+str(mobile))
  find_button(app.screen,"返回").pressed.emit();await process_frame
  dialog=app.find_child("ModUnsavedChanges",false,false);dialog.custom_action.emit("discard");await process_frame
  expect(app.page=="settings" and Registry.configuration()[0].enabled,"discard returns without changing enabled mod "+str(mobile))
  app.mod_settings();await process_frame
  toggle=app.screen.find_child("Mod_second_cards",true,false);toggle.button_pressed=false
  find_button(app.screen,"返回").pressed.emit();await process_frame
  dialog=app.find_child("ModUnsavedChanges",false,false);dialog.confirmed.emit();await process_frame
  expect(app.page=="settings" and not Registry.configuration()[0].enabled and inactive_card("second.cards/draw"),"save on back applies selection before leaving "+str(mobile))
  app.mod_settings();await process_frame
  toggle=app.screen.find_child("Mod_second_cards",true,false);toggle.button_pressed=true;toggle.button_pressed=false
  find_button(app.screen,"返回").pressed.emit();await process_frame
  expect(app.page=="settings" and app.find_child("ModUnsavedChanges",false,false)==null,"reverted choice returns without prompt "+str(mobile))
  app.mod_settings();await process_frame
  toggle=app.screen.find_child("Mod_second_cards",true,false);toggle.button_pressed=true
  DirAccess.make_dir_absolute(Registry.config_path()+".tmp")
  find_button(app.screen,"返回").pressed.emit();await process_frame
  dialog=app.find_child("ModUnsavedChanges",false,false);dialog.confirmed.emit();await process_frame
  status=app.screen.find_child("ModStatus",true,false)
  expect(app.page=="mods" and status.text.contains("无法保存") and toggle.button_pressed and not Registry.configuration()[0].enabled and inactive_card("second.cards/draw"),"save failure stays on page and preserves draft and runtime "+str(mobile))
  DirAccess.remove_absolute(Registry.config_path()+".tmp")
  find_button(app.screen,"应用选择").pressed.emit();await process_frame
  find_button(app.screen,"返回").pressed.emit();await process_frame
  expect(app.page=="settings" and app.find_child("ModUnsavedChanges",false,false)==null,"applied selection returns without prompt "+str(mobile))
  app.mod_settings();await process_frame
  status=app.screen.find_child("ModStatus",true,false)
  var previous_session=app.lan_session;var guard_session=Session.new();root.add_child(guard_session)
  app.lan_session=guard_session;guard_session.room_id="import-guard"
  var before=app.find_children("ModFilePicker","FileDialog",false,false).size()
  find_button(app.screen,"导入模组文件…").pressed.emit()
  expect(status.text.contains("退出当前房间") and app.find_children("ModFilePicker","FileDialog",false,false).size()==before,"active room blocks import "+str(mobile))
  app.screen.find_child("DeleteMod_second_cards",true,false).pressed.emit();await process_frame
  expect(status.text.contains("退出当前房间") and app.find_children("*","ConfirmationDialog",false,false).is_empty(),"active room blocks deletion "+str(mobile))
  toggle=app.screen.find_child("Mod_second_cards",true,false);toggle.button_pressed=false
  find_button(app.screen,"返回").pressed.emit();await process_frame
  dialog=app.find_child("ModUnsavedChanges",false,false);dialog.confirmed.emit();await process_frame
  expect(app.page=="mods" and Registry.configuration()[0].enabled and status.text.contains("退出当前房间"),"room guard also protects save on back "+str(mobile))
  toggle.button_pressed=true
  app.lan_session=previous_session;guard_session.room_id="";guard_session.queue_free()
  app.screen.find_child("DeleteMod_second_cards",true,false).pressed.emit();await process_frame
  dialog=app.find_children("*","ConfirmationDialog",false,false)[0];dialog.canceled.emit();await process_frame
  expect(Registry.configuration().size()==1 and Store.CARDS.has("second.cards/draw"),"cancel deletion keeps installed mod "+str(mobile))
  app.screen.find_child("DeleteMod_second_cards",true,false).pressed.emit();await process_frame
  dialog=app.find_children("*","ConfirmationDialog",false,false)[0];dialog.confirmed.emit();await process_frame
  expect(Registry.configuration().is_empty() and not Store.CARDS.has("second.cards/draw") and not DirAccess.dir_exists_absolute(Registry.install_root().path_join("second.cards")) and app.screen.find_child("Mod_second_cards",true,false)==null,"confirmed deletion removes files, selection and loaded mod "+str(mobile))
  find_button(app.screen,"返回").pressed.emit();await process_frame
  expect(app.page=="settings" and app.find_child("ModUnsavedChanges",false,false)==null,"completed deletion has no unsaved prompt "+str(mobile))
 Store.Paths.root_override=original_root
 expect(Settings.apply_configuration(config).is_empty(),"restore external testmod fixture")
 for mobile in [false,true]:
  app.is_android=mobile;app.refresh_ui_metrics();app.settings();await process_frame
  expect(app.screen.find_child("ModSettings",true,false)!=null,"settings exposes mod management "+str(mobile))
  app.mod_settings();await process_frame
  var toggle=app.screen.find_child("Mod_testmod",true,false)
  expect(toggle!=null,"external pack toggle rendered "+str(mobile))
  toggle.button_pressed=true;find_button(app.screen,"应用选择").pressed.emit();await process_frame
  expect(Store.CARDS.has("testmod/utsuho") and Registry.configuration()[0].enabled,"apply loads mod cards immediately "+str(mobile))
  toggle.button_pressed=false;find_button(app.screen,"应用选择").pressed.emit();await process_frame
  expect(inactive_card("testmod/utsuho"),"disable retains read-only cards without enabling play "+str(mobile))
 var enabled=config.duplicate(true);enabled[0].enabled=true
 expect(Settings.apply_configuration(enabled).is_empty(),"enable testmod for room")
 var old=Store.CARDS;var broken=enabled.duplicate(true);broken[0].path+="/missing"
 expect(not Settings.apply_configuration(broken).is_empty() and Store.CARDS==old and Registry.configuration()==enabled,"invalid pack leaves previous registry and configuration intact")
 Registry._shared=null
 expect(Registry.shared().packs.has("testmod"),"startup discovers selected filesystem pack")
 var session=Session.new();root.add_child(session);session.initialize(fixture+"/lan");session.set_process(false)
 for mobile in [false,true]:
  app.is_android=mobile;app.refresh_ui_metrics();app.clear_page("mod_room_test")
  var lobby=preload("res://net/lan_lobby.gd").new();app.screen.add_child(lobby);lobby.build(app,session);lobby.mode_selected=true
  for cloud in [false,true]:
   lobby.cloud_selected=cloud;lobby.refresh(true);await process_frame
   var suffix=" mobile="+str(mobile)+" cloud="+str(cloud)
   expect(lobby.format_input.item_count==4,"formats contain only BO3, BO1, BO1 sideboard and entertainment"+suffix)
   var index=Store.RuleSet.IDS.find(Store.RuleSet.MOD)
   expect(lobby.rule_input.get_item_text(index)==Store.RuleSet.label_for(Store.RuleSet.MOD),"room rules offer mod rules"+suffix)
   lobby.rule_input.select(index)
   for format_value in [Series.BO1,Series.BO1_SIDEBOARD,Series.BO3]:
    lobby.format_input.select(lobby.format_input.get_item_index(format_value));lobby.refresh_room_options()
    expect(lobby.rule_input.visible and Store.RuleSet.IDS[lobby.rule_input.selected]==Store.RuleSet.MOD and lobby.selected_room_format()==format_value,"mod rule stays independent of format"+suffix)
   var room=Series.new();room.setup(Series.BO1_SIDEBOARD,false,Store.RuleSet.MOD);room.state.status="sideboarding"
   var hint=lobby.preparation_hint(room.state)
   expect(hint.contains("最多换入 3 张") and hint.contains("testmod"),"mod manifest does not hide sideboard instruction"+suffix)
  app.draft=Store.blank("模组规则界面");app.draft.leader="70";app.editor();await process_frame
  var choice=app.screen.find_child("DeckRuleSet",true,false)
  var index=Store.RuleSet.IDS.find(Store.RuleSet.MOD);choice.select(index);choice.item_selected.emit(index);await process_frame
  expect(app.draft.rule_set==Store.RuleSet.MOD and Store.add_card(app.draft,"testmod/control","main",app.draft.rule_set).is_empty(),"editor selects mod rules and adds mod cards "+str(mobile))
  for card_id in ["testmod/sutra","testmod/resonance","testmod/furnace","testmod/ship"]:
   app.selected=card_id
   if mobile:app.editor_ui.show_details(card_id)
   else:app.update_preview()
   await process_frame
   var expected=Store.CARDS[card_id].name
   expect("「" in expected and "【" not in expected and "の" not in expected,"editor uses Japanese card name punctuation "+card_id+" "+str(mobile))
   expect(app.preview.find_children("*","Label",true,false).any(func(node):return node.text==expected),"editor preview displays the normalized name "+card_id+" "+str(mobile))
   if mobile:
    expect(app.editor_ui.thumbnail(card_id)!=null,"Android gallery loads raw mod card art "+card_id)
    app.editor_ui.close_details()
 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 for mobile in [false,true]:
  app.is_android=mobile;app.refresh_ui_metrics();clean(true)
  var rod=put("testmod/fuel","exile");var other=put("testmod/control","exile");var spare=put("testmod/fuel","exile")
  var furnace=e.make_card("testmod/furnace",0,"hand");e.enter_field(furnace,0);e.pump_choices()
  e.pass_priority(e.priority);e.pass_priority(e.priority);view.render();await process_frame
  expect(e.pending.get("trigger",{}).get("mod_resume",false),"furnace recovery uses common UI picker "+str(mobile))
  expect(view.picker.available_refs().size()==3,"picker displays all eligible exiled rod copies "+str(mobile))
  for card in [rod,other]:
   expect(view.picker.select_target({"uid":card.uid,"epoch":card.epoch,"zone":card.zone}),"pick a rod to shuffle back "+str(mobile));view.render()
  expect(view.picker.ready(),"up-to-two rod selection enables confirmation "+str(mobile))
  view.confirm_trigger();await process_frame
  expect(rod.zone=="deck" and other.zone=="deck" and spare.zone=="exile" and e.mod_resolution.is_empty(),"UI shuffles only the two chosen rods "+str(mobile))
 session.leave(false);session.queue_free();app.queue_free();await process_frame
 print("MOD_SETTINGS_UI: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
