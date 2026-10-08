extends "res://scripts/deck_editor_layout.gd"
## Android collection / deck overview share one draft and the existing deck rules.
const DeckCard=preload("res://scripts/deck_card.gd")
class LibraryPageArrow extends Button:
 var direction=1
 func _draw():
  var inset=8.0
  var extent=size-Vector2(inset*2,inset*2)
  var points=PackedVector2Array([Vector2(0,0.28),Vector2(0.52,0.28),Vector2(0.52,0),Vector2(1,0.5),Vector2(0.52,1),Vector2(0.52,0.72),Vector2(0,0.72)])
  for i in range(points.size()):
   if direction<0:points[i].x=1.0-points[i].x
   points[i]=Vector2(inset,inset)+points[i]*extent
  var color=Color("#e8c77e")
  if disabled:color=Color("#687a87",0.35)
  elif is_pressed():color=Color("#ac8c48")
  elif is_hovered():color=Color("#ffe3a1")
  draw_colored_polygon(points,color)
  if has_focus() and not disabled:
   points.append(points[0]);draw_polyline(points,Color("#ffffff"),2,true)

var overview=false
var view_switch: CheckButton
var management: VBoxContainer
var management_scroll: ScrollContainer
var toolbar: HBoxContainer
var tools_menu: Button
var rules_menu: PopupMenu
var switchers: HBoxContainer
var deck_panel: PanelContainer
var library_scroll: ScrollContainer
var library_status: Label
const LIBRARY_COLUMNS=4
const LIBRARY_ROWS=2
const LIBRARY_PAGE_SIZE=LIBRARY_COLUMNS*LIBRARY_ROWS
var library_page=0
var library_pages=1
var library_filter_state={}
var library_filtered_ids: Array=[]
var previous_library_page: Button
var next_library_page: Button
var library_page_label: Label
var library_tile_size=Vector2(150,232)
var library_filter_button: Button
var library_filter_overlay: Control
var library_filter_popup: PanelContainer
var library_search_bar: HBoxContainer
var list_height=72.0
var detail_zone="library"
var detail_index=-1
var detail_popup: PanelContainer
var scroll_positions={false:0,true:0}
var list_sections={}
var list_zone="main"
var list_rows={}
var list_scroll_positions={"main":0,"side":0}
var list_switchers: HBoxContainer
var list_buttons={}
var thumbnails={}
var gallery_art_pending=false
var touch_surfaces=preload("res://scripts/android_card_touch.gd").new()
var finger=-1
var touch_tile: WeakRef
var touch_origin=Vector2.ZERO
var touch_moved=false
const MAIN_COLUMNS=10
const SIDE_COLUMNS=2
const OVERVIEW_ROWS=5
const MAIN_PAGE_SIZE=MAIN_COLUMNS*OVERVIEW_ROWS
var main_page=0
var main_pages=1
var overview_panes: HBoxContainer
var side_scroll: ScrollContainer
var editor_root: VBoxContainer
var editor_heading: Label
var overview_menu: PanelContainer
var catalogue_back: Button

func editor_button(control: Control):
 if control is BaseButton:metrics.button(control)
 else:
  control.custom_minimum_size.y=metrics.hit
  control.add_theme_font_size_override("font_size",metrics.button_font)
 return control

func build(host,_swapping: bool=false):
 app=host;metrics=app.ui_metrics;overview=app.android_editor_overview
 list_zone=str(app.get_meta("android_editor_list_zone","main"))
 library_page=int(app.get_meta("android_editor_library_page",0))
 library_filter_state=app.get_meta("android_editor_library_filters",{}).duplicate(true)
 var root=column(app.screen);root.name="ResponsiveDeckEditor"
 editor_root=root
 root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 toolbar=HBoxContainer.new();root.add_child(toolbar)
 editor_heading=text(toolbar,"卡组编辑器",metrics.title);expand(editor_heading)
 editor_heading.add_theme_font_size_override("font_size",30)
 editor_heading.add_theme_color_override("font_color",app.GOLD)
 build_switchers()
 catalogue_back=action(toolbar,"返回主菜单",func():app.guard(app.menu))
 editor_button(catalogue_back)
 catalogue_back.name="LibraryBackToMenu"
 # Keep the view switch at the right edge when the collection back button hides.
 view_switch=CheckButton.new();view_switch.name="DeckViewSwitch";view_switch.text="切换图鉴/卡组"
 toolbar.add_child(view_switch);metrics.button(view_switch)
 editor_button(view_switch);view_switch.custom_minimum_size.x+=metrics.hit
 view_switch.set_pressed_no_signal(overview)
 view_switch.toggled.connect(set_overview)
 overview_menu=panel(root);overview_menu.name="DeckMenuPanel"
 management_scroll=ScrollContainer.new();management_scroll.name="DeckManagementScroll";overview_menu.add_child(management_scroll);expand(management_scroll,true)
 management_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 management_scroll.set_meta("android_swipe_prefer_vertical",true)
 management=column(management_scroll);management.name="DeckManagement"
 build_management()
 columns=HBoxContainer.new();columns.name="DeckEditorPanes";root.add_child(columns);expand(columns,true)
 catalogue=panel(columns);catalogue.name="LibraryPanel";expand(catalogue,true)
 build_library_gallery(column(catalogue))
 deck_panel=panel(columns);deck_panel.name="DeckPanel";expand(deck_panel,true)
 center=column(deck_panel)
 app.name_label=text(center,"",28);app.name_label.clip_text=true
 app.name_label.add_theme_color_override("font_color",app.GOLD)
 app.deck_canvas=VBoxContainer.new();app.deck_canvas.name="DeckCanvas";center.add_child(app.deck_canvas);expand(app.deck_canvas,true)
 app.counts=text(center,"",24)
 build_list_switchers()
 # The preview lives off screen until a card is tapped.
 details=panel(root);details.name="CardDetailsPanel";details.hide()
 preview_home=column(details)
 app.preview=VBoxContainer.new();app.preview.name="CardPreview";preview_home.add_child(app.preview);expand(app.preview,true)
 columns.resized.connect(relayout)
 library_scroll.resized.connect(resize_library)
 app.deck_canvas.resized.connect(resize_grid)
 apply_view()
 app.update_library();app.update_deck_rows()

