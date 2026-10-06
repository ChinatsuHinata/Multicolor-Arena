extends Control
const Client=preload("res://scripts/deck_plaza_client.gd")
const Store=preload("res://scripts/deck_store.gd")
const Art=preload("res://scripts/card_art.gd")
const CardInspection=preload("res://scripts/card_inspection.gd")
# The service returns six posts; Android presents that batch one row at a time.
const SERVER_PAGE_SIZE=6
var app
var mode="list"
var source_deck={}
var posts=[]
var current_post={}
var page_index=0
var pages=1
var total_posts=0
var page_offset=0
var requested_offset=0
var compact_tiles=false
var tile_layout_pending=false
var busy=false
var client
var mine=false
var filters={"leader":"","tag":"","color_text":"","colors":[]}
var search_fields={}
var color_filters_open=false
var color_filters: VBoxContainer
var color_filter_button: Button
var mine_button: Button
var back_button: Button
var detail_panes: HBoxContainer
var detail_info: PanelContainer
var detail_description_scroll: ScrollContainer
var detail_card_panel: VBoxContainer
var detail_deck={}
var card_overlay: Control
var card_popup: PanelContainer
var edit_after_detail=false
var heading: Label
var notice: Label
var body: VBoxContainer
var grid: GridContainer
var list_scroll: ScrollContainer
var title_input: LineEdit
var description_input: TextEdit
var tags_input: LineEdit
var upload_button: Button
var refresh_button: Button
var submit_button: Button
var previous_button: Button
var next_button: Button
var page_label: Label

func expand(control: Control,vertical: bool=false):
 control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 if vertical:control.size_flags_vertical=Control.SIZE_EXPAND_FILL

func text(parent: Node,value: String,font: int=0,color: Color=Color("#e8edf0")) -> Label:
 var result=Label.new();result.text=value;parent.add_child(result)
 result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;expand(result)
 result.add_theme_color_override("font_color",color)
 if font>0:result.add_theme_font_size_override("font_size",font)
 return result

func action(parent: Node,caption: String,callback: Callable,accent: bool=false) -> Button:
 var result=app.button(parent,caption,Rect2(),callback,accent)
 app.ui_metrics.button(result)
 return result

func _ready():
 name="DeckPlaza";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var margin=MarginContainer.new();add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,int(app.ui_metrics.padding))
 var root=VBoxContainer.new();margin.add_child(root)
 root.add_theme_constant_override("separation",int(app.ui_metrics.gap))
 var toolbar=HBoxContainer.new();root.add_child(toolbar)
 var title_row=HBoxContainer.new();toolbar.add_child(title_row);expand(title_row)
 heading=text(title_row,"套牌广场",app.ui_metrics.title,app.GOLD)
 if app.is_android:
  heading.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;heading.autowrap_mode=TextServer.AUTOWRAP_OFF
  notice=text(title_row,"",app.ui_metrics.small,app.MUTED)
  notice.autowrap_mode=TextServer.AUTOWRAP_OFF;notice.clip_text=true
 mine_button=action(toolbar,"我的上传",toggle_mine);mine_button.name="PlazaMineButton"
 upload_button=action(toolbar,"上传套牌" if app.is_android else "上传当前套牌",app.upload_current_deck);upload_button.name="PlazaUploadButton"
 refresh_button=action(toolbar,"刷新",func():fetch_list(page_index,page_offset))
 back_button=action(toolbar,"返回" if app.is_android else "返回编辑器",app.editor);back_button.name="PlazaBackButton"
 if not app.is_android:notice=text(root,"")
 notice.name="PlazaNotice"
 body=VBoxContainer.new();root.add_child(body);expand(body,true)
 body.resized.connect(queue_tile_layout)
 resized.connect(queue_tile_layout)
 mine=app.deck_plaza_browser.get("mine",false)
 filters=app.deck_plaza_browser.get("filters",filters).duplicate(true)
 if mode in ["upload","edit"]:show_upload()
 elif mode=="detail":show_detail()
 else:show_list();call_deferred("fetch_list",0)

