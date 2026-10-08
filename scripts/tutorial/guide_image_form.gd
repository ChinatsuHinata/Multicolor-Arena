extends HBoxContainer
## Choose exact card art, order illustrations, and apply one private media draft.
const Images=preload("res://scripts/tutorial/guide_image.gd")
const Art=preload("res://scripts/card_art.gd")
const Selector=preload("res://scripts/card_name_search_panel.gd")
var editor
var original: Dictionary={}
var draft: Dictionary={}
var initial: Dictionary={}
var selected_index=-1
var selector
var art_choice: OptionButton
var art_ids: Array=[]
var selected_art=""
var orientation: OptionButton
var image_list: ItemList
var preview
var preview_scroll: ScrollContainer
var columns: SpinBox
var error_label: Label
var add_card: Button
var replace_card: Button
var replace_custom: Button
var move_up: Button
var move_down: Button
var remove: Button
var add_custom: Button

func configure(owner_editor,source: Dictionary):
 editor=owner_editor;original=source.duplicate(true);draft=Images.normalize(source);initial=draft.duplicate(true)

func _ready():
 name="TutorialGuideImageForm";size_flags_vertical=Control.SIZE_EXPAND_FILL
 var left=VBoxContainer.new();add_child(left);left.custom_minimum_size.x=300;left.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 editor.text(left,"已选配图 · 按列表顺序显示")
 image_list=ItemList.new();image_list.name="TutorialGuideImageList";left.add_child(image_list);image_list.size_flags_vertical=Control.SIZE_EXPAND_FILL
 image_list.custom_minimum_size.y=80;image_list.item_selected.connect(select_item)
 var tools=HBoxContainer.new();left.add_child(tools)
 move_up=editor.action(tools,"上移",func():move_item(-1));move_up.name="MoveGuideImageUp"
 move_down=editor.action(tools,"下移",func():move_item(1));move_down.name="MoveGuideImageDown"
 remove=editor.action(tools,"移除选中",remove_item);remove.name="RemoveSelectedGuideImage"
 var custom=HBoxContainer.new();left.add_child(custom)
 add_custom=editor.action(custom,"添加自定义图",func():pick_custom(false));add_custom.name="AddCustomGuideImage"
 replace_custom=editor.action(custom,"更换为自定义图",func():pick_custom(true));replace_custom.name="ReplaceCustomGuideImage"
 var layouts=HBoxContainer.new();left.add_child(layouts)
 editor.option(layouts,["row","column","grid"],draft.layout,func(value):draft.layout=value;refresh_preview(),["横向并排","纵向排列","网格排列"]).name="TutorialGuideImageLayout"
 columns=SpinBox.new();columns.name="TutorialGuideImageColumns";layouts.add_child(columns);columns.min_value=1;columns.max_value=4;columns.step=1;columns.value=draft.columns;columns.custom_minimum_size.x=100;columns.suffix="列"
 columns.value_changed.connect(func(value):draft.columns=int(value);refresh_preview())
 preview_scroll=ScrollContainer.new();left.add_child(preview_scroll);preview_scroll.custom_minimum_size.y=80;preview_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 preview=preload("res://scripts/tutorial/guide_image_gallery.gd").new();preview.name="GuideImageDraftPreview";preview_scroll.add_child(preview);preview.configure(editor,editor.host);preview.height_limit=72
 var hint=editor.text(left,"横卡、竖卡保留原方向；点击预览可放大。\n最多 %d 张，支持卡图与自定义图混排。" % Images.MAX_ITEMS);hint.add_theme_font_size_override("font_size",16)
 error_label=editor.text(left,"");error_label.name="TutorialGuideImageError";error_label.add_theme_color_override("font_color",Color("ff8d8d"));error_label.hide()
 var right=VBoxContainer.new();add_child(right);right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;right.size_flags_stretch_ratio=1.8
 orientation=editor.option(right,["all","landscape","portrait"],"all",func(_value):refresh_choices(),["全部卡图（横卡和竖卡）","只看横卡","只看竖卡"]);orientation.name="TutorialGuideCardOrientation"
 selector=Selector.new();selector.name="TutorialGuideCardSearch";selector.layout_metrics=editor.host.ui_metrics;right.add_child(selector);selector.size_flags_vertical=Control.SIZE_EXPAND_FILL;selector.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 selector.selected.connect(func(_entry):refresh_art_options())
 art_choice=OptionButton.new();art_choice.name="TutorialGuideCardArt";right.add_child(art_choice);art_choice.custom_minimum_size.y=36;art_choice.clip_text=true;art_choice.fit_to_longest_item=false
 art_choice.item_selected.connect(func(index):selected_art=art_ids[index];art_choice.tooltip_text=art_choice.get_item_text(index);selector.update_preview())
 var actions=HBoxContainer.new();right.add_child(actions)
 add_card=editor.action(actions,"加入这张卡图",func():choose_card(false));add_card.name="AddTutorialGuideCard"
 replace_card=editor.action(actions,"替换选中配图",func():choose_card(true));replace_card.name="ReplaceTutorialGuideCard"
 refresh_choices();refresh_items()