func build_list_switchers():
 list_switchers=HBoxContainer.new();list_switchers.name="DeckListSwitchers";center.add_child(list_switchers)
 var group=ButtonGroup.new()
 for source in ["main","side"]:
  var button=action(list_switchers,"主卡组" if source=="main" else "副卡组",func():set_list_zone(source))
  button.name="MainDeckListButton" if source=="main" else "SideDeckListButton"
  button.toggle_mode=true;button.button_group=group;expand(button)
  list_buttons[source]=button

func set_list_zone(source: String):
 if source==list_zone or source not in ["main","side"]:return
 if is_instance_valid(app.main_scroll):list_scroll_positions[list_zone]=app.main_scroll.scroll_vertical
 close_details()
 list_zone=source;app.set_meta("android_editor_list_zone",source)
 app.update_deck_rows()
 app.main_scroll.set_deferred("scroll_vertical",list_scroll_positions[source])

func build_switchers():
 switchers=HBoxContainer.new();switchers.name="DeckSwitchers";toolbar.add_child(switchers);expand(switchers)
 app.saved_select=action(switchers,"选择卡组",app.open_editor_deck_picker);app.saved_select.name="SavedDeckSelect"
 editor_button(app.saved_select);expand(app.saved_select)
 var rules=OptionButton.new();rules.name="DeckRuleSet";switchers.add_child(rules);editor_button(rules)
 for caption in app.RuleSet.LABELS:rules.add_item("规则："+caption)
 rules.select(maxi(0,app.RuleSet.IDS.find(str(app.draft.get("rule_set",app.RuleSet.OFFICIAL)))))
 rules.item_selected.connect(func(index):app.change_deck_rule_set(app.RuleSet.IDS[index]))
 rules_menu=rules.get_popup();app.enable_android_popup_swipe(rules_menu)

func build_management():
 expand(action(management,"保存",app.save_deck,true),true)
 var plaza=action(management,"套牌广场",app.open_deck_plaza);plaza.name="DeckPlazaButton";expand(plaza,true)
 var upload=action(management,app.deck_upload_caption(),app.upload_current_deck);upload.name="DeckUploadButton";expand(upload,true)
 var menu_entries=[["导出代码",app.export_deck],["导入代码",app.import_deck],
  ["新建",func():app.guard(func():app.draft=app.Store.blank();app.dirty=false;app.editor();app.rename_dialog())],
  ["重命名",app.rename_dialog],
  ["清空卡组",func():app.confirm_action("清空当前卡组？",func():app.draft.main.clear();app.draft.side.clear();app.draft.leader="";app.dirty=true;app.update_deck_rows())],
  ["删除卡组",app.delete_deck_dialog],["排序",app.sort_current_deck],
  ["卡组截图",app.capture_current_deck]]
 tools_menu=action(management,"菜单",func():app.open_menu_popup("组卡菜单",menu_entries,2))
 tools_menu.name="DeckToolsMenu";expand(tools_menu,true)
 tools_menu.add_theme_stylebox_override("normal",app.style(Color("#192a38"),Color("#3d5161")))
 tools_menu.add_theme_stylebox_override("hover",app.style(Color("#294354"),app.GOLD))
 tools_menu.add_theme_stylebox_override("pressed",app.style(Color("#615135"),app.GOLD))
 tools_menu.add_theme_stylebox_override("focus",app.style(Color.TRANSPARENT,app.GOLD))
 var back=action(management,"返回主菜单",func():app.guard(app.menu));back.name="DeckBackToMenu";expand(back,true)
 for control in management.get_children():editor_button(control)

func build_library_gallery(body: VBoxContainer):
 app.color_buttons.clear();app.library_sort_choice=null
 body.name="LibraryGalleryCards"
 library_search_bar=HBoxContainer.new();library_search_bar.name="LibrarySearchBar";toolbar.add_child(library_search_bar);expand(library_search_bar)
 toolbar.move_child(library_search_bar,1)
 var search=LineEdit.new();search.name="LibrarySearch";search.placeholder_text="搜索卡名 / 描述 / 颜色";search.text=app.query
 search.tooltip_text="搜索卡名 / 描述 / 别名 / 颜色 / 类别"
 library_search_bar.add_child(search);editor_button(search);expand(search)
 search.custom_minimum_size.x=120
 search.clear_button_enabled=true
 search.text_changed.connect(func(value):app.query=value;app.update_library())
 library_filter_button=action(library_search_bar,"筛选",toggle_library_filters);editor_button(library_filter_button);library_filter_button.name="LibraryFilterButton"
 library_status=text(body,"",metrics.small);library_status.name="LibraryStatus"
 library_status.clip_text=true
 library_status.add_theme_font_size_override("font_size",22)
 library_status.add_theme_color_override("font_color",app.MUTED)
 var gallery=HBoxContainer.new();gallery.name="LibraryGallerySides";body.add_child(gallery);expand(gallery,true)
 var previous_rail=VBoxContainer.new();gallery.add_child(previous_rail)
 var previous_space=Control.new();previous_rail.add_child(previous_space);expand(previous_space,true)
 previous_library_page=page_arrow(previous_rail,-1,func():change_library_page(library_page-1));previous_library_page.name="PreviousLibraryPage"
 var previous_bottom=Control.new();previous_rail.add_child(previous_bottom);expand(previous_bottom,true)
 library_scroll=ScrollContainer.new();library_scroll.name="LibraryScroll";gallery.add_child(library_scroll);expand(library_scroll,true)
 var next_rail=VBoxContainer.new();gallery.add_child(next_rail)
 var next_space=Control.new();next_rail.add_child(next_space);expand(next_space,true)
 next_library_page=page_arrow(next_rail,1,func():change_library_page(library_page+1));next_library_page.name="NextLibraryPage"
 var next_bottom=Control.new();next_rail.add_child(next_bottom);expand(next_bottom,true)
 library_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 # DISABLED propagates the cards' previous minimum height into the root and
 # prevents the gallery from shrinking when the available height decreases.
 library_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
 library_scroll.set_meta("android_swipe_handled",true)
 app.library=GridContainer.new();app.library.name="LibraryCardGrid";app.library.columns=LIBRARY_COLUMNS
 app.library.add_theme_constant_override("h_separation",int(metrics.gap))
 app.library.add_theme_constant_override("v_separation",int(metrics.gap))
 library_scroll.add_child(app.library)
 app.library.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var pagination=HBoxContainer.new();pagination.name="LibraryPagination";body.add_child(pagination)
 library_page_label=text(pagination,"",metrics.small);library_page_label.name="LibraryPageLabel"
 library_page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;expand(library_page_label)
 var tutorial=action(pagination,"组卡教程",app.show_deck_tutorial);tutorial.name="LibraryDeckTutorialButton"
 editor_button(tutorial)
 build_library_filters()