func clear_body():
 close_card_details()
 app.free_children(body)
 grid=null;list_scroll=null;submit_button=null;previous_button=null;next_button=null;page_label=null
 title_input=null;description_input=null;tags_input=null
 search_fields={}
 color_filters=null;color_filter_button=null
 detail_panes=null;detail_info=null
 detail_description_scroll=null;detail_card_panel=null;detail_deck={}
 back_button.visible=mode!="detail"
 upload_button.visible=mode=="list";refresh_button.visible=mode=="list"
 mine_button.visible=mode=="list";mine_button.text="全部套牌" if mine else "我的上传"

func show_list():
 mode="list";clear_body();heading.text="我的上传" if mine else "套牌广场"
 build_search()
 var scroll=ScrollContainer.new();scroll.name="PlazaScroll";body.add_child(scroll);expand(scroll,true)
 list_scroll=scroll
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 if app.is_android:scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 scroll.resized.connect(queue_tile_layout)
 grid=GridContainer.new();grid.name="PlazaGrid";scroll.add_child(grid);expand(grid)
 grid.columns=tile_columns()
 if app.is_android:page_offset=int(page_offset/grid.columns)*grid.columns
 if app.is_android:expand(grid,true)
 grid.add_theme_constant_override("h_separation",int(app.ui_metrics.gap))
 grid.add_theme_constant_override("v_separation",int(app.ui_metrics.gap))
 render_tiles()
 var pagination=HBoxContainer.new();body.add_child(pagination)
 pagination.name="PlazaPagination"
 previous_button=action(pagination,"上一页",func():turn_page(-1))
 page_label=text(pagination,"第 %d / %d 页" % [page_index+1,pages]);page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 next_button=action(pagination,"下一页",func():turn_page(1))
 relayout();set_busy(busy)

func build_search():
 var row=HBoxContainer.new();row.name="PlazaSearch";body.add_child(row)
 for entry in [["leader","自机（名称 / 别名）","例如：灵梦"],["color_text","套牌颜色（文字命令）","例如：红蓝"],["tag","标签（逗号分隔，同时满足）","例如：灵梦，速攻"]]:
  var parent: Node=row
  if not app.is_android:
   var column=VBoxContainer.new();row.add_child(column);expand(column)
   text(column,entry[1],app.ui_metrics.small,app.MUTED);parent=column
  var field=LineEdit.new();parent.add_child(field);field.name="PlazaSearch_"+entry[0];expand(field)
  field.custom_minimum_size.y=app.ui_metrics.hit;field.max_length=30 if entry[0]=="color_text" else 60
  field.placeholder_text={"leader":"自机 / 别名","color_text":"颜色：红蓝","tag":"标签：灵梦，速攻"}[entry[0]] if app.is_android else entry[2]
  field.tooltip_text=entry[1]+" · "+entry[2];field.text=str(filters.get(entry[0],""));search_fields[entry[0]]=field
  field.text_submitted.connect(func(_value):apply_search())
 var search=action(row,"搜索",apply_search,true);search.name="PlazaSearchButton";search.size_flags_vertical=Control.SIZE_SHRINK_END
 var clear=action(row,"清除",reset_search);clear.name="PlazaClearSearch";clear.size_flags_vertical=Control.SIZE_SHRINK_END
 if app.is_android:
  color_filter_button=action(row,"颜色筛选",toggle_color_filters);color_filter_button.name="PlazaFilterToggle"
  color_filter_button.toggle_mode=true
 color_filters=VBoxContainer.new();color_filters.name="PlazaAdvancedFilters";body.add_child(color_filters)
 var swatches=HBoxContainer.new();swatches.name="PlazaColorFilters";color_filters.add_child(swatches)
 var color_caption=text(swatches,"包含颜色：",app.ui_metrics.small,app.MUTED)
 color_caption.autowrap_mode=TextServer.AUTOWRAP_OFF
 color_caption.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;color_caption.size_flags_vertical=Control.SIZE_SHRINK_CENTER
 var inks=[Color("#344553"),Color("#a83035"),Color("#337aa7"),Color("#39794d"),Color("#ac963b"),Color("#383a42")]
 var colors=["全部","红","蓝","绿","黄","黑"]
 for index in range(colors.size()):
  var color=colors[index]
  var b=action(swatches,color,func():toggle_color(color));b.name="PlazaColor_"+color
  b.size_flags_vertical=Control.SIZE_SHRINK_CENTER
  b.toggle_mode=true;b.set_pressed_no_signal(filters.colors.is_empty() if color=="全部" else color in filters.colors)
  b.add_theme_stylebox_override("normal",app.style(inks[index]))
  b.add_theme_stylebox_override("pressed",app.style(inks[index].lightened(0.18),app.GOLD))
 text(color_filters,"色块和文字均筛选包含全部指定颜色的套牌；多个标签用逗号分隔。",app.ui_metrics.small,app.MUTED)
 update_color_filters()