func value() -> Dictionary:
 if draft==initial:return original.duplicate(true)
 return draft.duplicate(true) if not draft.items.is_empty() else {}

func refresh_choices():
 var choices=[]
 for id in editor.host.Store.CARDS:
  var landscape=editor.host.landscape_card(id)
  if orientation.selected==1 and not landscape:continue
  if orientation.selected==2 and landscape:continue
  choices.append({"id":id})
 selector.configure(editor.host.Store.CARDS,choices,card_texture);selected_art="";refresh_art_options()

func card_texture(id: String) -> Texture2D:
 return editor.host.preview_texture(id,selected_art if selector.selected_entry.get("id")==id else "")

func refresh_art_options():
 selected_art="";art_ids=[];art_choice.clear()
 var id=str(selector.selected_entry.get("id",""))
 if not id.is_empty():
  art_ids.append("");art_choice.add_item("卡图版本：默认卡面 · #"+id)
  for variant in Art.options(id,editor.host.Store.CARDS):
   if variant.id==id:continue
   art_ids.append(variant.id);art_choice.add_item("卡图版本："+variant.label+" · "+variant.id)
 else:art_choice.add_item("选择卡牌后指定默认卡面或异画")
 art_choice.disabled=art_ids.is_empty();refresh_buttons()

func select_item(index: int):
 if index<0 or index>=draft.items.size():return
 selected_index=index
 var item=draft.items[index]
 if item.has("card_id"):
  orientation.select(0);refresh_choices();selector.select_id(item.card_id)
  var version=art_ids.find(item.get("art_id",""));art_choice.select(maxi(0,version));selected_art=item.get("art_id","");selector.update_preview()
 refresh_buttons()

func choose_card(replacing: bool):
 if selector.selected_entry.is_empty():return
 var item={"card_id":str(selector.selected_entry.id)}
 if not selected_art.is_empty():item.art_id=selected_art
 if Images.item_texture(item,editor.host)==null:show_error("这张卡图暂时无法读取，请选择其他卡图。");return
 put_item(item,replacing)

func put_item(item: Dictionary,replacing: bool):
 if replacing:
  if selected_index<0 or selected_index>=draft.items.size():return
  draft.items[selected_index]=item
 else:
  if draft.items.size()>=Images.MAX_ITEMS:show_error("最多添加 %d 张配图。" % Images.MAX_ITEMS);return
  draft.items.append(item);selected_index=draft.items.size()-1
 error_label.hide();refresh_items()

func pick_custom(replacing: bool):
 var target=selected_index
 if replacing and target<0:return
 var dialog=FileDialog.new();dialog.name="TutorialGuideImagePicker";editor.add_child(dialog)
 dialog.access=FileDialog.ACCESS_FILESYSTEM;dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE
 dialog.title="更换选中配图为自定义图片" if replacing else "添加自定义配图"
 dialog.filters=PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; 图片（PNG、JPG、WebP）"])
 dialog.file_selected.connect(func(path):
  var result=Images.import_file(path)
  if not result.error.is_empty():show_error(result.error)
  else:
   if replacing:selected_index=target
   result.data.name=path.get_file();put_item(result.data,replacing)
  dialog.queue_free())
 dialog.canceled.connect(dialog.queue_free);dialog.popup_centered_ratio(0.8)

func move_item(offset: int):
 var target=selected_index+offset
 if selected_index<0 or target<0 or target>=draft.items.size():return
 var item=draft.items.pop_at(selected_index);draft.items.insert(target,item);selected_index=target;refresh_items()

func remove_item():
 if selected_index<0 or selected_index>=draft.items.size():return
 draft.items.remove_at(selected_index);selected_index=-1;refresh_items()

func refresh_items():
 image_list.clear()
 for i in range(draft.items.size()):
  var caption=Images.caption(draft.items[i],editor.host.Store.CARDS)
  image_list.add_item("%d. %s" % [i+1,caption]);image_list.set_item_tooltip(i,caption)
 if selected_index>=0 and selected_index<draft.items.size():image_list.select(selected_index)
 refresh_buttons();refresh_preview()

func refresh_preview():
 columns.visible=draft.layout=="grid";preview.set_data(draft)

func refresh_buttons():
 var chosen=selected_index>=0 and selected_index<draft.items.size()
 var card_chosen=not selector.selected_entry.is_empty()
 add_card.disabled=not card_chosen or draft.items.size()>=Images.MAX_ITEMS
 replace_card.disabled=not card_chosen or not chosen;replace_custom.disabled=not chosen
 add_custom.disabled=draft.items.size()>=Images.MAX_ITEMS;remove.disabled=not chosen
 move_up.disabled=not chosen or selected_index==0;move_down.disabled=not chosen or selected_index>=draft.items.size()-1

func show_error(reason: String):
 error_label.text=reason;error_label.show()
