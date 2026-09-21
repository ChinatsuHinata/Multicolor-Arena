extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
var checks=0
var failures=[]
func expect(ok: bool,title: String):
 checks+=1
 if ok: print("PASS: "+title)
 else: failures.append(title); push_error(title)
func _initialize(): call_deferred("run")
func run():
 var before=FileAccess.get_file_as_string(Store.SAVE_PATH)
 var app=load("res://main.tscn").instantiate()
 root.add_child(app)
 await process_frame
 app.draft=Store.blank("布局检查")
 app.draft.leader="70"
 for i in range(70): app.draft.main.append("68")
 app.editor()
 await process_frame
 await process_frame
 expect(app.main_card_rect(16).position.x==4 and app.main_card_rect(16).position.y>=240,"third row fills space beneath leader")
 var overlap=false
 for i in range(70):
  var rect=app.main_card_rect(i)
  if rect.intersects(Rect2(4,4,162,231)): overlap=true
  for j in range(i):
   if rect.intersects(app.main_card_rect(j)): overlap=true
 expect(not overlap,"all 70 main cards have distinct unobscured positions")
 app.main_scroll.scroll_vertical=10000
 await process_frame
 expect(app.main_card_rect(69).end.y-app.main_scroll.scroll_vertical<=app.main_scroll.size.y,"last card scrolls fully into view")
 app.toggle_color("红")
 app.toggle_color("黄")
 expect(app.selected_colors==["红","黄"] and app.color_buttons["红"].button_pressed and app.color_buttons["黄"].button_pressed,"red and yellow stay selected together")
 expect(app.matches_colors(Store.CARDS["70"]) and app.matches_colors(Store.CARDS["99"]) and not app.matches_colors(Store.CARDS["167"]),"multiple selected colors match either color")
 app.toggle_color("红")
 expect(app.selected_colors==["黄"],"unchecking one color preserves the other")
 app.toggle_color("全部")
 expect(app.selected_colors.is_empty() and app.library.get_child_count()==Store.CARDS.size(),"all resets color selection")
 expect(Store.CARDS["70"].colors==["红","黄"] and Store.CARDS["170"].colors==["红","黄"] and Store.CARDS["68"].colors==["蓝","黄"],"three requested multicolor identities")
 var names=true
 for row in app.library.get_children():
  if row.get_child(0).text!=Store.CARDS[row.get_meta("card_id")].name: names=false
 expect(names,"library labels preserve entire titles and names")
 app.query="普通的魔法使"
 app.update_library()
 expect(app.library.get_child_count()==1 and app.library.get_child(0).get_meta("card_id")=="68","full character title is searchable")
 app.selected="68"
 app.update_preview()
 await process_frame
 await process_frame
 var scroll=app.preview.get_node("CardTextScroll")
 var column=scroll.get_child(0)
 expect(column.get_child(1).text==app.card_description("68") and "自机能力" in column.get_child(1).text and "1点伤害" in column.get_child(1).text,"complete workbook ability text in preview")
 scroll.scroll_vertical=10000
 await process_frame
 expect(column.size.y-scroll.scroll_vertical<=scroll.size.y+1,"preview footer remains reachable by scrolling")
 expect(FileAccess.get_file_as_string(Store.SAVE_PATH)==before,"player saved decks unchanged")
 var report=FileAccess.open("res://work/v03-test.txt",FileAccess.WRITE)
 report.store_string("%d checks, %d failures\n%s" % [checks,failures.size(),"\n".join(failures)])
 print("V03_TEST: %d checks, %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)