func toggle_color_filters():
 color_filters_open=not color_filters_open;update_color_filters()

func update_color_filters():
 color_filters.visible=not app.is_android or color_filters_open
 if is_instance_valid(color_filter_button):
  color_filter_button.text="颜色筛选"+("（%d）" % filters.colors.size() if not filters.colors.is_empty() else "")
  color_filter_button.set_pressed_no_signal(color_filters_open)
  app.ui_metrics.button(color_filter_button)

func capture_search():
 for key in search_fields:
  if is_instance_valid(search_fields[key]):filters[key]=search_fields[key].text.strip_edges()

func apply_search():
 if busy:return
 capture_search();fetch_list(0)

func reset_search():
 if busy:return
 filters={"leader":"","tag":"","color_text":"","colors":[]};show_list();fetch_list(0)

func toggle_color(color: String):
 if busy:return
 capture_search()
 if color=="全部":filters.colors=[]
 elif color in filters.colors:filters.colors.erase(color)
 else:filters.colors.append(color)
 show_list();fetch_list(0)

func toggle_mine():
 if busy:return
 capture_search();mine=not mine;posts=[];page_index=0;show_list();fetch_list(0)

func decoded(post: Dictionary) -> Dictionary:
 return Store.decode(str(post.get("deck_code",""))).get("deck",{})

func picture(parent: Node,deck: Dictionary,height: float) -> TextureRect:
 var result=TextureRect.new();parent.add_child(result)
 result.custom_minimum_size=Vector2(0,height);expand(result)
 result.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 result.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 result.mouse_filter=Control.MOUSE_FILTER_IGNORE
 if not deck.is_empty():result.texture=app.texture(deck.leader,Art.selected(deck,deck.leader,Store.CARDS))
 result.name="PlazaLeaderArt"
 return result

