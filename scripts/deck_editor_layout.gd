extends RefCounted
## Container-owned editor layout; the host retains all deck operations/rules.
var app
var metrics
var columns: HBoxContainer
var details: PanelContainer
var center: VBoxContainer
var catalogue: PanelContainer
var grid: GridContainer
var side_grid: Container
var main_row: HBoxContainer
var preview_home: VBoxContainer
var details_overlay: Control
var detail_button: Button
var side_header: Label
var deck_columns=10
var tile_size=Vector2(80,112)
var leader_width=116.0
var side_stride=90.0
var deck_gap=4.0
var last_canvas_size=Vector2(-1,-1)
var sideboarding=false

func expand(control: Control,vertical: bool=false):
 control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 if vertical:control.size_flags_vertical=Control.SIZE_EXPAND_FILL
 return control

func column(parent: Node) -> VBoxContainer:
 var result=VBoxContainer.new();parent.add_child(result);expand(result,true)
 return result

func text(parent: Node,value: String,font: int=0) -> Label:
 var result=Label.new();result.text=value
 result.add_theme_font_size_override("font_size",metrics.body if font==0 else font)
 result.add_theme_color_override("font_color",app.WHITE)
 result.mouse_filter=Control.MOUSE_FILTER_IGNORE
 parent.add_child(result)
 return result

func action(parent: Node,caption: String,callback: Callable,accent: bool=false) -> Button:
 var result=app.button(parent,caption,Rect2(),callback,accent)
 metrics.button(result)
 return result

func panel(parent: Node) -> PanelContainer:
 var result=PanelContainer.new();parent.add_child(result)
 result.add_theme_stylebox_override("panel",metrics.panel_style())
 return result

func menu_button(parent: Node,caption: String,entries: Array) -> Button:
 var result=action(parent,caption,func():app.open_menu_popup("组卡菜单",entries,2))
 return result

func build(host,swapping: bool):
 app=host;metrics=app.ui_metrics;sideboarding=swapping
 var root=column(app.screen);root.name="ResponsiveDeckEditor"
 root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var toolbar=HBoxContainer.new();root.add_child(toolbar)
 var heading=text(toolbar,"换备牌" if swapping else "卡组编辑器",metrics.title)
 heading.add_theme_color_override("font_color",app.GOLD);expand(heading)
 detail_button=action(toolbar,"卡牌详情",toggle_details)
 action(toolbar,"排序",app.sort_current_deck)
 if not swapping:
  var entries=[["卡组截图",app.capture_current_deck],["打开截图文件夹",app.open_screenshot_folder],["组卡教程",app.show_deck_tutorial]]
  if metrics.touch:menu_button(toolbar,"工具",entries)
  else:
   for entry in entries:
    var b=action(toolbar,entry[0],entry[1])
    if entry[0]=="卡组截图":b.name="DeckCaptureButton"
    if entry[0]=="打开截图文件夹":b.name="OpenScreenshotFolderButton"
 action(toolbar,"返回",app.online if swapping else func():app.guard(app.menu))
 columns=HBoxContainer.new();root.add_child(columns);expand(columns,true)
 details=panel(columns);details.name="CardDetailsPanel"
 preview_home=column(details)
 app.preview=VBoxContainer.new();app.preview.name="CardPreview";preview_home.add_child(app.preview);expand(app.preview,true)
 var center_panel=panel(columns);center_panel.name="DeckPanel";expand(center_panel,true)
 center=column(center_panel)
 var deck_title=HBoxContainer.new();center.add_child(deck_title)
 app.name_label=text(deck_title,"",metrics.body+3);app.name_label.clip_text=true;expand(app.name_label)
 app.name_label.add_theme_color_override("font_color",app.GOLD)
 if not swapping:
  app.name_label.mouse_filter=Control.MOUSE_FILTER_STOP
  app.name_label.gui_input.connect(app.on_deck_title_input)
 var rules=OptionButton.new();rules.name="DeckRuleSet";deck_title.add_child(rules);metrics.button(rules)
 rules.custom_minimum_size.x=metrics.body*8
 for caption in app.RuleSet.LABELS:rules.add_item("规则："+caption)
 rules.select(maxi(0,app.RuleSet.IDS.find(str(app.draft.get("rule_set",app.RuleSet.OFFICIAL)))))
 rules.disabled=swapping
 rules.item_selected.connect(func(index):app.change_deck_rule_set(app.RuleSet.IDS[index]))
 if not swapping:
  var cloud_actions=HBoxContainer.new();cloud_actions.name="DeckCloudActions";center.add_child(cloud_actions)
  var plaza=action(cloud_actions,"套牌广场",app.open_deck_plaza);plaza.name="DeckPlazaButton";expand(plaza)
  var upload=action(cloud_actions,app.deck_upload_caption(),app.upload_current_deck);upload.name="DeckUploadButton";expand(upload)
 app.deck_canvas=VBoxContainer.new();app.deck_canvas.name="DeckCanvas";center.add_child(app.deck_canvas);expand(app.deck_canvas,true)
 app.counts=text(center,"");app.counts.add_theme_font_size_override("font_size",metrics.small)
 app.counts.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 catalogue=panel(columns);catalogue.name="LibraryPanel"
 var right=column(catalogue)
 if swapping:
  text(right,"调整方法",metrics.title)
  var instructions=text(right,"点击或拖动卡牌，在主卡组和副卡组之间移动。\n拖到卡牌上可交换；同组拖动可排序。\n完成时须符合登记牌池与张数限制。")
  instructions.name="SideboardInstructions";instructions.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  app.sideboard_status=text(right,"");app.sideboard_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;expand(app.sideboard_status,true)
  app.sideboard_done=action(right,"更换完成",app.complete_sideboard,true)
 else:build_library(right)
 columns.resized.connect(relayout)
 app.deck_canvas.resized.connect(resize_grid)
 relayout()
 app.update_preview()
 if not swapping:app.update_library()
 app.update_deck_rows()
 if swapping:app.sideboard_changed()

