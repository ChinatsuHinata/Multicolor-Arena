extends "res://tests/support/ui_base.gd"
const GuideImage=preload("res://scripts/tutorial/guide_image.gd")
const Config=preload("res://scripts/tutorial/config.gd")
const OUTPUT="res://work/tutorial-guide-image"
var editor

func frames(count: int=6):
 for i in range(count):await process_frame

func shot(title: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUTPUT.path_join(title+".png"))

func touch(at: Vector2):
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()

func swipe_image(at: Vector2):
 var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true
 root.push_input(event,true);await process_frame
 var movement=InputEventScreenDrag.new();movement.index=0;movement.position=at+Vector2(0,-40);movement.relative=Vector2(0,-40)
 root.push_input(movement,true);await process_frame
 event=event.duplicate();event.position=movement.position;event.pressed=false;root.push_input(event,true);await frames()

func fixture(width: int=640,height: int=320) -> Image:
 var image=Image.create(width,height,false,Image.FORMAT_RGBA8);image.fill(Color("#152b3a"))
 for i in range(3):
  var box=Rect2i(Vector2i(width*(0.08+i*0.31),height*0.20),Vector2i(width*0.22,height*0.60))
  image.fill_rect(box,[Color("#46b6cf"),Color("#f0c866"),Color("#7ccd93")][i])
 return image

func select_art_card(fields,id: String):
 fields.selector.search_input.text=id;fields.selector.search_input.text_changed.emit(id);await frames()
 var results=fields.selector.search_results.get_children().filter(func(node):return node.has_meta("card_id") and node.get_meta("card_id")==id)
 expect(not results.is_empty(),"card search finds exact ID: "+id)
 if not results.is_empty():await click(results[0].get_global_rect().get_center());await frames()