func build_library_filters():
 library_filter_overlay=Control.new();library_filter_overlay.name="LibraryFilterOverlay";app.screen.add_child(library_filter_overlay)
 library_filter_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 library_filter_overlay.mouse_filter=Control.MOUSE_FILTER_STOP
 var shade=ColorRect.new();shade.color=Color(0,0,0,0.76);library_filter_overlay.add_child(shade)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 shade.gui_input.connect(func(event):
  if event is InputEventMouseButton and not event.pressed and event.button_index==MOUSE_BUTTON_LEFT:close_library_filters())
 library_filter_popup=panel(library_filter_overlay);library_filter_popup.name="LibraryFilterPopup"
 var filters=column(library_filter_popup);filters.name="LibraryFilters"
 var heading=HBoxContainer.new();filters.add_child(heading)
 var title=text(heading,"筛选卡牌",32);title.add_theme_color_override("font_color",app.GOLD);expand(title)
 editor_button(action(heading,"关闭",close_library_filters))
 var options=HBoxContainer.new();filters.add_child(options)
 var type_column=column(options)
 var sort_column=column(options)
 text(type_column,"卡牌类型",24)
 var kind=OptionButton.new();kind.name="LibraryKindFilter";type_column.add_child(kind);editor_button(kind)
 kind.fit_to_longest_item=false;kind.tooltip_text="类型筛选"
 for value in app.SearchAliases.ANDROID_FILTER_KINDS:kind.add_item("全部类型" if value=="全部" else value)
 kind.select(maxi(0,app.SearchAliases.ANDROID_FILTER_KINDS.find("自机单位" if app.filter_kind=="自机" else app.filter_kind)))
 kind.item_selected.connect(func(index):app.filter_kind=app.SearchAliases.ANDROID_FILTER_KINDS[index];app.update_library())
 app.enable_android_popup_swipe(kind.get_popup())
 text(filters,"颜色（可以多选）",24)
 var color_scroll=ScrollContainer.new();color_scroll.name="LibraryColorScroll";filters.add_child(color_scroll)
 color_scroll.custom_minimum_size.y=metrics.hit*2+metrics.gap
 color_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 color_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
 color_scroll.set_meta("android_swipe_prefer_vertical",true)
 var colors=GridContainer.new();colors.name="LibraryColorFilters";colors.columns=3;color_scroll.add_child(colors);expand(colors)
 var swatches=[Color("#344553"),Color("#a83035"),Color("#337aa7"),Color("#39794d"),Color("#ac963b"),Color("#383a42")]
 var values=["全部"]+app.SearchAliases.COLORS
 for i in range(values.size()):
  var value=values[i]
  var choice=action(colors,value,func():app.toggle_color(value));choice.name="LibraryColor"+value
  editor_button(choice);choice.toggle_mode=true;expand(choice)
  choice.add_theme_stylebox_override("normal",app.style(swatches[i]))
  choice.add_theme_stylebox_override("hover",app.style(swatches[i].lightened(0.15),app.GOLD))
  choice.add_theme_stylebox_override("pressed",app.style(swatches[i],app.GOLD))
  app.color_buttons[value]=choice
 text(sort_column,"卡库排序",24)
 var sort=OptionButton.new();sort.name="LibrarySortChoice";sort_column.add_child(sort);editor_button(sort)
 sort.fit_to_longest_item=false
 for mode in ["类别","颜色值","名字"]:sort.add_item(mode)
 sort.select(maxi(0,["类别","颜色值","名字"].find(app.library_sort_mode)))
 sort.item_selected.connect(func(index):app.library_sort_mode=["类别","颜色值","名字"][index];app.update_library())
 app.library_sort_choice=sort;app.enable_android_popup_swipe(sort.get_popup())
 app.refresh_color_buttons()
 library_filter_overlay.hide()

func toggle_library_filters():
 if library_filter_overlay.visible:close_library_filters()
 else:
  layout_library_filters()
  library_filter_overlay.show()
  library_filter_overlay.move_to_front()

func close_library_filters():
 if is_instance_valid(library_filter_overlay):library_filter_overlay.hide()

func layout_library_filters():
 if not is_instance_valid(library_filter_popup):return
 library_filter_popup.size=Vector2(minf(800,app.screen.size.x-metrics.padding*2),app.screen.size.y-metrics.padding*2)
 library_filter_popup.position=(app.screen.size-library_filter_popup.size)*0.5

func page_arrow(parent: Node,direction: int,callback: Callable) -> Button:
 var arrow=LibraryPageArrow.new();arrow.direction=direction;parent.add_child(arrow)
 arrow.custom_minimum_size=Vector2(metrics.hit*1.45,metrics.hit)
 arrow.tooltip_text="上一页" if direction<0 else "下一页"
 for state in ["normal","hover","pressed","disabled","focus"]:arrow.add_theme_stylebox_override(state,StyleBoxEmpty.new())
 arrow.pressed.connect(callback)
 return arrow

func set_overview(value: bool):
 if overview==value:return
 if is_instance_valid(app.main_scroll):scroll_positions[overview]=app.main_scroll.scroll_vertical
 close_details()
 overview=value;app.android_editor_overview=value
 apply_view()
 last_canvas_size=Vector2(-1,-1)
 app.update_deck_rows()
 app.main_scroll.set_deferred("scroll_vertical",scroll_positions[overview])