func make_tile(post: Dictionary):
 var tile=PanelContainer.new();grid.add_child(tile);expand(tile)
 tile.name="PlazaTile"+str(post.id)
 if not app.is_android:tile.custom_minimum_size.x=280
 else:expand(tile,true)
 var panel_style=app.ui_metrics.panel_style()
 if app.is_android and compact_tiles:panel_style.set_content_margin_all(maxf(8,app.ui_metrics.padding*0.5))
 tile.add_theme_stylebox_override("panel",panel_style)
 tile.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 var deck=decoded(post)
 var column=VBoxContainer.new()
 if app.is_android and compact_tiles:
  var row=HBoxContainer.new();tile.add_child(row);row.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var art=picture(row,deck,0);expand(art,true);art.size_flags_stretch_ratio=0.7
  row.add_child(column);expand(column);column.size_flags_vertical=Control.SIZE_SHRINK_CENTER
 else:
  tile.add_child(column)
  var art=picture(column,deck,0 if app.is_android else 220)
  if app.is_android:expand(art,true)
 column.mouse_filter=Control.MOUSE_FILTER_IGNORE
 if app.is_android:column.add_theme_constant_override("separation",4 if compact_tiles else maxi(4,int(app.ui_metrics.gap*0.5)))
 tile_text(column,str(post.title),app.ui_metrics.body+4,app.GOLD)
 tile_text(column,"上传："+str(post.get("nickname",post.get("username",""))),app.ui_metrics.small,app.MUTED)
 var tags="，".join(post.get("tags",[]))
 var colors=" / ".join(post.get("colors",[])) if not post.get("colors",[]).is_empty() else "无色"
 if app.is_android and compact_tiles:
  tile_text(column,"颜色："+colors+(" · 标签："+tags if not tags.is_empty() else ""),app.ui_metrics.small,app.MUTED)
 else:
  if not app.is_android or not tags.is_empty():tile_text(column,tags,app.ui_metrics.small,app.MUTED)
  tile_text(column,"套牌颜色："+colors,app.ui_metrics.small,app.MUTED)
 if deck.is_empty() and not app.is_android:tile_text(column,"此套牌需要更新客户端后查看",app.ui_metrics.small,app.MUTED)
 var open=action(column,"查看套牌",func():fetch_detail(int(post.id)));open.name="PlazaOpen"+str(post.id)
 # Owner actions remain available in the detail, keeping Android tiles one row high.
 if not app.is_android and mine and post.get("owned",false):
  var controls=HBoxContainer.new();column.add_child(controls)
  expand(action(controls,"进入编辑器",func():fetch_for_edit(int(post.id))))
  expand(action(controls,"删除",func():delete_post(post)))
 var tap={"pressed":false,"origin":Vector2.ZERO}
 tile.gui_input.connect(func(event):
  if not event is InputEventMouseButton or event.button_index!=MOUSE_BUTTON_LEFT or busy:return
  if not app.is_android:
   if event.pressed:fetch_detail(int(post.id))
  elif event.pressed:
   tap.pressed=true;tap.origin=event.position
  else:
   var open_on_release=tap.pressed and event.position.distance_to(tap.origin)<=12.0
   tap.pressed=false
   if open_on_release:fetch_detail(int(post.id)))

func tile_text(parent: Node,value: String,font: int,color: Color) -> Label:
 var label=text(parent,value,font,color);label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 if app.is_android:
  label.autowrap_mode=TextServer.AUTOWRAP_OFF;label.clip_text=true
  label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;label.tooltip_text=value
 return label

func render_tiles():
 app.free_children(grid)
 if posts.is_empty():text(grid,"没有符合条件的套牌。试试清除筛选或上传套牌。",app.ui_metrics.body,app.MUTED)
 var visible_posts=posts.slice(page_offset,mini(posts.size(),page_offset+grid.columns)) if app.is_android else posts
 for post in visible_posts:make_tile(post)

func visible_page() -> int:
 return int((page_index*SERVER_PAGE_SIZE+page_offset)/maxi(1,grid.columns)) if app.is_android else page_index

func visible_pages() -> int:
 return maxi(1,ceili(float(total_posts)/maxi(1,grid.columns))) if app.is_android else pages

func turn_page(direction: int):
 if busy:return
 if not app.is_android:fetch_list(page_index+direction);return
 if visible_page()+direction<0 or visible_page()+direction>=visible_pages():return
 var offset=page_offset+direction*grid.columns
 if offset>=0 and offset<posts.size():
  page_offset=offset;render_tiles();set_busy(false)
 else:fetch_list(page_index+direction,0 if direction>0 else SERVER_PAGE_SIZE-grid.columns)

func relayout():
 queue_tile_layout()

func tile_columns() -> int:
 var minimum=maxf(280,app.ui_metrics.hit*4.2)
 var available=body.size.x-(0 if app.is_android else 24)
 return maxi(1,mini(3,int((available+app.ui_metrics.gap)/(minimum+app.ui_metrics.gap))))

func queue_tile_layout():
 if tile_layout_pending:return
 tile_layout_pending=true;call_deferred("layout_tiles")

