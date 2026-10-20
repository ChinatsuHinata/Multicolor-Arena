extends "res://scripts/deck_picker.gd"
## Private cloud gallery shares the local picker's cards, filters and pagination.
var store
var upload_button: Button
var refresh_button: Button
var download_button: Button
var delete_button: Button
var status_label: Label
var message=""

func _ready():
 caption="云端卡组";empty_message="还没有云端卡组，请上传当前套牌。";show_favorites=false
 super._ready()
 name="CloudDeckSlots"
 fit_background()
 if app.is_android:
  color_row.hide()
  search.placeholder_text="检索名称 / 自机 / 卡牌 / 颜色"
 var header=heading.get_parent()
 upload_button=action(header,"上传当前套牌",upload_current);upload_button.name="UploadCurrentCloudDeck"
 header.move_child(upload_button,1)
 refresh_button=action(header,"同步",func():message="";store.refresh());refresh_button.name="RefreshCloudDecks"
 header.move_child(refresh_button,2)
 var pagination=page_label.get_parent()
 download_button=action(pagination,"下载到本地",download_selected);download_button.name="DownloadCloudDeck"
 delete_button=action(pagination,"从云端删除",delete_selected);delete_button.name="DeleteCloudDeck"
 status_label=text(body,"",app.ui_metrics.small,app.MUTED);status_label.name="CloudDeckStatus"
 store.changed.connect(refresh_cloud)
 refresh_cloud();store.refresh()

func source_decks() -> Array:return store.decks

func fit_background():
 var background=get_child(0) as ColorRect
 background.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 background.position=-global_position;background.size=app.get_viewport_rect().size

func selected_deck() -> Dictionary:
 for deck in store.decks:
  if str(deck.id)==selected_id:return deck
 return {}

func choose(id: String):
 if store.busy:return
 selected_id=id;message="";render_tiles();update_actions()

func make_tile(entry: Dictionary) -> Button:
 var tile=super.make_tile(entry)
 tile.name="CloudDeckSlot_%d" % int(entry.deck.cloud_slot);tile.disabled=store.busy
 return tile

func refresh_cloud():
 if not is_instance_valid(status_label):return
 if selected_deck().is_empty():selected_id=""
 var previous_page=page_index
 reload_entries();page_index=clampi(previous_page,0,pages()-1);render_tiles()
 update_actions()

func update_actions():
 var deck=selected_deck()
 upload_button.disabled=store.busy or store.decks.size()>=store.LIMIT and not store.owns(app.draft)
 upload_button.tooltip_text="上传「%s」，本地卡组和当前编辑内容会保留。" % app.draft.get("name","")
 refresh_button.disabled=store.busy
 download_button.disabled=store.busy or deck.is_empty()
 delete_button.disabled=store.busy or deck.is_empty()
 var status=message if not message.is_empty() and not store.busy else store.status
 if message.is_empty() and not store.busy and not deck.is_empty():status="已选择「%s」，可下载到本地或从云端删除。" % deck.name
 status_label.text=status if not status.is_empty() else "选择云端套牌后，可下载到本地或从云端删除。"
 status_label.tooltip_text=status_label.text

func upload_current():
 message=""
 var title=str(app.draft.get("name",""))
 app.upload_private_deck(func(answer):
  if not is_instance_valid(self):return
  message="已上传「%s」到云端。" % title if answer.get("ok",false) else str(answer.get("message","上传失败"))
  update_actions())

func download_selected():
 var deck=selected_deck()
 if store.busy or deck.is_empty():return
 var result=Store.download_to_local(deck)
 if result.has("error"):message=result.error
 else:
  app.reload_decks()
  message="已下载「%s」到本地。" % deck.name
 update_actions()

func delete_selected():
 var deck=selected_deck()
 if store.busy or deck.is_empty():return
 message="";app.delete_cloud_deck(deck.duplicate(true))

func refresh_metrics():
 super.refresh_metrics()
 fit_background()
 if is_instance_valid(status_label):status_label.add_theme_font_size_override("font_size",app.ui_metrics.small)

func handle_input(event: InputEvent):
 if app.get_children().any(func(child):return child is Window and child.visible):return
 super.handle_input(event)