func apply_view():
 close_library_filters()
 editor_heading.visible=overview
 library_search_bar.visible=not overview
 if overview:
  if app.name_label.get_parent()!=toolbar:app.name_label.reparent(toolbar)
  toolbar.move_child(app.name_label,1)
  editor_heading.size_flags_horizontal=Control.SIZE_FILL
  expand(app.name_label)
 else:
  if app.name_label.get_parent()!=center:app.name_label.reparent(center)
  center.move_child(app.name_label,0)
  expand(editor_heading)
 switchers.visible=overview
 if not overview and overview_menu.get_parent()!=editor_root:overview_menu.reparent(editor_root)
 overview_menu.visible=overview;catalogue.visible=not overview
 list_switchers.visible=not overview
 catalogue_back.visible=not overview
 view_switch.set_pressed_no_signal(overview)
 app.name_label.tooltip_text="当前卡组"
 relayout()

func relayout():
 if not is_instance_valid(columns):return
 deck_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL if overview else Control.SIZE_FILL
 deck_panel.custom_minimum_size.x=0 if overview else clampf(app.screen.size.x*0.28,metrics.hit*3.4,app.screen.size.x*0.38)
 layout_library_filters()
 resize_library();resize_grid()
 if is_instance_valid(detail_popup):
  detail_popup.size=Vector2(minf(1200,app.screen.size.x-metrics.padding*2),app.screen.size.y-metrics.padding*2)
  detail_popup.position=(app.screen.size-detail_popup.size)*0.5
  app.update_preview()

func resize_library():
 if not is_instance_valid(library_scroll) or library_scroll.size.x<100 or library_scroll.size.y<100:return
 var width=library_scroll.size.x
 var height=library_scroll.size.y
 var row_height=maxf(1,(height-metrics.gap*(LIBRARY_ROWS-1))/LIBRARY_ROWS)
 var tile_width=floorf(maxf(1,(width-metrics.gap*(LIBRARY_COLUMNS-1))/LIBRARY_COLUMNS))
 library_tile_size=Vector2(tile_width,row_height)
 app.library.custom_minimum_size.x=LIBRARY_COLUMNS*tile_width+metrics.gap*(LIBRARY_COLUMNS-1)
 for item in app.library.get_children():item.custom_minimum_size=library_tile_size
 queue_gallery_art()

func update_library():
 var filters={"query":app.query,"kind":app.filter_kind,"colors":app.selected_colors.duplicate(),"sort":app.library_sort_mode}
 if filters!=library_filter_state:library_page=0
 library_filter_state=filters;library_filtered_ids=app.library_ids()
 var selected_count=app.selected_colors.size()+int(app.filter_kind!="全部")+int(app.library_sort_mode!="类别")
 library_filter_button.text="筛选" if selected_count==0 else "筛选 · %d" % selected_count
 library_pages=maxi(1,ceili(float(library_filtered_ids.size())/LIBRARY_PAGE_SIZE))
 library_page=clampi(library_page,0,library_pages-1)
 render_library_page()

func change_library_page(value: int):
 var next_page=clampi(value,0,library_pages-1)
 if next_page==library_page:return
 cancel_touch_holds()
 library_page=next_page
 render_library_page()

func render_library_page():
 app.free_children(app.library);app.library_rows.clear()
 library_scroll.scroll_vertical=0
 app.set_meta("android_editor_library_page",library_page);app.set_meta("android_editor_library_filters",library_filter_state.duplicate(true))
 var rule_set=str(app.draft.get("rule_set",app.RuleSet.OFFICIAL))
 library_status.text="%d 张卡牌 · 长按查看详情并加入卡组" % library_filtered_ids.size() if not library_filtered_ids.is_empty() else "没有匹配的卡牌，试试其他关键词"
 library_page_label.text="%d / %d" % [library_page+1,library_pages]
 previous_library_page.disabled=library_page==0;next_library_page.disabled=library_page==library_pages-1
 resize_library()
 var start=library_page*LIBRARY_PAGE_SIZE
 var ids=library_filtered_ids.slice(start,start+LIBRARY_PAGE_SIZE)
 for id in ids:
  var info=app.Store.CARDS[id]
  var available=app.RuleSet.allowed(id,info,rule_set)
  var remaining=app.RuleSet.remaining(app.draft,id,app.Store.CARDS,rule_set)
  var tile=DeckCard.new();tile.is_android=true;tile.card_id=id;tile.source_zone="library"
  tile.tap_action=true;tile.long_press_enabled=false
  tile.hold_to_drag=true
  tile.texture_provider=func():return app.texture(id)
  tile.draggable=false;tile.set_meta("card_id",id)
  tile.custom_minimum_size=library_tile_size
  tile.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
  app.library.add_child(tile)
  var picture=TextureRect.new();picture.name="LibraryCardArt"
  picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  tile.add_child(picture);picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
  tile.resized.connect(func():layout_gallery_tile(tile))
  if not available:picture.modulate=Color(0.6,0.6,0.6)
  var inventory=text(tile,"余 %d" % remaining if remaining>=0 else "余 ∞",metrics.small)
  inventory.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  inventory.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
  inventory.name="LibraryRemaining"
  inventory.add_theme_color_override("font_color",app.GOLD if remaining!=0 else app.MUTED)
  var remaining_label: Label=inventory if available and remaining>=0 else null
  app.library_rows[id]={"row":tile,"remaining_label":remaining_label}
  tile.tooltip_text=info.name+("" if available else "\n此规则集仅供查看")
  tile.preview_requested.connect(func(card_id):app.selected=card_id)
  tile.art_requested.connect(app.open_art_picker)
  tile.clicked.connect(func(card_id,_zone,_index,_right):show_details(card_id))
 for slot in range(ids.size(),LIBRARY_PAGE_SIZE):
  var empty=Panel.new();empty.name="LibraryEmptySlot"+str(slot);empty.custom_minimum_size=library_tile_size
  empty.add_theme_stylebox_override("panel",metrics.panel_style());empty.modulate.a=0.35
  empty.mouse_filter=Control.MOUSE_FILTER_IGNORE;app.library.add_child(empty)
 queue_gallery_art()

func layout_gallery_tile(tile: Control):
 var picture=tile.find_child("LibraryCardArt",true,false) as TextureRect
 if picture==null:return
 var caption_height=maxf(32,metrics.small*1.4)
 var art_height=maxf(1,tile.size.y-caption_height-4)
 var art_width=minf(tile.size.x,art_height/1.397)
 picture.size=Vector2(art_width,art_width*1.397)
 picture.position=Vector2((tile.size.x-picture.size.x)*0.5,0)
 var inventory=tile.find_child("LibraryRemaining",true,false) as Label
 inventory.position=Vector2(picture.position.x,picture.size.y+4)
 inventory.size=Vector2(picture.size.x,caption_height)

