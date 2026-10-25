extends "res://tests/support/ui_base.gd"
var snapshots="res://work/tournament-layout-tests"

class OfflinePage extends "res://scripts/tournament_page.gd":
 func fetch_list(_index: int=0):
  can_create=true;show_list()

func frames(count: int=12):
 for i in range(count):await process_frame

func expect(ok: bool,caption: String):
 checks+=1
 if not ok:failures.append(caption);push_error(caption)

func shot(caption: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(snapshots.path_join(caption+".png"))

func check_column(column: Container,caption: String):
 var previous: Control=null
 for child in column.get_children():
  if not child is Control or not child.visible:continue
  expect(child.position.x>=-1 and child.get_rect().end.x<=column.size.x+1,caption+" contains "+child.get_class())
  if previous!=null:expect(child.position.y>=previous.get_rect().end.y,caption+" rows do not overlap")
  previous=child

func check_form(ui,caption: String,scroll_name: String="TournamentCreateScroll"):
 var scroll=ui.find_child(scroll_name,true,false)
 var column=scroll.get_child(0)
 expect(app.screen.get_global_rect().grow(1).encloses(scroll.get_global_rect()),caption+" scroll fits the screen")
 expect(column.size.x>=scroll.size.x-scroll.get_v_scroll_bar().size.x-1,caption+" form uses the viewport width")
 expect(scroll.get_h_scroll_bar().max_value<=scroll.size.x+1,caption+" needs no horizontal scrolling")
 check_column(column,caption+" main column")
 for field in ui.stage_form.fields:
  check_column(field.title.get_parent(),caption+" stage column")
  var inputs=[field.rounds,field.count,field.threshold,field.losses]
  inputs.append_array(field.points.values())
  for input in inputs:
   var row=input.get_parent()
   var label=row.get_child(0)
   expect(label.size.x>app.ui_metrics.small*8,caption+" numeric caption has readable width")
   expect(label.get_line_count()<=3,caption+" caption wraps normally")
   expect(label.get_rect().end.x<=input.position.x,caption+" caption and input do not overlap")
   expect(is_equal_approx(input.size.y,input.get_combined_minimum_size().y),caption+" numeric input does not stretch with its caption")
   expect(input.size.y>=app.ui_metrics.hit,caption+" numeric input meets the control height")
   expect(row.get_rect().end.x<=column.size.x+1,caption+" numeric row fits the form")
 var target=ui.stage_form.fields[0].rounds
 target.get_line_edit().release_focus();target.get_line_edit().grab_focus();await frames()
 expect(scroll.get_global_rect().grow(1).encloses(target.get_global_rect()),caption+" focused numeric input scrolls fully into view")
 scroll.scroll_vertical=int(target.get_parent().global_position.y-column.global_position.y)
 await frames();await shot(caption)

func create_form(mobile: bool,pixels: Vector2i,dpi: float=0,safe: Rect2=Rect2()):
 root.size=pixels;app.is_android=mobile;app.layout_dpi_override=dpi;app.layout_safe_override=safe
 await frames();app.clear_page("tournaments")
 var ui=OfflinePage.new();ui.app=app;app.tournament_ui=ui;app.screen.add_child(ui)
 await frames();ui.show_create();await frames()
 expect(not ui.stage_form.visible,"basic creation hides the optional stage form")
 ui.title_input.text="布局回归比赛";ui.title_input.text_changed.emit(ui.title_input.text)
 ui.description_input.text="请在比赛开始前完成签到。"
 expect(not ui.submit_button.disabled,"valid title enables creation")
 expect(ui.settings_payload().format=="swiss","basic creation keeps the default schedule")
 ui.custom_stages.button_pressed=true;await frames()
 expect(ui.stage_form.visible,"custom creation shows stage controls")
 check_advancement_modes(ui)
 await frames()
 return ui

func select_metadata(control: OptionButton,value: String):
 for index in range(control.item_count):
  if control.get_item_metadata(index)==value:
   control.select(index);control.item_selected.emit(index);return
 expect(false,"advancement option exists: "+value)

func check_advancement_modes(ui):
 for mode in ["points","rank","rank_tie","all"]:
  var field=ui.stage_form.fields[0]
  select_metadata(field.advance,mode)
  expect(field.threshold.editable==(mode=="points"),"only points advancement enables the score threshold")
  expect(field.count.editable==(mode in ["rank","rank_tie"]),"only rank advancement enables the player count")
  field.early.button_pressed=false
  expect(not field.losses.editable,"early loss limit is inactive when early exits are off")
  if mode=="points":field.threshold.value=7
  if mode in ["rank","rank_tie"]:field.count.value=4
  var saved=ui.settings_payload().stages
  expect(saved[0].advance.mode==mode and not saved[0].advance.early,"saving the selected advancement mode does not enable early exits")
  if mode=="points":expect(saved[0].advance.points==7,"points threshold is saved independently of early exits")
  ui.stage_form.rebuild()
  field=ui.stage_form.fields[0]
  expect(field.advance.get_selected_metadata()==mode,"stage rebuild preserves the chosen advancement rule")
  field.early.button_pressed=true
  expect(field.losses.editable,"early loss limit becomes editable when explicitly enabled")
  expect(ui.settings_payload().stages[0].advance.mode==mode,"early exits never switch advancement to all survivors")
  field.early.button_pressed=false
 var field=ui.stage_form.fields[0]
 select_metadata(field.kind,"single_elimination")
 expect(field.early.disabled and not field.losses.editable,"knockout stages disable the extra early-exit rules")
 select_metadata(field.kind,"swiss")
 ui.stage_form.capture()

func check_rebuild_and_settings(ui,caption: String):
 var field=ui.stage_form.fields[0]
 field.title.text="自定义瑞士轮";field.rounds.value=4;field.points.win.value=5
 field.scores.text="2:0=5,2:1=4"
 find_button(ui.stage_form,"＋ 添加下一阶段").pressed.emit();await frames()
 expect(ui.stage_form.fields.size()==2,"adding a stage rebuilds its controls")
 var payload=ui.settings_payload()
 expect(payload.stages.size()==2 and payload.stages[0].rounds==4 and payload.stages[0].points.win==5 and payload.stages[0].points.scores["2:0"]==5,"stage rebuild preserves edited settings")
 await check_form(ui,caption+"-two-stages")
 find_button(ui.stage_form.fields[1].title.get_parent(),"删除阶段").pressed.emit();await frames()
 payload=ui.settings_payload()
 expect(payload.stages.size()==1 and payload.stages[0].name=="自定义瑞士轮","removing a stage preserves the remaining form")
 ui.current={"owned":true,"phase":"registration","round_number":0,"format":"swiss_top4","game_format":3,"start_at":int(payload.start_at),"stages":payload.stages}
 ui.show_settings();await frames()
 expect(ui.custom_stages.button_pressed and ui.stage_form.visible,"management opens the saved custom stages")
 await check_form(ui,caption+"-settings","TournamentSettingsScroll")
 expect(ui.settings_payload().stages==payload.stages,"layout changes preserve the settings payload")
 var saved=payload.stages
 ui.stage_form.begin(app,[saved[0],saved[0]],1)
 expect(ui.stage_form.fields[0].advance.disabled and not ui.stage_form.fields[0].count.editable and not ui.stage_form.fields[0].threshold.editable and ui.stage_form.fields[0].early.disabled,"completed stage advancement stays locked")
 select_metadata(ui.stage_form.fields[1].advance,"points")
 expect(ui.stage_form.fields[1].threshold.editable,"current stage can repair its points threshold")
 ui.stage_form.begin(app,saved)

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(snapshots))
 var folder=snapshots.path_join(str(Time.get_ticks_usec()))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 Store.Paths.root_override=ProjectSettings.globalize_path(folder)
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1600,900)
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate()
 app.settings_path=folder.path_join("settings.json");app.account_session_path=folder.path_join("account.json")
 app.tutorial_local_directory=folder.path_join("tutorials");app.tournament_server_url="ws://127.0.0.1:1"
 root.add_child(app);await frames(30)
 var ui=await create_form(false,Vector2i(1600,900))
 await check_form(ui,"desktop-create")
 await check_rebuild_and_settings(ui,"desktop")
 ui=await create_form(false,Vector2i(1280,720))
 await check_form(ui,"desktop-small-create")
 ui=await create_form(true,Vector2i(1280,720),360,Rect2(40,12,1200,684))
 await check_form(ui,"android-create")
 var same=ui.stage_form;var field=ui.stage_form.fields[0]
 field.title.text="安全区变化后保留";field.rounds.value=7
 app.layout_dpi_override=420;app.layout_safe_override=Rect2(60,12,1160,680)
 app.refresh_responsive_layout();await frames()
 expect(ui.stage_form==same and field.rounds.value==7 and field.title.text=="安全区变化后保留","DPI and safe-area resize preserve stage inputs")
 await check_form(ui,"android-dense-create")
 await check_rebuild_and_settings(ui,"android")
 ui=await create_form(true,Vector2i(1920,848),420,Rect2(80,20,1760,808))
 await check_form(ui,"android-wide-create")
 app.queue_free();await frames()
 print("TOURNAMENT LAYOUT: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