func layout_tiles():
 tile_layout_pending=false
 if mode=="detail":
  if is_instance_valid(detail_info):detail_info.custom_minimum_size.x=clampf(body.size.x*0.27,280,440)
  fit_card_popup()
  return
 if not is_instance_valid(grid):return
 var columns=tile_columns()
 var row_height=size.y-app.ui_metrics.padding*2-app.ui_metrics.hit*3-app.ui_metrics.gap*3
 if is_instance_valid(color_filters) and color_filters.visible:row_height-=color_filters.get_combined_minimum_size().y+app.ui_metrics.gap
 var compact=app.is_android and row_height<app.ui_metrics.hit*2.4+app.ui_metrics.small*5+app.ui_metrics.padding*2+app.ui_metrics.gap*3
 if grid.columns!=columns or compact_tiles!=compact:
  grid.columns=columns;compact_tiles=compact
  page_offset=int(mini(page_offset,maxi(0,posts.size()-1))/columns)*columns
  render_tiles()
 set_busy(busy)

static func parse_tags(value: String) -> Dictionary:
 if value.contains(","):return {"error":"请用中文逗号（，）分隔标签"}
 var tags=[]
 for part in value.split("，",false):
  var tag=part.strip_edges()
  if tag.is_empty():continue
  if tag.length()>20:return {"error":"每个标签最多 20 个字符"}
  tags.append(tag)
 if tags.size()>10:return {"error":"标签最多十个，请减少标签后再上传"}
 return {"tags":tags}

func show_upload():
 var updating=mode=="edit"
 clear_body();heading.text="更新上传套牌" if updating else "上传套牌"
 var scroll=ScrollContainer.new();body.add_child(scroll);expand(scroll,true)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var form=VBoxContainer.new();scroll.add_child(form);expand(form)
 var saved=app.deck_plaza_form if app.deck_plaza_form.get("deck_id","")==source_deck.get("id","") else {"title":current_post.get("title",source_deck.get("name","")),"description":current_post.get("description",""),"tags":"，".join(current_post.get("tags",[]))}
 if updating:text(form,"将更新自己上传的「%s」；卡牌与异画来自刚刚编辑的套牌。" % current_post.get("title",""),app.ui_metrics.body,app.GOLD)
 text(form,"标题（最多 40 字）",app.ui_metrics.body,app.GOLD)
 title_input=LineEdit.new();title_input.name="PlazaTitle";form.add_child(title_input)
 title_input.max_length=40;title_input.custom_minimum_size.y=app.ui_metrics.hit
 title_input.text=saved.get("title",source_deck.get("name",""));title_input.placeholder_text="为这副套牌起个标题"
 text(form,"描述（最多 2000 字）",app.ui_metrics.body,app.GOLD)
 description_input=TextEdit.new();description_input.name="PlazaDescription";form.add_child(description_input)
 description_input.custom_minimum_size.y=maxf(160,app.ui_metrics.hit*2.5)
 description_input.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;description_input.text=saved.get("description","")
 description_input.placeholder_text="介绍思路、打法或适用场景"
 text(form,"标签（最多十个，用中文逗号 ， 分隔；每个最多 20 字）",app.ui_metrics.body,app.GOLD)
 tags_input=LineEdit.new();tags_input.name="PlazaTags";form.add_child(tags_input)
 tags_input.text=saved.get("tags","");tags_input.placeholder_text="例如：灵梦，速攻，官限";tags_input.custom_minimum_size.y=app.ui_metrics.hit
 text(form,"上传玩家："+app.account_nickname+"（"+app.account_name+"）",app.ui_metrics.body,app.MUTED)
 submit_button=action(form,"保存套牌更新" if updating else "上传到套牌广场",submit_upload,true);submit_button.name="PlazaSubmit"
 tags_input.text_changed.connect(func(value):
  var parsed=parse_tags(value)
  notice.text=parsed.get("error","已填写 %d / 10 个标签" % parsed.get("tags",[]).size()))
 notice.text="确认编辑后的套牌，再修改标题、描述和标签。" if updating else "为当前套牌填写标题、描述和标签。"