func queue_gallery_art():
 if gallery_art_pending:return
 gallery_art_pending=true;call_deferred("refresh_gallery_art")

func refresh_gallery_art():
 gallery_art_pending=false
 if not is_instance_valid(library_scroll) or not library_scroll.is_visible_in_tree():return
 var visible_area=library_scroll.get_global_rect().grow(library_tile_size.y)
 for id in app.library_rows:
  var tile=app.library_rows[id].row
  layout_gallery_tile(tile)
  var picture=tile.find_child("LibraryCardArt",true,false)
  if not visible_area.intersects(tile.get_global_rect()):picture.texture=null
  else:picture.texture=thumbnail(id)

func thumbnail(id: String) -> Texture2D:
 var path=app.CardArt.image_path(id,app.editor_art_id(id),app.Store.CARDS)
 if thumbnails.has(path):return thumbnails[path]
 var original=load(path) as Texture2D
 if original==null:return null
 var image=original.get_image()
 if image.get_width()>image.get_height():image.rotate_90(CLOCKWISE)
 image.resize(240,335,Image.INTERPOLATE_BILINEAR)
 var result=ImageTexture.create_from_image(image)
 if thumbnails.size()>=64:thumbnails.erase(thumbnails.keys()[0])
 thumbnails[path]=result
 return result

func update_deck():
 if app.counts.get_parent()!=center:app.counts.reparent(center)
 if overview:
  update_overview_deck()
  return
 var old_scroll=app.main_scroll.scroll_vertical if is_instance_valid(app.main_scroll) else scroll_positions[false]
 app.free_children(app.deck_canvas);list_sections.clear();list_rows.clear();grid=null;side_grid=null
 for source in list_buttons:list_buttons[source].set_pressed_no_signal(source==list_zone)
 list_height=clampf(app.screen.size.y*0.05,36,44)
 app.main_scroll=ScrollContainer.new();app.main_scroll.name="DeckListScroll";app.deck_canvas.add_child(app.main_scroll);expand(app.main_scroll,true)
 app.main_scroll.set_meta("android_swipe_prefer_vertical",true)
 app.main_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 app.main_content=VBoxContainer.new();app.main_content.name="DeckListCards";app.main_scroll.add_child(app.main_content);expand(app.main_content)
 var width=maxf(1,app.deck_canvas.size.x-metrics.padding*2-20)
 var leader_section=Control.new();app.main_content.add_child(leader_section);leader_section.custom_minimum_size.y=list_height
 if app.draft.leader.is_empty():
  var choose=action(leader_section,"选择自机",app.open_leader_picker,true)
  editor_button(choose);choose.add_theme_font_size_override("font_size",24)
  choose.name="ChooseDeckLeader";choose.custom_minimum_size=Vector2(150,list_height)
  choose.size=choose.custom_minimum_size
 else:
  var leader=row_card(app.draft.leader,"leader",0,leader_section,width)
  leader.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for source in [list_zone]:
  var entries=grouped_list(source);list_rows[source]=entries
  var section=Control.new();section.name="MainDeckList" if source=="main" else "SideDeckList";app.main_content.add_child(section)
  var height=maxf(list_height,entries.size()*(list_height+deck_gap)-deck_gap)
  section.custom_minimum_size.y=height;list_sections[source]=section
  var rows=VBoxContainer.new();section.add_child(rows);rows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  rows.mouse_filter=Control.MOUSE_FILTER_IGNORE;rows.add_theme_constant_override("separation",int(deck_gap))
  for entry in entries:row_card(entry.id,source,entry.index,rows,width,entry.count)
  if app.draft[source].is_empty():
   var hint=text(rows,"在卡牌详情中加入卡牌",metrics.small);hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hint.add_theme_color_override("font_color",app.MUTED)
 app.main_scroll.set_deferred("scroll_vertical",old_scroll)

func grouped_list(source: String) -> Array:
 var entries=[];var row_by_id={}
 for index in range(app.draft[source].size()):
  var id=app.draft[source][index]
  if row_by_id.has(id):entries[row_by_id[id]].count+=1
  else:
   row_by_id[id]=entries.size();entries.append({"id":id,"index":index,"count":1})
 return entries

func row_card(id: String,source: String,index: int,parent: Node,width: float,copies: int=1):
 # Text rows load card art only when inspection needs it.
 var tile=DeckCard.new();tile.is_android=true;tile.draggable=false;tile.hold_to_remove=true
 tile.tap_action=true;tile.long_press_enabled=false
 tile.card_id=id;tile.source_zone=source;tile.source_index=index
 tile.texture_provider=func():return app.texture(id)
 tile.tooltip_text=app.Store.CARDS[id].name+"\n点击：查看详情"
 tile.size=Vector2(width,list_height)
 tile.add_theme_stylebox_override("panel",app.style(Color("#142737"),app.GOLD if source=="leader" else Color("#677585")))
 parent.add_child(tile)
 tile.custom_minimum_size=Vector2(0,list_height);expand(tile)
 tile.preview_requested.connect(func(card_id):app.selected=card_id;app.update_preview())
 tile.remove_requested.connect(remove_list_card)
 tile.clicked.connect(func(card_id,from,index_in_deck,_right):app.zone=from;show_details(card_id,from,index_in_deck))
 var margin=MarginContainer.new();tile.add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 margin.mouse_filter=Control.MOUSE_FILTER_IGNORE
 margin.add_theme_constant_override("margin_left",8);margin.add_theme_constant_override("margin_right",4)
 var line=HBoxContainer.new();margin.add_child(line);line.mouse_filter=Control.MOUSE_FILTER_IGNORE
 line.add_theme_constant_override("separation",8)
 var name=text(line,app.Store.CARDS[id].name,22);name.name="DeckListName";name.clip_text=true;expand(name)
 name.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 if source!="leader":
  var quantity=text(line,"×%d" % copies,22);quantity.name="DeckListQuantity"
  quantity.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;quantity.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
  quantity.add_theme_color_override("font_color",app.GOLD)
 return tile

