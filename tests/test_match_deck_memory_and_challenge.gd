extends "res://tests/support/ui_base.gd"
const Memory=preload("res://scripts/match_deck_memory.gd")
const Challenge=preload("res://scripts/rules/remilia_challenge.gd")
const Policy=preload("res://addons/share_export/release_policy.gd")
var output="res://work/match-deck-memory-tests"

func frames(count: int=5):
 for i in range(count):await process_frame

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 Store.Paths.root_override=ProjectSettings.globalize_path(output.path_join("fixtures-"+str(Time.get_ticks_usec())))
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 app=load("res://main.tscn").instantiate()
 app.settings_path=output.path_join("settings.json");app.account_session_path=output.path_join("session.bin")
 app.tutorial_local_directory=output.path_join("tutorials");root.add_child(app);await frames()
 var valid=Challenge.deck();valid.id="memory_fixture";valid.name="匹配记忆卡组"
 expect(Store.save_file(valid).is_empty(),"save match fixture")
 app.reload_decks();app.account_name="MemoryPlayer"
 expect(Memory.remember("MemoryPlayer",valid.id).is_empty(),"selected deck is persisted immediately")
 expect(Memory.selected("memoryplayer")==valid.id,"a new memory reader restores the account selection")
 expect(Memory.selected("otherplayer").is_empty() and Memory.selected("").is_empty(),"account selections are isolated")
 var lobby=preload("res://net/lan_lobby.gd").new();lobby.app=app;app.ensure_lan_session();lobby.session=app.lan_session
 lobby.restore_match_deck()
 expect(lobby.match_deck_index>=0 and app.decks[lobby.match_deck_index].id==valid.id,"match lobby restores persisted valid deck")
 var saved=app.decks.duplicate(true);app.decks=[]
 lobby.restore_match_deck();expect(lobby.match_deck_index==-1,"deleted decks require a new selection")
 app.decks=saved
 var index=app.remembered_match_deck_index("official")
 app.decks[index].main=[];lobby.restore_match_deck()
 expect(lobby.match_deck_index==-1,"an edited invalid deck is not silently queued")
 app.decks=saved;app.reload_decks();lobby.free()
 var original=Challenge.deck();var changed=Challenge.deck();changed.main.clear();changed.name="本地修改"
 expect(Challenge.deck()==original,"each embedded challenge deck is an independent copy")
 expect(Store.validate(original,true,"official").is_empty(),"embedded Remilia is a legal fifty-card deck")
 expect(preload("res://scripts/rules/remilia_aggro_ai.gd").profile(original)=="remilia_aggro","challenge retains Remilia AI behavior")
 var portable=original.duplicate(true);portable.id=Policy.REMILIA_ID;portable.main=[]
 expect(Policy.select_decks([],[]).decks[0].main==original.main and Policy.select_decks([],[portable]).decks[0].main==original.main,"exports use embedded data even when local AI deck is removed or edited")
 for android in [false,true]:
  root.size=Vector2i(1280,720) if android else Vector2i(1600,900)
  app.is_android=android;app.layout_dpi_override=360 if android else 0
  app.ai_opponent="remilia";app.setup();await frames()
  expect(app.screen.find_child("AIDeckSelect",true,false).disabled,"challenge uses a locked embedded opponent on both platforms")
  expect(app.match_setup_deck(1)==original,"challenge ignores the local opponent selection")
  var selector=app.screen.find_child("AIOpponentSelect",true,false)
  selector.select(1);selector.item_selected.emit(1);await frames()
  expect(not app.screen.find_child("AIDeckSelect",true,false).disabled and not app.remilia_challenge(),"other-deck mode enables choosing the bot deck")
  if DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(output.path_join("android.png" if android else "desktop.png"))
 app.decks=[];app.ai_opponent="remilia"
 expect(app.match_setup_deck(1)==original,"challenge remains available without any local deck files")
 app.queue_free();await frames();Store.Paths.root_override=""
 print("MATCH DECK MEMORY AND CHALLENGE: ",checks," checks, ",failures.size()," failures")
 quit(1 if failures.size() else 0)
