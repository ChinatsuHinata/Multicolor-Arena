extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
var app
var failures=[]
var checks=0
func expect(ok: bool,title: String):
 checks+=1
 if ok: print("PASS: "+title)
 else: failures.append(title); push_error(title)
func _initialize(): call_deferred("run")
func motion(point: Vector2, held: bool):
 var event=InputEventMouseMotion.new()
 event.position=point
 event.global_position=point
 event.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0
 event.relative=Vector2(20,0)
 root.push_input(event,true)
func click(point: Vector2, pressed: bool):
 var event=InputEventMouseButton.new()
 event.position=point
 event.global_position=point
 event.button_index=MOUSE_BUTTON_LEFT
 event.pressed=pressed
 root.push_input(event,true)
func drag(from: Vector2, to: Vector2):
 motion(from,false)
 click(from,true)
 await process_frame
 motion(from+Vector2(20,0),true)
 await process_frame
 motion(to,true)
 await process_frame
 click(to,false)
 await process_frame
 await process_frame
func main_tile():
 for tile in app.main_content.get_children():
  if tile.get_script()==preload("res://scripts/deck_card.gd") and tile.source_zone=="main": return tile
 return null
func run():
 var before=FileAccess.get_file_as_string(Store.SAVE_PATH)
 app=load("res://main.tscn").instantiate()
 root.add_child(app)
 await process_frame
 app.draft=Store.blank("拖放验证")
 app.draft.leader="70"
 app.editor()
 await process_frame
 await process_frame
 var row=app.library.get_child(0)
 var source=row.global_position+Vector2(80,25)
 var target=app.main_content.global_position+Vector2(250,50)
 await drag(source,target)
 expect(app.draft.main==["68"],"mouse drag from library adds exactly one card")
 if main_tile()!=null:
  await drag(main_tile().global_position+Vector2(35,35),source)
 expect(app.draft.main.is_empty(),"mouse drag back over library row removes card")
 await drag(source,app.deck_canvas.global_position+Vector2(100,600))
 expect(app.draft.side==["68"],"mouse drag from library adds to side deck")
 app.return_card_to_library(Vector2.ZERO,{"card_id":"68","source_zone":"side","source_index":0})
 expect(app.draft.side.is_empty(),"returning side card removes it")
 app.return_card_to_library(Vector2.ZERO,{"card_id":"70","source_zone":"leader","source_index":0})
 expect(app.draft.leader.is_empty(),"leader may be dragged out")
 app.drop_editor_card({"card_id":"68","source_zone":"library","source_index":-1},"leader")
 expect(app.draft.leader=="68","library drag fills leader slot")
 var count=app.draft.main.size()
 await drag(source,Vector2(600,35))
 expect(app.draft.main.size()==count,"cancelled drag neither adds nor removes")
 app.draft.main=["68","70","68"]
 app.return_card_to_library(Vector2.ZERO,{"card_id":"68","source_zone":"main","source_index":2})
 expect(app.draft.main==["68","70"],"remove exact dragged duplicate")
 app.return_card_to_library(Vector2.ZERO,{"card_id":"68","source_zone":"main","source_index":1})
 expect(app.draft.main==["68","70"],"stale source cannot remove another card")
 var clean=true
 for id in Store.CARDS:
  var text=app.card_description(id)
  if text.is_empty() or "费用" in text or "颜色值" in text or "SOI-" in text or "画师" in text or "攻击 3" in text: clean=false
 expect(clean,"preview shows abilities without stats or metadata")
 expect("3点伤害" in app.card_description("68") and "1点伤害" in app.card_description("68"),"rules retain meaningful effect numbers")
 expect(FileAccess.get_file_as_string(Store.SAVE_PATH)==before,"saved player decks unchanged")
 var report=FileAccess.open("res://work/v04-test.txt",FileAccess.WRITE)
 report.store_string("%d checks, %d failures\n%s" % [checks,failures.size(),"\n".join(failures)])
 print("V04_TEST: %d checks, %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