func remove_list_card(id: String,source: String,index: int):
 if overview or not remove_deck_copy(id,source,index):return
 app.dirty=true;app.update_deck_rows();app.update_preview()

func overview_geometry(width: float,height: float) -> Dictionary:
 var header_height=metrics.hit if main_pages>1 else 34.0
 var menu_width=maxf(260,maxf(28*8+metrics.padding*2,overview_menu.get_minimum_size().x))
 var available=width-menu_width-metrics.gap*3-deck_gap*(MAIN_COLUMNS+SIDE_COLUMNS-2)
 var width_limit=available/(MAIN_COLUMNS+SIDE_COLUMNS+2.5)
 var height_limit=(height-header_height-metrics.gap-deck_gap*(OVERVIEW_ROWS-1))/OVERVIEW_ROWS/1.397
 var card_width=floorf(maxf(1,minf(160,minf(width_limit,height_limit))))
 var card_height=floorf(card_width*1.397)
 var grid_height=OVERVIEW_ROWS*card_height+(OVERVIEW_ROWS-1)*deck_gap
 var leader_available=available-(MAIN_COLUMNS+SIDE_COLUMNS)*card_width
 var stats_height=40+metrics.gap
 var hero_width=minf(leader_available,maxf(1,(height-header_height-metrics.gap*2-stats_height)/1.397))
 menu_width+=maxf(0,leader_available-hero_width)
 return {"card":Vector2(card_width,card_height),
  "main_width":MAIN_COLUMNS*card_width+(MAIN_COLUMNS-1)*deck_gap,
  "side_width":SIDE_COLUMNS*card_width+(SIDE_COLUMNS-1)*deck_gap,
  "leader_width":hero_width,"menu_width":menu_width,"header_height":header_height}

func change_main_page(value: int):
 main_page=clampi(value,0,main_pages-1);app.android_editor_main_page=main_page
 app.update_deck_rows()

func overview_slot(parent: Node):
 var empty=Panel.new();parent.add_child(empty);empty.custom_minimum_size=tile_size
 empty.add_theme_stylebox_override("panel",app.style(Color("#10202c"),Color("#243948")))
 empty.mouse_filter=Control.MOUSE_FILTER_IGNORE
 return empty

func update_overview_deck():
 if overview_menu.get_parent()!=editor_root:overview_menu.reparent(editor_root)
 overview_menu.hide()
 app.free_children(app.deck_canvas)
 # Use the safe viewport width while containers settle after switching views.
 # A previous oversized minimum must not feed back into the next grid size.
 var width=maxf(100,minf(app.deck_canvas.size.x,app.screen.size.x-metrics.padding*2))
 main_pages=maxi(1,ceili(float(app.draft.main.size())/MAIN_PAGE_SIZE))
 main_page=clampi(app.android_editor_main_page,0,main_pages-1);app.android_editor_main_page=main_page
 var geometry=overview_geometry(width,maxf(100,app.deck_canvas.size.y))
 deck_columns=MAIN_COLUMNS;tile_size=geometry.card;leader_width=geometry.leader_width
 overview_panes=HBoxContainer.new();overview_panes.name="OverviewDeckPanes";app.deck_canvas.add_child(overview_panes);expand(overview_panes,true)
 var hero=column(overview_panes);hero.name="OverviewLeaderPane";hero.size_flags_horizontal=Control.SIZE_FILL;hero.custom_minimum_size.x=leader_width
 var hero_title=text(hero,"自机",24);hero_title.custom_minimum_size.y=geometry.header_height
 hero_title.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;hero_title.add_theme_color_override("font_color",app.GOLD)
 var leader=Control.new();hero.add_child(leader);leader.custom_minimum_size=Vector2(leader_width,leader_width*1.397)
 var leader_drop=app.make_drop_zone("leader",Rect2(0,0,leader_width,leader_width*1.397),leader)
 if app.draft.leader.is_empty():
  app.free_children(leader_drop)
  var hint=text(leader_drop,"选择自机",metrics.small);hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hint.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 else:app.editor_card(app.draft.leader,"leader",0,Rect2(0,0,leader_width,leader_width*1.397),leader)
 app.counts.reparent(hero);app.counts.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 var left=column(overview_panes);left.name="OverviewMainPane"
 left.size_flags_horizontal=Control.SIZE_FILL;left.custom_minimum_size.x=geometry.main_width
 var heading=HBoxContainer.new();left.add_child(heading);heading.custom_minimum_size.y=geometry.header_height
 var caption=text(heading,"主卡组",24);expand(caption);caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 caption.add_theme_color_override("font_color",app.GOLD)
 if main_pages>1:
  var previous=action(heading,"上一页",func():change_main_page(main_page-1));editor_button(previous);previous.name="PreviousMainPage";previous.disabled=main_page==0
  text(heading,"%d / %d" % [main_page+1,main_pages],24)
  var next=action(heading,"下一页",func():change_main_page(main_page+1));editor_button(next);next.name="NextMainPage";next.disabled=main_page==main_pages-1
 app.main_scroll=ScrollContainer.new();app.main_scroll.name="MainDeckScroll";left.add_child(app.main_scroll);expand(app.main_scroll,true)
 app.main_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 app.main_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
 app.main_content=Control.new();app.main_content.name="MainDeckCards";app.main_scroll.add_child(app.main_content);expand(app.main_content,true)
 var content_height=OVERVIEW_ROWS*tile_size.y+(OVERVIEW_ROWS-1)*deck_gap
 app.main_content.custom_minimum_size=Vector2(geometry.main_width,content_height)
 var drop=app.make_drop_zone("main",Rect2(0,0,geometry.main_width,content_height),app.main_content);drop.name="MainDeckFrame"
 grid=GridContainer.new();grid.name="MainCardGrid";grid.columns=deck_columns;app.main_content.add_child(grid)
 grid.add_theme_constant_override("h_separation",int(deck_gap));grid.add_theme_constant_override("v_separation",int(deck_gap))
 grid.mouse_filter=Control.MOUSE_FILTER_IGNORE
 for slot in range(MAIN_PAGE_SIZE):
  var index=main_page*MAIN_PAGE_SIZE+slot
  if index<app.draft.main.size():
   var tile=app.editor_card(app.draft.main[index],"main",index,Rect2(Vector2.ZERO,tile_size),grid)
   tile.custom_minimum_size=tile_size
  else:overview_slot(grid)
 var right=column(overview_panes);right.name="OverviewSidePane"
 right.size_flags_horizontal=Control.SIZE_FILL;right.custom_minimum_size.x=geometry.side_width
 side_header=text(right,"副卡组",24)
 side_header.custom_minimum_size.y=geometry.header_height
 side_header.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;side_header.add_theme_color_override("font_color",app.GOLD)
 side_scroll=ScrollContainer.new();side_scroll.name="SideDeckScroll";right.add_child(side_scroll);expand(side_scroll,true)
 side_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;side_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
 var side=Control.new();side.name="SideDeckCards";side_scroll.add_child(side);expand(side,true)
 side_stride=tile_size.x+deck_gap
 side.custom_minimum_size=Vector2(0,content_height)
 var side_drop=app.make_drop_zone("side",Rect2(0,0,geometry.side_width,content_height),side)
 var side_cards=GridContainer.new();side_cards.columns=SIDE_COLUMNS
 side_grid=side_cards;side_grid.name="SideCardGrid";side.add_child(side_grid)
 side_grid.add_theme_constant_override("h_separation",int(deck_gap));side_grid.add_theme_constant_override("v_separation",int(deck_gap))
 side_grid.mouse_filter=Control.MOUSE_FILTER_IGNORE
 for slot in range(SIDE_COLUMNS*OVERVIEW_ROWS):
  if slot<app.draft.side.size():
   var tile=app.editor_card(app.draft.side[slot],"side",slot,Rect2(Vector2.ZERO,tile_size),side_grid)
   tile.custom_minimum_size=tile_size
  else:overview_slot(side_grid)
 overview_menu.reparent(overview_panes);overview_menu.custom_minimum_size.x=geometry.menu_width
 overview_menu.size_flags_horizontal=Control.SIZE_EXPAND_FILL;overview_menu.show()