func build_library(right: VBoxContainer):
 app.color_buttons.clear()
 app.library_sort_choice=null
 var search=LineEdit.new();search.name="LibrarySearch";search.placeholder_text="搜索卡名 / 颜色 / 类别";search.text=app.query
 search.custom_minimum_size.y=metrics.hit;right.add_child(search)
 search.text_changed.connect(func(value):app.query=value;app.update_library())
 var scroll=ScrollContainer.new();scroll.name="LibraryScroll";right.add_child(scroll);expand(scroll,true)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 scroll.set_drag_forwarding(Callable(),app.can_return_card,app.return_card_to_library)
 app.library=GridContainer.new();app.library.columns=1;scroll.add_child(app.library);expand(app.library)
 app.library.set_drag_forwarding(Callable(),app.can_return_card,app.return_card_to_library)
 app.saved_select=OptionButton.new();app.saved_select.name="SavedDeckSelect";right.add_child(app.saved_select);metrics.button(app.saved_select)
 app.saved_select.fit_to_longest_item=false
 app.enable_android_popup_swipe(app.saved_select.get_popup())
 app.saved_select.add_item("选择卡组")
 for d in app.decks:
  app.saved_select.add_item(d.name)
  if d.id==app.draft.id:app.saved_select.select(app.saved_select.item_count-1)
 app.saved_select.item_selected.connect(func(i):
  if i>0:app.guard(func():app.draft=app.decks[i-1].duplicate(true);app.dirty=false;app.editor()))
 var actions=HBoxContainer.new();right.add_child(actions)
 expand(action(actions,"保存",app.save_deck,true))
 expand(action(actions,"使用",app.use_deck))
 var entries=[["导出代码",app.export_deck],["导入代码",app.import_deck],
  ["新建",func():app.guard(func():app.draft=app.Store.blank();app.dirty=false;app.editor();app.rename_dialog())],
  ["重命名",app.rename_dialog],
  ["清空卡组",func():app.confirm_action("清空当前卡组？",func():app.draft.main.clear();app.draft.side.clear();app.draft.leader="";app.dirty=true;app.update_deck_rows())],
  ["删除卡组",app.delete_deck_dialog]]
 expand(menu_button(actions,"更多",entries))

