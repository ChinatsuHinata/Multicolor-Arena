extends "res://tests/support/ui_base.gd"
const G=preload("res://scripts/rules/gensokyo_exploration.gd")
const Series=preload("res://net/series_controller.gd")
var output="res://work/gensokyo-exploration"

func frames(count: int=8):
 for i in range(count):await process_frame

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))

func tap(at: Vector2):
 if not app.is_android:await click(at);return
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()

func setup_flow(mobile: bool):
 app.is_android=mobile;app.layout_dpi_override=240.0 if mobile else 0.0
 root.size=Vector2i(1280,720) if mobile else Vector2i(1600,900)
 app.battle_mode="standard";app.setup();await frames()
 var mode=app.screen.find_child("BattleModeSelect",true,false)
 expect(mode!=null and mode.item_count==2,"mode selector available on "+("Android" if mobile else "desktop"))
 mode.select(1);mode.item_selected.emit(1);await frames()
 expect(app.battle_mode=="exploration" and app.screen.find_child("PlayerDeckSelect",true,false).disabled and app.screen.find_child("AIDeckSelect",true,false).disabled,"fixed deck selection locks both seats")
 expect(app.match_setup_deck(0)==G.deck() and app.match_setup_deck(1)==G.deck(),"both setup previews use fixed deck")
 expect(app.texture(G.LEADER)!=null and app.texture(G.VISIT)!=null and app.texture(G.EXPLORE)!=null and app.texture(G.TRAVEL)!=null and app.preview_texture(G.CLUB)!=null,"all requested art loads")
 var experiment=app.screen.find_child("ExperimentalAI",true,false)
 if experiment!=null:expect(experiment.disabled and not experiment.button_pressed,"entertainment setup disables experiment AI")
 await shot("android-setup" if mobile else "desktop-setup")
 app.experimental_ai=true;app.experiment_model_path="res://work/gensokyo-exploration/missing-model.json"
 app.begin_battle(true);view=app.duel_view;e=view.engine;view.set_process(false);view.reveal_player.reset();e.presentation_events.clear();view.fast_mode=true;view._process(1.0);view.fast_mode=false
 expect(e.ai_profiles==["",e.PASSIVE_AI] and not view.experiment_agent.enabled,"real UI launch uses passive opponent despite saved experiment settings")
 expect(e.players[1].mulligan_done and not e.players[0].mulligan_done,"view automatically confirms only the passive opponent opening hand")
 view.reveal_player.reset();await frames()
 expect(e.players.all(func(p):return p.leader.card_id==G.LEADER and p.deck.size()==46 and p.hand.size()==4),"real UI launch deals both fixed decks")
 for p in e.players:
  for z in ["hand","palette","field","grave","exile"]:p[z]=[]
  p.potato=false;p.mulligan_done=true;p.turns=3
 e.phase="main";e.active=0;e.priority=0;e.turn=6;e.pending={};e.presentation_events.clear();view.reveal_player.reset()
 view.render();await frames();view.android_inspection_allowed=true;view.inspect_card(G.LEADER,e.players[0].leader.uid);view.android_inspection_allowed=false;await frames()
 expect(is_instance_valid(view.inspection_text) and view.inspection_text.get_parsed_text().contains("任意自机") and not view.inspection_text.get_parsed_text().contains("减少任意两点颜色值"),"leader inspection displays new self ability without old Merry and Renko discount")
 expect(not view.inspection_text.get_parsed_text().contains("搜寻") and not view.inspection_text.get_parsed_text().contains("该单位进战场时"),"leader inspection carries no original entry search")
 var self_text=view.inspection_text.get_parsed_text().split("自机能力：")
 expect(self_text.size()==2 and self_text[1].contains("梅莉的拜访") and self_text[1].contains("更容易抽到自机") and self_text[1].contains("战场上"),"leader inspection includes battlefield visit bonus inside self ability")
 await shot("android-leader-description" if mobile else "desktop-leader-description")
 view.inspect_id="";view.update_inspection()
 put(G.EXPLORE,"palette");var c=put(G.TRAVEL,"hand")
 expect(e.commit_cast(0,c.uid,{"none":true},e.payment(0,e.cast_cost(0,c)).plan).is_empty(),"UI fixture pays discovery normally")
 resolve();e.presentation_events.clear();view.reveal_player.reset();view.previous_snapshot={};view.render();await frames()
 var panel=view.android_choice_panel
 expect(is_instance_valid(panel) and panel.get_meta("region_picker",false),"discovery displays card-art gallery")
 expect(app.ui_metrics.safe.grow(1).encloses(panel.get_global_rect()),"discovery gallery stays within screen safe area")
 expect(view.region_tiles.size()==3,"three discovered card faces displayed")
 expect(view.region_tiles.values().all(func(tile):return e.cards[view.region_card(tile.get_meta("choice_atom")).card_id].kind in ["道具","结界"]),"travel bag gallery contains only item and barrier options")
 var confirm=panel.find_child("RegionConfirm",true,false)
 expect(confirm!=null and confirm.disabled,"mandatory choice cannot confirm empty selection")
 for tile in view.region_tiles.values():
  expect(view.region_card(tile.get_meta("choice_atom")).zone=="outside","discovery tiles point to outside cards")
  expect(panel.get_global_rect().encloses(tile.get_global_rect()),"discovery card fits visible gallery")
 await shot("android-discovery" if mobile else "desktop-discovery")
 var first_tile=view.region_tiles.values()[0];var offered=view.region_card(first_tile.get_meta("choice_atom")).card_id
 await tap(first_tile.get_global_rect().get_center());await frames()
 confirm=view.android_choice_panel.find_child("RegionConfirm",true,false)
 expect(not confirm.disabled,"selecting a card enables confirmation")
 await tap(confirm.get_global_rect().get_center());await frames()
 expect(e.players[0].hand.size()==1 and e.players[0].hand[0].card_id==offered,"real click or touch takes selected card into hand")
 if e.pending.get("kind","")=="reveal_review":e.confirm_revealed(1,e.pending.serial)
 view.reveal_player.reset();app.setup();await frames()
 expect(app.battle_mode=="exploration","return to setup retains entertainment mode")
 app.experimental_ai=false;app.experiment_model_path=""
 var lobby=preload("res://net/lan_lobby.gd").new();lobby.format_input=OptionButton.new();lobby.add_formats()
 expect(lobby.format_input.get_item_id(lobby.format_input.item_count-1)==Series.EXPLORATION,"network format picker includes entertainment room")
 lobby.format_input.free();lobby.free()

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 Store.Paths.root_override=ProjectSettings.globalize_path(output.path_join("fixtures/"+str(Time.get_ticks_usec())))
 DirAccess.make_dir_recursive_absolute(Store.Paths.root_override.path_join("tutorials"))
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 app=load("res://main.tscn").instantiate();app.tutorial_local_directory=Store.Paths.root_override.path_join("tutorials")
 app.settings_path=Store.Paths.root_override.path_join("settings.json");app.account_session_path=Store.Paths.root_override.path_join("account.json")
 root.add_child(app);await frames()
 app.auto_patch_update_in_editor=false
 await setup_flow(false);await setup_flow(true)
 app.queue_free();await frames()
 print("GENSOKYO EXPLORATION UI: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