func main_card_rect(index: int) -> Rect2:
 if overview:
  var slot=index-main_page*MAIN_PAGE_SIZE
  var offset=grid.global_position-app.main_content.global_position
  return Rect2(offset+Vector2((slot%MAIN_COLUMNS)*(tile_size.x+deck_gap),floorf(float(slot)/MAIN_COLUMNS)*(tile_size.y+deck_gap)),tile_size)
 if not list_sections.has("main") or index<0 or index>=app.draft.main.size():return Rect2()
 var row=0
 for entry in list_rows.main:
  if entry.id==app.draft.main[index]:break
  row+=1
 return Rect2(list_sections.main.position+Vector2(0,row*(list_height+deck_gap)),Vector2(app.main_content.size.x,list_height))

func insert_index(target: String,at: Vector2) -> int:
 if overview:
  var offset=grid.global_position-app.main_content.global_position if target=="main" else side_grid.position
  var columns_count=MAIN_COLUMNS if target=="main" else SIDE_COLUMNS
  var row=clampi(int(floorf((at.y-offset.y)/(tile_size.y+deck_gap))),0,OVERVIEW_ROWS-1)
  var col=clampi(int(roundf((at.x-offset.x)/(tile_size.x+deck_gap))),0,columns_count)
  return clampi(row*columns_count+col+(main_page*MAIN_PAGE_SIZE if target=="main" else 0),0,app.draft[target].size()) if target in ["main","side"] else -1
 if list_rows.has(target):
  var entries=list_rows[target]
  var row=clampi(int(roundf(at.y/(list_height+deck_gap))),0,entries.size())
  return entries[row].index if row<entries.size() else app.draft[target].size()
 return -1

func show_details(id: String,source: String="library",index: int=-1):
 app.selected=id;detail_zone=source;detail_index=index
 if not is_instance_valid(details_overlay):
  details_overlay=Control.new();details_overlay.name="CardDetailsOverlay";app.screen.add_child(details_overlay)
  details_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  var shade=ColorRect.new();shade.color=Color(0,0,0,0.78);details_overlay.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  shade.gui_input.connect(func(event):
   if event is InputEventMouseButton and not event.pressed and event.button_index==MOUSE_BUTTON_LEFT:close_details())
  detail_popup=panel(details_overlay);detail_popup.name="CardDetailsPopup"
  var body=column(detail_popup)
  var header=HBoxContainer.new();body.add_child(header)
  var title=text(header,"卡牌详情",metrics.title);expand(title);title.add_theme_color_override("font_color",app.GOLD)
  action(header,"关闭",close_details)
  app.preview.reparent(body)
 relayout()

func toggle_details():
 if is_instance_valid(details_overlay):close_details()
 else:show_details(app.selected)

func close_details():
 if not is_instance_valid(details_overlay):return
 app.preview.reparent(preview_home)
 details_overlay.queue_free();details_overlay=null;detail_popup=null