func relayout():
 if not is_instance_valid(columns):return
 var layout=metrics.columns(app.screen.size.x)
 details.custom_minimum_size.x=layout.details
 details.visible=layout.inline
 detail_button.visible=not layout.inline
 catalogue.custom_minimum_size.x=layout.library
 resize_grid()

func resize_grid():
 if not is_instance_valid(app.deck_canvas) or app.deck_canvas.size.x<100:return
 if last_canvas_size.is_equal_approx(app.deck_canvas.size):return
 last_canvas_size=app.deck_canvas.size
 app.call_deferred("update_deck_rows")

func toggle_details():
 if is_instance_valid(details_overlay):close_details();return
 details_overlay=Control.new();app.screen.add_child(details_overlay);details_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var shade=ColorRect.new();shade.color=Color(0,0,0,0.75);details_overlay.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 shade.gui_input.connect(func(event):
  if event is InputEventMouseButton and event.pressed:close_details())
 var popup=panel(details_overlay)
 popup.size=Vector2(minf(620,app.screen.size.x-40),app.screen.size.y-32)
 popup.position=(app.screen.size-popup.size)*0.5
 var body=column(popup)
 action(body,"关闭详情",close_details)
 app.preview.reparent(body)
 app.update_preview()

func close_details():
 if not is_instance_valid(details_overlay):return
 app.preview.reparent(preview_home)
 details_overlay.queue_free();details_overlay=null

func update_preview():
 app.free_children(app.preview)
 var width=maxf(220,app.preview.size.x)
 var info=app.Store.CARDS[app.selected]
 var picture=TextureRect.new();picture.texture=app.preview_texture(app.selected)
 picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 picture.custom_minimum_size.y=minf(app.screen.size.y*0.42,width*(0.72 if app.landscape_card(app.selected) else 1.397))
 picture.mouse_filter=Control.MOUSE_FILTER_IGNORE;app.preview.add_child(picture)
 var scroll=ScrollContainer.new();scroll.name="CardTextScroll";scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 app.preview.add_child(scroll);expand(scroll,true)
 var body=column(scroll)
 var title=text(body,info.name,metrics.body+2);title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;title.add_theme_color_override("font_color",app.GOLD)
 var costs=app.HexCost.new();body.add_child(costs);costs.configure(info.cost,false,width-12,metrics.body*1.5,info.get("variable_cost",""))
 var description=text(body,app.card_description(app.selected));description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 if app.sideboard_session==null:
  if not app.RuleSet.allowed(app.selected,info,str(app.draft.get("rule_set",app.RuleSet.OFFICIAL))):
   var notice=text(app.preview,"此规则集仅供查看",metrics.small);notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  elif info.kind=="自机":action(app.preview,"设为自机",func():app.add_to("leader"),true)