func check_card_gallery() -> Dictionary:
 root.size=Vector2i(1280,600);root.content_scale_size=root.size;app.is_android=false;app.refresh_ui_metrics();await frames()
 var original=editor.model.data.duplicate(true)
 editor.open_guide_image();await frames()
 var fields=editor.dialog_layer.find_child("TutorialGuideImageForm",true,false)
 expect(fields.get_global_rect().end.y<=root.size.y and fields.get_global_rect().end.x<=root.size.x,"card illustration editor fits 1280 by 600")
 await shot("card-editor-small")
 var depth=editor.model.undo_stack.size()
 await click(editor.dialog_layer.find_child("ApplyTutorialGuideImages",true,false).get_global_rect().get_center());await frames()
 expect(editor.model.data==original and editor.model.undo_stack.size()==depth,"applying unchanged media preserves legacy PNG and edit history")
 editor.open_guide_image();await frames();fields=editor.dialog_layer.find_child("TutorialGuideImageForm",true,false)
 fields.orientation.select(1);fields.orientation.item_selected.emit(1);await frames()
 expect(fields.selector.entries.all(func(entry):return app.landscape_card(entry.id)),"horizontal card filter includes only landscape art")
 fields.orientation.select(2);fields.orientation.item_selected.emit(2);await frames()
 expect(fields.selector.entries.all(func(entry):return not app.landscape_card(entry.id)),"vertical card filter includes only portrait art")
 fields.orientation.select(0);fields.orientation.item_selected.emit(0);await frames()
 await select_art_card(fields,"70")
 await click(fields.add_card.get_global_rect().get_center());await frames()
 await select_art_card(fields,"100")
 await click(fields.add_card.get_global_rect().get_center());await frames()
 await select_art_card(fields,"53")
 await click(fields.add_card.get_global_rect().get_center());await frames()
 expect(fields.draft.items.size()==4 and fields.draft.items[1].card_id=="70" and fields.draft.items[2].card_id=="100","specific card selections append in chosen order with the custom image")
 if fields.draft.items.size()!=4:editor.close_dialog();return original.steps.step_1.guide.image
 fields.select_item(1);await frames()
 var art_index=fields.art_ids.find("tts_151600")
 expect(art_index>=0,"selected card offers its alternate artwork")
 if art_index>=0:fields.art_choice.select(art_index);fields.art_choice.item_selected.emit(art_index);await frames()
 await click(fields.replace_card.get_global_rect().get_center());await frames()
 expect(fields.draft.items[1].get("art_id")=="tts_151600" and fields.draft.items.size()==4,"replacement specifies exact card artwork without appending or altering other images")
 expect(fields.image_list.get_item_text(1).contains("#70") and fields.image_list.get_item_text(1).contains("竖卡") and fields.image_list.get_item_text(1).contains("Kanta"),"chosen list identifies card ID, orientation and art version")
 fields.move_item(-1);expect(fields.draft.items[0].get("art_id")=="tts_151600","moving image up changes gallery order")
 fields.move_item(1);expect(fields.draft.items[1].get("art_id")=="tts_151600","moving image down restores chosen order")
 fields.select_item(3);fields.pick_custom(true);await frames()
 var picker=editor.get_node("TutorialGuideImagePicker");picker.hide();picker.file_selected.emit(OUTPUT.path_join("source.jpg"));await frames()
 expect(fields.draft.items.size()==4 and fields.draft.items[3].get("name")=="source.jpg","selected card can be replaced with an explicitly named custom image")
 fields.remove_item();expect(fields.draft.items.size()==3,"removing selected media preserves the other card and custom images")
 var layout=fields.find_child("TutorialGuideImageLayout",true,false)
 layout.select(2);layout.item_selected.emit(2);fields.columns.value=2;await frames()
 var candidate=fields.draft.duplicate(true)
 expect(editor.model.data==original,"card selection, replacement, ordering and custom import remain private before applying")
 await shot("card-selection-editor")
 await click(editor.dialog_layer.find_child("CancelTutorialGuideImages",true,false).get_global_rect().get_center());await frames()
 expect(editor.model.data==original,"cancel discards all card gallery edits")
 editor.open_guide_image();await frames();fields=editor.dialog_layer.find_child("TutorialGuideImageForm",true,false)
 fields.draft=candidate.duplicate(true);fields.refresh_items();await frames()
 await click(editor.dialog_layer.find_child("ApplyTutorialGuideImages",true,false).get_global_rect().get_center());await frames()
 expect(editor.model.data.steps.step_1.guide.image==candidate and editor.model.validate().ok,"applying mixed gallery stores card IDs and exact art versions")
 var gallery_path=OUTPUT.path_join("gallery.json")
 expect(editor.model.save_course(gallery_path).is_empty(),"mixed gallery saves")
 app.tutorial_editor(gallery_path);await frames();editor=app.screen.get_child(0)
 expect(GuideImage.normalize(editor.model.data.steps.step_1.guide.image)==GuideImage.normalize(candidate),"card order, artwork and custom image survive reopening")
 await shot("gallery-node-inspector")
 for bad in [{"items":[]},{"items":[{"card_id":"missing"}]},{"items":[{"card_id":"70","art_id":"tts_150900"}]},{"layout":"diagonal","items":[{"card_id":"70"}]},{"columns":0,"items":[{"card_id":"70"}]},{"columns":2.5,"items":[{"card_id":"70"}]},{"items":[{"card_id":"70","path":"external.png"}]}]:
  var invalid=editor.model.data.duplicate(true);invalid.steps.step_1.guide.image=bad
  expect(not Config.new().validate(invalid,Store.CARDS).ok,"invalid card gallery rejects unknown IDs, artwork, layout or columns")
 for kind in ["battlefield","deck","in_game"]:
  editor.change_scene(kind);await frames()
  for arrangement in ["row","column","grid"]:
   editor.model.data.steps.step_1.guide.image.layout=arrangement
   for android in [false,true]:
    app.is_android=android;root.size=Vector2i(1280,720);root.content_scale_size=root.size;app.refresh_ui_metrics();await frames()
    editor.test_course();await frames(12)
    var guide=editor.playtest.tutorial_guide;var flow=editor.playtest.runtime;flow.set_process(false)
    var gallery=guide.illustration
    expect(gallery.pictures.size()==3 and gallery.configuration.layout==arrangement,"mixed gallery uses chosen layout: %s %s %s" % [kind,arrangement,android])
    expect(gallery.pictures[1].texture.get_width()<gallery.pictures[1].texture.get_height() and gallery.pictures[2].texture.get_width()>gallery.pictures[2].texture.get_height(),"portrait and landscape card artwork retain natural directions")
    expect(gallery.pictures.all(func(picture):return picture.position.x>=-1 and picture.position.x+picture.size.x<=gallery.size.x+1),"mixed artwork fits gallery width")
    if arrangement=="column":expect(gallery.pictures[1].position.y>=gallery.pictures[0].size.y,"vertical layout preserves sequence")
    if arrangement=="grid":expect(gallery.pictures[2].position.y>gallery.pictures[0].position.y,"grid column count wraps later images")
    var picture=gallery.pictures[2];guide.scroll.ensure_control_visible(picture);await frames()
    if android:await touch(picture.get_global_rect().get_center())
    else:await click(picture.get_global_rect().get_center())
    await frames()
    expect(is_instance_valid(gallery.overlay) and gallery.overlay.find_child("TutorialImageFullSize",true,false).texture==picture.texture,"each card opens its own exact illustration")
    if not is_instance_valid(gallery.overlay):editor.stop_test();return candidate
    gallery.close_preview();guide.scroll.scroll_vertical=0;await frames()
    await shot("gallery-%s-%s-%s" % [kind,arrangement,"android" if android else "desktop"])
    editor.stop_test();await frames()
   app.is_android=false
 editor.model.data.steps.step_1.guide.image=candidate.duplicate(true)
 return candidate

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 Store.Paths.root_override=ProjectSettings.globalize_path(OUTPUT.path_join("fixtures-"+str(Time.get_ticks_usec())))
 root.mode=Window.MODE_WINDOWED;root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.size=Vector2i(1600,900)
 var source=OUTPUT.path_join("source.png");var jpg=OUTPUT.path_join("source.jpg");var webp=OUTPUT.path_join("source.webp")
 var image=fixture();image.set_pixel(0,0,Color.TRANSPARENT)
 expect(image.save_png(source)==OK,"PNG fixture writes")
 image.save_jpg(jpg);image.save_webp(webp)
 for path in [source,jpg,webp]:
  var result=GuideImage.import_file(path)
  expect(result.error.is_empty() and GuideImage.read(result.data).error.is_empty(),"supported image imports: "+path.get_extension())
 var wide=OUTPUT.path_join("wide.png");fixture(4096,1024).save_png(wide)
 var resized=GuideImage.texture(GuideImage.import_file(wide).data)
 expect(resized.get_width()==2048 and resized.get_height()==512,"large import keeps aspect ratio within portable image size")
 app=load("res://main.tscn").instantiate();app.settings_path=OUTPUT.path_join("missing-settings.json");app.account_session_path=OUTPUT.path_join("missing-account.json")
 app.tutorial_local_directory=OUTPUT.path_join("local-courses");DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(app.tutorial_local_directory))
 root.add_child(app);await frames();app.tutorial_editor();await frames();editor=app.screen.get_child(0)
 var original=editor.model.data.duplicate(true)
 expect(editor.find_child("RemoveTutorialGuideImage",true,false).disabled,"new node has no removable image")
 await click(editor.find_child("EditTutorialGuideImage",true,false).get_global_rect().get_center());await frames()
 var fields=editor.dialog_layer.find_child("TutorialGuideImageForm",true,false)
 expect(fields.selector!=null and fields.image_list!=null,"image editor opens explicit card search and ordered selection")
 fields.pick_custom(false);await frames()
 var picker=editor.get_node("TutorialGuideImagePicker")
 expect(picker.file_mode==FileDialog.FILE_MODE_OPEN_FILE and picker.access==FileDialog.ACCESS_FILESYSTEM,"add image opens filesystem picker")
 picker.hide();picker.canceled.emit();await frames()
 await click(editor.dialog_layer.find_child("CancelTutorialGuideImages",true,false).get_global_rect().get_center());await frames()
 expect(editor.model.data==original,"canceling the image picker preserves course")
 expect(not editor.set_guide_image("step_1",OUTPUT.path_join("missing.png")).is_empty() and editor.model.data==original,"failed import preserves existing course")
 expect(editor.set_guide_image("step_1",source).is_empty(),"adding image to selected node succeeds")
 await frames()
 var picture=editor.find_child("AuthoringGuideImage",true,false)
 expect(picture!=null and picture.texture.get_size()==Vector2(640,320),"node inspector displays imported illustration")
 expect(picture.texture.get_image().get_pixel(0,0).a==0,"PNG transparency survives import")
 var data=editor.model.data.steps.step_1.guide.image.duplicate(true)
 expect(not editor.set_guide_image("step_1",OUTPUT.path_join("missing.png")).is_empty() and editor.model.data.steps.step_1.guide.image==data,"failed replacement keeps original illustration")
 expect(editor.model.dirty() and not editor.model.data.steps.step_2.guide.has("image"),"image changes only its node and marks course unsaved")
 var depth=editor.model.undo_stack.size();editor.set_guide_image("step_1",source)
 expect(editor.model.undo_stack.size()==depth,"reimporting the same illustration does not create a change")
 expect(editor.set_guide_image("step_1",jpg).is_empty(),"existing illustration can be replaced")
 expect(editor.model.undo() and editor.model.data.steps.step_1.guide.image==data,"undo restores original illustration")
 editor.refresh();await frames()
 await shot("editor")
 var course=OUTPUT.path_join("portable.json")
 expect(editor.model.save_course(course).is_empty(),"course with illustration saves")
 # Removing the original source proves that opening the JSON needs no image path.
 DirAccess.remove_absolute(source)
 app.tutorial_editor(course);await frames();editor=app.screen.get_child(0)
 expect(editor.model.data.steps.step_1.guide.image==data and not editor.model.dirty(),"saved image reopens after original file is deleted")
 expect(editor.find_child("AuthoringGuideImage",true,false)!=null,"reopened inspector previews embedded image")
 await click(editor.find_child("AuthoringGuideImage",true,false).get_global_rect().get_center());await frames()
 expect(editor.find_child("TutorialImageFullSize",true,false)!=null,"inspector illustration opens enlarged view")
 await click(editor.find_child("CloseTutorialImagePreview",true,false).get_global_rect().get_center());await frames()
 expect(editor.find_child("TutorialImageOverlay",true,false)==null,"enlarged inspector image closes")
 var invalid=editor.model.data.duplicate(true)
 for value in [null,"path.png",{}, {"png_base64":"bad"}, {"png_base64":Marshalls.raw_to_base64("not a PNG".to_utf8_buffer())}, {"png_base64":data.png_base64,"path":"external.png"}]:
  invalid.steps.step_1.guide.image=value
  expect(not Config.new().validate(invalid,Store.CARDS).ok,"malformed illustration is rejected by course validation")
 for kind in ([] if "--card-gallery-only" in OS.get_cmdline_user_args() else ["battlefield","deck","in_game"]):
  if kind!="battlefield":editor.change_scene(kind);await frames()
  for android in [false,true]:
   app.is_android=android
   for extent in ([Vector2i(1600,900),Vector2i(1280,600)] if not android else [Vector2i(1280,720)]):
    root.size=extent;root.content_scale_size=extent;app.refresh_ui_metrics();await frames()
    editor.test_course();await frames(12)
    var guide=editor.playtest.tutorial_guide;var flow=editor.playtest.runtime;flow.set_process(false)
    expect(guide.illustration.is_visible_in_tree() and guide.illustration.texture.get_size()==Vector2(640,320),"runtime displays embedded illustration: %s %s %s" % [kind,android,extent])
    expect(guide.panel.get_global_rect().end.y<=root.size.y+1 and guide.panel.get_global_rect().end.x<=root.size.x+1,"illustrated guide fits viewport: %s %s %s" % [kind,android,extent])
    guide.scroll.ensure_control_visible(guide.illustration);await frames()
    if android:
     await swipe_image(guide.illustration.get_global_rect().get_center())
     expect(not is_instance_valid(guide.illustration.overlay),"swiping illustration does not open enlarged view")
     guide.scroll.ensure_control_visible(guide.illustration);await frames()
    var before=flow.current_step
    if android:await touch(guide.illustration.get_global_rect().get_center())
    else:await click(guide.illustration.get_global_rect().get_center())
    await frames()
    expect(is_instance_valid(guide.illustration.overlay) and flow.current_step==before,"image click enlarges without advancing tutorial")
    if not is_instance_valid(guide.illustration.overlay):app.free();quit(1);return
    await click(Vector2(extent.x-32,extent.y-32));await frames()
    expect(is_instance_valid(guide) and flow.current_step==before,"enlarged image blocks background scene clicks")
    await shot(kind+("-android" if android else "-desktop")+"-enlarged")
    await click(guide.illustration.overlay.find_child("CloseTutorialImagePreview",true,false).get_global_rect().get_center());await frames()
    expect(not is_instance_valid(guide.illustration.overlay),"runtime enlarged illustration closes")
    await shot(kind+("-android" if android else "-desktop"))
    guide.set_popup(false);await frames();guide.set_popup(true);await frames()
    expect(guide.illustration.is_visible_in_tree(),"restoring guide keeps node illustration")
    flow.next();await frames()
    guide=editor.playtest.tutorial_guide
    expect(not guide.illustration.visible and guide.illustration.texture==null,"next node clears previous illustration")
    flow.previous();await frames();guide=editor.playtest.tutorial_guide
    expect(guide.illustration.visible,"previous node restores illustration")
    guide.illustration.open_preview();flow.next();await frames()
    expect(editor.playtest.find_child("TutorialImageOverlay",true,false)==null,"step switch closes image overlay")
    editor.stop_test();await frames()
   app.is_android=false
 data=await check_card_gallery()
 editor.selected_step="step_1";editor.refresh();await frames()
 await click(editor.find_child("RemoveTutorialGuideImage",true,false).get_global_rect().get_center());await frames()
 expect(not editor.model.data.steps.step_1.guide.has("image") and editor.find_child("AuthoringGuideImage",true,false)==null,"remove button clears image and preview")
 expect(editor.model.undo() and editor.model.data.steps.step_1.guide.image==data,"removed illustration can be undone")
 editor.refresh();await frames();editor.remove_guide_image()
 expect(editor.model.save_course(course).is_empty(),"removed image saves")
 app.tutorial_editor(course);await frames();editor=app.screen.get_child(0)
 expect(not editor.model.data.steps.step_1.guide.has("image"),"removed image stays absent after reopening")
 app.free();await frames()
 print("TUTORIAL GUIDE IMAGE: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