func update_preview():
 if not is_instance_valid(details_overlay) or not app.Store.CARDS.has(app.selected):return
 app.free_children(app.preview)
 var info=app.Store.CARDS[app.selected]
 var panes=HBoxContainer.new();panes.name="CardDetailsPanes";app.preview.add_child(panes);expand(panes,true)
 var left=column(panes);left.name="CardDescriptionPane"
 var scroll=ScrollContainer.new();scroll.name="CardTextScroll";left.add_child(scroll);expand(scroll,true)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var body=column(scroll)
 var title=text(body,info.name,metrics.title);title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;title.add_theme_color_override("font_color",app.GOLD)
 var width=maxf(100,(detail_popup.size.x-metrics.padding*2-metrics.gap)*0.52)
 var costs=app.HexCost.new();body.add_child(costs);costs.configure(info.cost,false,width-20,metrics.body*1.5,info.get("variable_cost",""))
 var description=text(body,app.card_description(app.selected));description.name="CardDescription";description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var actions=GridContainer.new();actions.name="CardDetailsActions";actions.columns=2;left.add_child(actions)
 var allowed=app.RuleSet.allowed(app.selected,info,str(app.draft.get("rule_set",app.RuleSet.OFFICIAL)))
 if not allowed:
  var notice=text(actions,"此规则集仅供查看",metrics.small);notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 else:
  var add_main=action(actions,"加入主卡组",func():app.add_to("main");app.update_preview(),true);expand(add_main)
  var add_side=action(actions,"加入副卡组",func():app.add_to("side");app.update_preview());expand(add_side)
  add_main.text_overrun_behavior=TextServer.OVERRUN_NO_TRIMMING
  add_side.text_overrun_behavior=TextServer.OVERRUN_NO_TRIMMING
  if info.kind=="自机":expand(action(actions,"设为自机",func():app.add_to("leader");close_details(),true))
 if detail_zone in ["main","side","leader"]:
  expand(action(actions,"移出卡组",remove_inspected_card))
 if app.CardArt.options(app.selected,app.Store.CARDS).size()>1:
  expand(action(actions,"更换异画",func():app.open_art_picker(app.selected)))
 if detail_zone=="leader":expand(action(actions,"更换自机",func():close_details();app.open_leader_picker()))
 var picture=TextureRect.new();picture.name="CardDetailsArt";picture.texture=app.preview_texture(app.selected)
 picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 panes.add_child(picture);expand(picture,true);picture.size_flags_stretch_ratio=0.92;picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var remaining=app.RuleSet.remaining(app.draft,app.selected,app.Store.CARDS,str(app.draft.get("rule_set",app.RuleSet.OFFICIAL)))
 var inventory=Label.new();inventory.name="CardDetailsRemaining"
 inventory.text="余 %d" % remaining if remaining>=0 else "余 ∞"
 inventory.add_theme_font_size_override("font_size",metrics.body)
 inventory.add_theme_color_override("font_color",app.GOLD if remaining!=0 else app.MUTED)
 inventory.add_theme_color_override("font_outline_color",Color.BLACK);inventory.add_theme_constant_override("outline_size",4)
 inventory.add_theme_stylebox_override("normal",app.style(Color(0.04,0.08,0.12,0.88),app.GOLD))
 inventory.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;inventory.vertical_alignment=VERTICAL_ALIGNMENT_BOTTOM
 inventory.mouse_filter=Control.MOUSE_FILTER_IGNORE;picture.add_child(inventory)
 picture.resized.connect(func():fit_detail_inventory(picture,inventory))
 fit_detail_inventory.call_deferred(picture,inventory)

func fit_detail_inventory(picture: TextureRect,inventory: Label):
 if not is_instance_valid(picture) or not is_instance_valid(inventory):return
 var displayed=picture.size
 if picture.texture!=null:
  var dimensions=picture.texture.get_size()
  displayed=dimensions*minf(picture.size.x/dimensions.x,picture.size.y/dimensions.y)
 inventory.size=inventory.get_combined_minimum_size()
 inventory.position=(picture.size+displayed)*0.5-inventory.size-Vector2(metrics.padding,metrics.padding)

func remove_deck_copy(id: String,source: String,index: int) -> bool:
 if source=="leader":
  if app.draft.leader!=id:return false
  app.draft.leader=""
 elif source in ["main","side"]:
  if index<0 or index>=app.draft[source].size() or app.draft[source][index]!=id:return false
  app.draft[source].remove_at(index)
 else:return false
 return true

func remove_inspected_card():
 if not remove_deck_copy(app.selected,detail_zone,detail_index):return
 app.dirty=true;app.update_deck_rows();close_details()

func cancel_touch_holds():
 for tile in app.library_rows.values():tile.row.cancel_touch_hold()
 cancel_deck_holds(app.deck_canvas)

func cancel_deck_holds(node: Node):
 if node is DeckCard:node.cancel_touch_hold()
 for child in node.get_children():cancel_deck_holds(child)

func handle_touch(event: InputEvent) -> bool:
 if not (event is InputEventScreenTouch or event is InputEventScreenDrag):return false
 if event is InputEventScreenTouch and event.pressed:
  if finger>=0:cancel_touch_holds();touch_moved=true;return false
  var tile=touch_surfaces.surface_at(app.screen,event.position)
  if tile==null or not tile is DeckCard:return false
  finger=event.index;touch_tile=weakref(tile);touch_origin=event.position;touch_moved=false
  tile.dragged=false;tile.held=false;tile.grab_focus()
  app.android_swipe_scroll.handle(event,app)
 elif event.index!=finger:return false
 else:
  var tile=touch_tile.get_ref() if touch_tile!=null else null
  if event is InputEventScreenDrag:
   if is_instance_valid(tile) and event.position.distance_to(touch_origin)>12:
    touch_moved=true;tile.cancel_touch_hold()
   if app.get_viewport().gui_is_dragging():
    app.android_swipe_scroll.reset();drag_touch_mouse(event.position)
   elif app.android_swipe_scroll.handle(event,app):pass
   elif is_instance_valid(tile) and tile.draggable and touch_moved and overview:
    tile.dragged=true;tile.held=true
    tile.force_drag(tile.drag_data(),tile.drag_picture());drag_touch_mouse(event.position)
  else:
   var activate=not event.canceled and not touch_moved and is_instance_valid(tile) and not tile.is_queued_for_deletion() and not tile.dragged and not tile.held and tile.is_visible_in_tree() and tile.get_global_rect().has_point(event.position)
   if is_instance_valid(tile):tile.cancel_touch_hold()
   var was_dragging=app.get_viewport().gui_is_dragging()
   app.android_swipe_scroll.handle(event,app)
   finger=-1;touch_tile=null
   if was_dragging:
    drag_touch_mouse(event.position)
    var release=InputEventMouseButton.new();release.position=event.position;release.global_position=event.position
    release.button_index=MOUSE_BUTTON_RIGHT if event.canceled else MOUSE_BUTTON_LEFT;release.pressed=event.canceled
    app.get_viewport().push_input(release,true)
   elif activate:
    tile.held=false;tile.clicked.emit(tile.card_id,tile.source_zone,tile.source_index,false)
 app.suppress_swipe_mouse_until=Time.get_ticks_msec()+250
 app.suppress_swipe_mouse_point=event.position
 app.get_viewport().set_input_as_handled()
 return true

func drag_touch_mouse(at: Vector2):
 var motion=InputEventMouseMotion.new();motion.position=at;motion.global_position=at;motion.button_mask=MOUSE_BUTTON_MASK_LEFT
 app.get_viewport().push_input(motion,true)