func update_deck():
 var old_scroll=app.main_scroll.scroll_vertical if is_instance_valid(app.main_scroll) else 0
 app.free_children(app.deck_canvas)
 var width=maxf(440,app.deck_canvas.size.x)
 leader_width=clampf(width*0.1,60,96)
 var available=width-leader_width-metrics.gap-16
 var side_width=minf(72,(width-16-9*deck_gap)/10)
 var side_height=side_width*1.397+4
 # Fill the main deck's width with ten cards. Taller decks can scroll inside
 # their own area instead of leaving a wide blank strip on the right.
 deck_columns=10
 var width_limit=(available-(deck_columns-1)*deck_gap)/deck_columns
 var card_width=maxf(1.0,width_limit)
 tile_size=Vector2(card_width,card_width*1.397)
 app.main_scroll=ScrollContainer.new();app.main_scroll.name="MainDeckScroll";app.deck_canvas.add_child(app.main_scroll);expand(app.main_scroll,true)
 app.main_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 app.main_content=Control.new();app.main_content.name="MainDeckCards";app.main_scroll.add_child(app.main_content);expand(app.main_content,true)
 var rows_needed=ceili(float(app.draft.main.size())/deck_columns)
 var height=maxf(leader_width*1.397,rows_needed*tile_size.y+maxi(0,rows_needed-1)*deck_gap)
 app.main_content.custom_minimum_size=Vector2(0,height)
 var drop=app.make_drop_zone("main",Rect2(0,0,width-16,height),app.main_content)
 drop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 main_row=HBoxContainer.new();app.main_content.add_child(main_row);main_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 main_row.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var leader=Control.new();leader.custom_minimum_size.x=leader_width;main_row.add_child(leader)
 app.make_drop_zone("leader",Rect2(0,0,leader_width,leader_width*1.397),leader)
 if not app.draft.leader.is_empty():app.editor_card(app.draft.leader,"leader",0,Rect2(0,0,leader_width,leader_width*1.397),leader)
 grid=GridContainer.new();grid.name="MainCardGrid";grid.columns=deck_columns;main_row.add_child(grid);expand(grid)
 grid.add_theme_constant_override("h_separation",int(deck_gap))
 grid.add_theme_constant_override("v_separation",int(deck_gap))
 grid.mouse_filter=Control.MOUSE_FILTER_IGNORE
 for i in range(app.draft.main.size()):
  var tile=app.editor_card(app.draft.main[i],"main",i,Rect2(Vector2.ZERO,tile_size),grid)
  tile.custom_minimum_size=tile_size
 app.main_scroll.set_deferred("scroll_vertical",old_scroll)
 var counts={"红":0,"蓝":0,"绿":0,"黄":0,"黑":0}
 for id in app.draft.main:
  for color in app.Store.CARDS[id].colors:counts[color]+=1
 var stats=[]
 for color in counts:stats.append("%s %d" % [color,counts[color]])
 side_header=text(app.deck_canvas,"副卡组   ·   "+"  ".join(stats),metrics.small)
 side_header.clip_text=true;side_header.add_theme_color_override("font_color",app.MUTED)
 var side_scroll=ScrollContainer.new();side_scroll.name="SideDeckScroll";app.deck_canvas.add_child(side_scroll)
 side_scroll.custom_minimum_size.y=side_height
 side_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var side=Control.new();side_scroll.add_child(side)
 side_stride=side_width+deck_gap
 side.custom_minimum_size=Vector2(maxf(width,side_stride*app.draft.side.size()),side_width*1.397)
 app.make_drop_zone("side",Rect2(Vector2.ZERO,side.custom_minimum_size),side)
 side_grid=HBoxContainer.new();side.add_child(side_grid);side_grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 side_grid.add_theme_constant_override("separation",int(deck_gap))
 side_grid.mouse_filter=Control.MOUSE_FILTER_IGNORE
 for i in range(app.draft.side.size()):
  var tile=app.editor_card(app.draft.side[i],"side",i,Rect2(0,0,side_width,side_width*1.397),side_grid)
  tile.custom_minimum_size=Vector2(side_width,side_width*1.397)

func main_card_rect(index: int) -> Rect2:
 return Rect2(leader_width+metrics.gap+(index%deck_columns)*(tile_size.x+deck_gap),floorf(float(index)/deck_columns)*(tile_size.y+deck_gap),tile_size.x,tile_size.y)

func insert_index(target: String,at: Vector2) -> int:
 if target=="main":
  var row=maxi(0,int(floorf(at.y/(tile_size.y+deck_gap))))
  var col=clampi(int(roundf((at.x-leader_width-metrics.gap)/(tile_size.x+deck_gap))),0,deck_columns)
  return clampi(row*deck_columns+col,0,app.draft.main.size())
 if target=="side":return clampi(int(roundf(at.x/side_stride)),0,app.draft.side.size())
 return -1