func remember_form():
 if mode in ["upload","edit"] and is_instance_valid(title_input):
  app.deck_plaza_form={"deck_id":source_deck.get("id",""),"title":title_input.text,"description":description_input.text,"tags":tags_input.text}

func submit_upload():
 if busy:return
 var title=title_input.text.strip_edges()
 if title.is_empty():notice.text="请输入套牌标题";return
 if description_input.text.length()>2000:notice.text="描述最多 2000 个字符";return
 var parsed=parse_tags(tags_input.text)
 if parsed.has("error"):notice.text=parsed.error;return
 var deck=source_deck.duplicate(true);deck.name=title
 var error=Store.validate(deck,false,str(deck.get("rule_set",Store.RuleSet.OFFICIAL)))
 if not error.is_empty():notice.text=error;return
 remember_form()
 var payload={"action":"edit" if mode=="edit" else "upload","title":title,"description":description_input.text,"tags":parsed.tags,"deck_code":Store.encode(deck)}
 if mode=="edit":payload.id=int(current_post.id)
 send(payload,"正在保存套牌更新…" if mode=="edit" else "正在上传套牌…")

func fetch_list(index: int,offset: int=0):
 if busy:return
 requested_offset=offset
 app.deck_plaza_browser={"mine":mine,"filters":filters.duplicate(true)}
 var payload=filters.duplicate(true);payload.merge({"action":"list","page":maxi(0,index),"mine":mine},true)
 send(payload,"正在加载我的上传…" if mine else "正在加载套牌广场…")

func fetch_detail(post_id: int):
 if busy:return
 send({"action":"detail","id":post_id},"正在加载套牌详情…")

func fetch_for_edit(post_id: int):
 if busy:return
 edit_after_detail=true;fetch_detail(post_id)

func delete_post(post: Dictionary):
 if busy or not post.get("owned",false):return
 app.confirm_action("删除自己上传的「%s」？" % post.title,func():
  if is_instance_valid(self) and not busy:send({"action":"delete","id":int(post.id)},"正在删除套牌…"))

func send(payload: Dictionary,message: String):
 set_busy(true);notice.text=message
 client=Client.new();add_child(client);client.server_url=app.deck_plaza_server_url
 client.finished.connect(func(answer):receive(answer,str(payload.action)))
 client.request(payload,app.account_token)

func receive(answer: Dictionary,operation: String):
 if is_instance_valid(client):client.queue_free();client=null
 set_busy(false)
 if answer.get("auth_required",false):
  remember_form();app.call_deferred("deck_login_expired","upload" if mode in ["upload","edit"] else "list",str(answer.get("message","请重新登录")));return
 if not answer.get("ok",false):edit_after_detail=false;notice.text=str(answer.get("message","操作失败，请重试"));return
 match operation:
  "upload":
   app.deck_plaza_form={};notice.text="套牌已上传到广场。";mode="list";show_list();fetch_list(0)
  "edit":
   app.cloud_edit_post=answer.get("deck",app.cloud_edit_post)
   app.deck_plaza_form={};mine=true;mode="list";show_list();fetch_list(0)
  "delete":
   if int(app.cloud_edit_post.get("id",0))==int(answer.get("id",0)):app.cloud_edit_post={}
   mode="list";show_list();fetch_list(page_index,page_offset)
  "list":
   posts=answer.get("decks",[]);page_index=int(answer.get("page",0));pages=int(answer.get("pages",1))
   total_posts=int(answer.get("total",posts.size()));page_offset=mini(requested_offset,maxi(0,posts.size()-1))
   show_list();notice.text="共 %d 副套牌 · 点击查看详情" % int(answer.get("total",posts.size()))
  "detail":
   current_post=answer.get("deck",{})
   if edit_after_detail:
    edit_after_detail=false;app.edit_uploaded_deck(current_post)
   else:show_detail()

