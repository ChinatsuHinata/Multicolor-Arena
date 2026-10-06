extends RefCounted
## Stable tutorial intentions mapped to the existing editor controls.
const ALLOWED=["editor.sort","editor.add","editor.remove","editor.move","editor.inspect","editor.search","editor.filter","editor.rule_set","editor.view","editor.page","editor.menu","editor.select_zone"]
const METHODS={"sort_current_deck":"editor.sort","save_deck":"editor.save","menu":"editor.return_menu","remove_card":"editor.remove","add_to":"editor.add","open_tools_menu":"editor.menu","toggle_details":"editor.inspect","open_art_picker":"editor.external","export_deck":"editor.export","import_deck":"editor.import","delete_deck_dialog":"editor.delete"}
const NAMES={"LibraryBackToMenu":"editor.return_menu","DeckBackToMenu":"editor.return_menu","EditorReturnMenu":"editor.return_menu","DeckViewSwitch":"editor.view","LibrarySearch":"editor.search","LibraryKindFilter":"editor.filter","LibrarySortChoice":"editor.filter","DeckRuleSet":"editor.rule_set","PreviousLibraryPage":"editor.page","NextLibraryPage":"editor.page","PreviousMainPage":"editor.page","NextMainPage":"editor.page","SavedDeckSelect":"editor.external"}
# Anonymous callbacks have no method identity; this is the UI adapter's explicit
# mapping, never a caption embedded in authored task references.
const CAPTIONS={"返回":"editor.return_menu","返回主菜单":"editor.return_menu","排序":"editor.sort","排序卡组":"editor.sort","菜单":"editor.menu","主卡组":"editor.select_zone","副卡组":"editor.select_zone","加入主卡组":"editor.add","加入副卡组":"editor.add","设为自机":"editor.add","移出卡组":"editor.remove","保存":"editor.save","保存卡组":"editor.save","新建":"editor.external","清空卡组":"editor.delete","删除卡组":"editor.delete","更换异画":"editor.external","关闭":"editor.inspect"}
const LABELS={"editor.sort":"排序卡组","editor.add":"加入卡牌","editor.remove":"移出卡牌","editor.move":"移动卡牌","editor.inspect":"查看卡牌","editor.search":"搜索卡牌","editor.filter":"筛选卡牌","editor.rule_set":"选择构筑规则","editor.view":"切换视图","editor.page":"翻页","editor.menu":"打开菜单","editor.select_zone":"切换卡组区域"}

static func caption(action: Dictionary,cards: Dictionary={}) -> String:
 var args=action.get("args",{});var result=LABELS.get(action.get("id"),str(action.get("id","")))
 if args.has("card_id"):
  var card_name=str(cards.get(args.card_id,{}).get("name",args.card_id))
  result+=card_name if card_name.begins_with("「") and card_name.ends_with("」") else "「"+card_name+"」"
 if args.has("zone"):result+=" · "+{"main":"主卡组","side":"副卡组","leader":"自机"}.get(args.zone,args.zone)
 if args.has("value"):result+=" · "+str(args.value)
 return result

static func identify(control: Control,callback: Callable=Callable()) -> String:
 if control.has_meta("tutorial_action"):return str(control.get_meta("tutorial_action"))
 if NAMES.has(str(control.name)):return NAMES[str(control.name)]
 if str(control.name).begins_with("LibraryColor"):return "editor.filter"
 if callback.is_valid() and METHODS.has(str(callback.get_method())):return METHODS[str(callback.get_method())]
 if callback.is_valid() and callback.get_method()=="toggle_color":return "editor.filter"
 if control is Button and CAPTIONS.has(control.text):return CAPTIONS[control.text]
 return "ui.unsupported"

static func args_for(control: Control,values: Array=[]) -> Dictionary:
 var args={}
 if control is Button:
  if control.text in ["主卡组","加入主卡组"]:args.zone="main"
  elif control.text in ["副卡组","加入副卡组"]:args.zone="side"
  elif control.text=="设为自机":args.zone="leader"
 if not values.is_empty():args.value=values[0]
 return args
