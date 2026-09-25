extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
var app
var checks=0
var failures=[]
func _initialize(): call_deferred("run")
func expect(ok: bool,title: String):
 checks+=1
 if ok: print("PASS: "+title)
 else: failures.append(title); push_error(title)
func deck(id: String) -> Dictionary:
 var d=Store.blank(id); d.id=id; d.leader="70"; d.main=["14","15"]; return d
func find_button(node: Node,title: String):
 if node is Button and node.text==title: return node
 for child in node.get_children():
  var found=find_button(child,title)
  if found: return found
 return null
func run():
 var saved=FileAccess.get_file_as_string(Store.SAVE_PATH)
 app=load("res://main.tscn").instantiate(); root.add_child(app); await process_frame
 app.editor()
 app.decks=[deck("A"),deck("B"),deck("C")]; app.draft=app.decks[1].duplicate(true)
 app.player_choice=2; app.ai_choice=0; app.dirty=true; app.update_deck_rows()
 expect(find_button(app.screen,"删除卡组")!=null and find_button(app.screen,"备牌")==null,"bottom-right control replaced by delete deck")
 find_button(app.screen,"删除卡组").pressed.emit()
 var confirmation: ConfirmationDialog
 for child in app.get_children():
  if child is ConfirmationDialog: confirmation=child
 expect(confirmation!=null and "B" in confirmation.dialog_text,"delete confirms the current deck by name")
 if confirmation!=null: confirmation.canceled.emit()
 await process_frame
 expect(app.decks.size()==3 and app.draft.id=="B" and app.dirty,"cancel preserves saved list and unsaved draft")
 app.toggle_color("黑")
 expect(app.matches_colors(Store.CARDS["15"]) and not app.matches_colors(Store.CARDS["14"]),"black selects mono-black and rejects red-black")
 expect(app.library.get_children().all(func(row): return Store.CARDS[row.get_meta("card_id")].colors==["黑"]),"visible library contains only mono-black")
 app.toggle_color("红")
 expect(app.selected_colors==["黑","红"] and app.matches_colors(Store.CARDS["14"]),"red-black accepts exact pair regardless of click order")
 expect(not app.matches_colors(Store.CARDS["15"]) and not app.matches_colors(Store.CARDS["165"]),"red-black excludes both monochrome colors")
 expect(not app.matches_colors(Store.CARDS["78"]) and not app.matches_colors(Store.CARDS["70"]),"red-black excludes tricolor and other color pairs")
 expect(app.library.get_children().all(func(row): var c=Store.CARDS[row.get_meta("card_id")]; return c.colors.size()==2 and "红" in c.colors and "黑" in c.colors),"visible library follows strict pair match")
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://work/v091-editor-red-black.png")
 app.toggle_color("黑")
 expect(app.matches_colors(Store.CARDS["165"]) and not app.matches_colors(Store.CARDS["14"]),"unchecking black leaves strict mono-red")
 app.toggle_color("红")
 expect(app.selected_colors.is_empty() and app.library.get_child_count()==Store.CARDS.keys().filter(func(id):return Store.CARDS[id].get("canonical_id",id)==id).size(),"unchecking final color restores all")
 app.toggle_color("黑"); app.toggle_color("全部")
 expect(app.selected_colors.is_empty() and app.library.get_child_count()==Store.CARDS.keys().filter(func(id):return Store.CARDS[id].get("canonical_id",id)==id).size(),"all button clears strict filters")
 expect(FileAccess.get_file_as_string(Store.SAVE_PATH)==saved,"real player saved decks unchanged")
 print("V091_TEST: %d checks; %d failures" % [checks,failures.size()])
 quit(1 if not failures.is_empty() else 0)
