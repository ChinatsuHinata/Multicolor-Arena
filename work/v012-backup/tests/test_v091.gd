extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
const TEST_PATH="res://work/v091-decks.json"
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
 app.decks=[deck("A"),deck("B"),deck("C")]; app.draft=app.decks[1].duplicate(true)
 app.player_choice=2; app.ai_choice=0; app.dirty=true; app.editor()
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
 expect(app.selected_colors.is_empty() and app.library.get_child_count()==Store.CARDS.size(),"unchecking final color restores all")
 app.toggle_color("黑"); app.toggle_color("全部")
 expect(app.selected_colors.is_empty() and app.library.get_child_count()==Store.CARDS.size(),"all button clears strict filters")
 expect(Store.persist(app.decks,TEST_PATH).is_empty(),"test fixture saved independently")
 expect(app.delete_current_deck(TEST_PATH).is_empty(),"saved deck deletion succeeds")
 expect(app.decks.map(func(d): return d.id)==["A","C"] and Store.load_decks(TEST_PATH).decks==app.decks,"deletion persists only remaining decks")
 expect(app.draft.id=="C" and not app.dirty and app.player_choice==1 and app.ai_choice==0,"editor and battle selections retain remaining deck identities")
 expect(Store.load_decks(TEST_PATH+".bak").decks.size()==3,"existing persistence backup retains pre-delete decks")
 var disk=FileAccess.get_file_as_string(TEST_PATH)
 app.draft=Store.blank("unsaved"); app.draft.main=["14"]; app.dirty=true
 expect(app.delete_current_deck(TEST_PATH).is_empty() and app.draft.main.is_empty() and app.draft.leader.is_empty() and not app.dirty,"deleting an unsaved draft resets it without requiring a leader")
 expect(FileAccess.get_file_as_string(TEST_PATH)==disk and app.decks.size()==2,"unsaved deletion does not write or remove stored decks")
 app.draft=app.decks[0].duplicate(true); app.dirty=true
 var prior=JSON.stringify([app.decks,app.draft,app.player_choice,app.ai_choice,app.dirty])
 expect(not app.delete_current_deck("res://work/missing-v091-parent/decks.json").is_empty(),"failed disk write is reported")
 expect(JSON.stringify([app.decks,app.draft,app.player_choice,app.ai_choice,app.dirty])==prior,"failed deletion leaves all in-memory state unchanged")
 app.load_error="test load failure"
 expect(app.delete_current_deck(TEST_PATH)==app.load_error and FileAccess.get_file_as_string(TEST_PATH)==disk,"existing load error prevents overwriting saved data")
 app.load_error=""
 expect(app.delete_current_deck(TEST_PATH).is_empty() and app.decks.size()==1,"deleting first deck keeps the other")
 expect(app.delete_current_deck(TEST_PATH).is_empty() and app.decks.is_empty() and Store.load_decks(TEST_PATH).decks.is_empty(),"deleting last deck persists empty list")
 app.editor(); await process_frame
 expect(app.draft.main.is_empty() and app.draft.leader.is_empty() and app.saved_select.item_count==1 and app.player_choice==0 and app.ai_choice==0,"empty state is usable and has valid selection indices")
 expect(FileAccess.get_file_as_string(Store.SAVE_PATH)==saved,"real player saved decks unchanged")
 print("V091_TEST: %d checks; %d failures" % [checks,failures.size()]); quit(1 if not failures.is_empty() else 0)