func set_busy(value: bool):
 busy=value
 for b in [upload_button,refresh_button,submit_button,mine_button]:
  if is_instance_valid(b):b.disabled=value
 if is_instance_valid(grid) and is_instance_valid(page_label):
  page_label.text="第 %d / %d 页" % [visible_page()+1,visible_pages()]
  previous_button.disabled=value or visible_page()<=0
  next_button.disabled=value or visible_page()>=visible_pages()-1

func show_detail():
 mode="detail";clear_body();heading.text="套牌详情";notice.text=""
 detail_panes=HBoxContainer.new();detail_panes.name="PlazaDetailPanes";body.add_child(detail_panes);expand(detail_panes,true)
 detail_panes.add_theme_constant_override("separation",int(app.ui_metrics.gap))
 detail_info=PanelContainer.new();detail_info.name="PlazaDetailInfo";detail_panes.add_child(detail_info)
 detail_info.add_theme_stylebox_override("panel",app.ui_metrics.panel_style())
 detail_info.custom_minimum_size.x=clampf(app.screen.size.x*0.27,280,440)
 var info=VBoxContainer.new();detail_info.add_child(info)
 info.add_theme_constant_override("separation",int(app.ui_metrics.gap))
 var scroll=ScrollContainer.new();scroll.name="PlazaDescriptionScroll";info.add_child(scroll);expand(scroll,true)
 detail_description_scroll=scroll
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var column=VBoxContainer.new();scroll.add_child(column);expand(column)
 column.add_theme_constant_override("separation",int(app.ui_metrics.gap))
 var deck=decoded(current_post)
 detail_deck=deck
 text(column,str(current_post.get("title","")),app.ui_metrics.title,app.GOLD)
 text(column,"上传玩家：%s（%s）" % [current_post.get("nickname",""),current_post.get("username","")],app.ui_metrics.body,app.MUTED)
 text(column,"标签："+("，".join(current_post.get("tags",[])) if not current_post.get("tags",[]).is_empty() else "无"),app.ui_metrics.body,app.GOLD).name="PlazaDetailTags"
 text(column,"套牌颜色："+(" / ".join(current_post.get("colors",[])) if not current_post.get("colors",[]).is_empty() else "无色"),app.ui_metrics.body,app.MUTED)
 text(column,str(current_post.get("description","")) if not str(current_post.get("description","")).is_empty() else "暂无描述",app.ui_metrics.body).name="PlazaDetailDescription"
 if not deck.is_empty():text(column,"主卡组 %d 张 · 副卡组 %d 张 · %s" % [deck.main.size(),deck.side.size(),Store.RuleSet.label_for(str(deck.rule_set))],app.ui_metrics.body,app.MUTED)
 detail_card_panel=VBoxContainer.new();detail_card_panel.name="PlazaCardInspection";info.add_child(detail_card_panel);expand(detail_card_panel,true)
 detail_card_panel.add_theme_constant_override("separation",int(app.ui_metrics.gap));detail_card_panel.hide()
 var download=action(info,"下载套牌到本地",download_deck,true);download.name="PlazaDownload";download.disabled=deck.is_empty()
 if current_post.get("owned",false):
  var owner_actions=VBoxContainer.new();info.add_child(owner_actions)
  var edit=action(owner_actions,"进入编辑器修改",func():app.edit_uploaded_deck(current_post));edit.name="PlazaEdit";edit.disabled=deck.is_empty();expand(edit)
  expand(action(owner_actions,"删除上传套牌",func():delete_post(current_post)))
 action(info,"返回广场",func():show_list();notice.text="点击套牌查看详情").name="PlazaReturnToList"
 var overview_panel=PanelContainer.new();overview_panel.name="PlazaDeckPanel";detail_panes.add_child(overview_panel);expand(overview_panel,true)
 overview_panel.add_theme_stylebox_override("panel",app.ui_metrics.panel_style())
 if not deck.is_empty():
  var overview=preload("res://scripts/deck_plaza_overview.gd").new();overview.app=app;overview.deck=deck
  overview.card_inspected.connect(show_card_details)
  overview_panel.add_child(overview);expand(overview,true)
 else:text(overview_panel,"此套牌需要更新客户端后查看",app.ui_metrics.body,app.MUTED)
 queue_tile_layout()
 if deck.is_empty():notice.text="此套牌包含当前客户端无法识别的卡牌或异画，请更新后再下载。"

func inspection_art(parent: Node,id: String) -> TextureRect:
 var picture=CardInspection.artwork(app,parent,id,detail_deck);picture.name="PlazaInspectionArt"
 return picture

func inspection_text(parent: Node,id: String,width: float):
 var scroll=CardInspection.rules(app,parent,id,width);scroll.name="PlazaCardTextScroll"
 scroll.find_child("CardInspectionRules",true,false).name="PlazaCardRules"

func inspection_header(parent: Node):
 var header=HBoxContainer.new();parent.add_child(header)
 var title=text(header,"卡牌详情",app.ui_metrics.body,app.GOLD)
 title.autowrap_mode=TextServer.AUTOWRAP_OFF;title.clip_text=true
 action(header,"关闭",close_card_details).name="PlazaCloseCardDetails"

func show_card_details(id: String):
 if mode!="detail" or not Store.CARDS.has(id):return
 close_card_details()
 if not app.is_android:
  detail_description_scroll.hide();detail_card_panel.show()
  inspection_header(detail_card_panel)
  var picture=inspection_art(detail_card_panel,id)
  picture.size_flags_vertical=Control.SIZE_FILL
  var width=maxf(100,detail_info.size.x-app.ui_metrics.padding*2)
  picture.custom_minimum_size.y=minf(app.screen.size.y*0.3,width*(0.72 if app.landscape_card(id) else 1.397))
  inspection_text(detail_card_panel,id,width-16)
  return
 card_overlay=Control.new();card_overlay.name="PlazaCardOverlay";add_child(card_overlay)
 card_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var shade=ColorRect.new();shade.color=Color(0,0,0,0.78);card_overlay.add_child(shade)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 shade.gui_input.connect(func(event):
  if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:close_card_details())
 card_popup=PanelContainer.new();card_popup.name="PlazaCardPopup";card_overlay.add_child(card_popup)
 card_popup.add_theme_stylebox_override("panel",app.ui_metrics.panel_style())
 fit_card_popup()
 var column=VBoxContainer.new();card_popup.add_child(column)
 column.add_theme_constant_override("separation",int(app.ui_metrics.gap))
 inspection_header(column)
 var panes=HBoxContainer.new();column.add_child(panes);expand(panes,true)
 panes.add_theme_constant_override("separation",int(app.ui_metrics.gap))
 var words=VBoxContainer.new();panes.add_child(words);expand(words,true)
 inspection_text(words,id,maxf(100,(card_popup.size.x-app.ui_metrics.padding*2-app.ui_metrics.gap)*0.52-16))
 var picture=inspection_art(panes,id);picture.size_flags_stretch_ratio=0.92

func fit_card_popup():
 if not is_instance_valid(card_popup):return
 var padding=app.ui_metrics.padding
 card_popup.size=Vector2(minf(1200,size.x-padding*2),size.y-padding*2)
 card_popup.position=(size-card_popup.size)*0.5

func close_card_details():
 if is_instance_valid(card_overlay):
  remove_child(card_overlay);card_overlay.queue_free()
 card_overlay=null;card_popup=null
 if is_instance_valid(detail_card_panel):
  detail_card_panel.hide();app.free_children(detail_card_panel)
 if is_instance_valid(detail_description_scroll):detail_description_scroll.show()

func download_deck():
 var deck=decoded(current_post)
 if deck.is_empty():notice.text="套牌代码无效，无法下载";return
 deck.name=str(current_post.title)
 var error=Store.save_file(deck)
 if not error.is_empty():notice.text=error;return
 app.reload_decks()
 notice.text="已下载「%s」到本地，在编辑器的卡组列表中选择即可。" % deck.name

func _exit_tree():remember_form()
