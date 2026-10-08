extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
const Art=preload("res://scripts/card_art.gd")
const Account=preload("res://scripts/account_client.gd")
const Client=preload("res://scripts/deck_plaza_client.gd")
const Plaza=preload("res://scripts/deck_plaza.gd")
var server_url="ws://127.0.0.1:47872"
var errors=[]
var checks=0
var app

func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if ok:print("PASS: ",message)
 else:errors.append(message);push_error(message)

func account_request(action: String,username: String,password: String) -> Dictionary:
 var client=Account.new();root.add_child(client);client.server_url=server_url
 client.call_deferred("submit",action,username,password)
 var result=await client.finished
 var answer={"ok":result[0],"token":client.session_token,"nickname":client.nickname,"message":result[1]}
 client.queue_free();return answer

func request(payload: Dictionary,token: String) -> Dictionary:
 var client=Client.new();root.add_child(client);client.server_url=server_url
 client.call_deferred("request",payload,token)
 var answer=await client.finished
 client.queue_free();return answer

func settled(view):
 await process_frame;await process_frame
 for i in range(400):
  if not is_instance_valid(view) or not view.busy:break
  await create_timer(0.05).timeout
 await process_frame;await process_frame

func screenshot(path: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(path)

func run():
 root.mode=Window.MODE_WINDOWED
 root.size=Vector2i(1600,900)
 root.content_scale_size=Vector2i(1600,900)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 var args=OS.get_cmdline_user_args()
 for i in range(args.size()-1):
  if args[i]=="--server":server_url=args[i+1]
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/deck-plaza-tests/"+str(Time.get_ticks_usec()))
 var source=Store.blank("广场异画测试");source.leader="70";source.main=["100","100","100","100"]
 source.art_overrides={"70":"tts_151600"}
 var username="plaza_"+str(Time.get_ticks_usec())
 print("PLAZA_TEST_USER=",username)
 var account=await account_request("register",username,"password123!")
 check(account.ok,"register a plaza uploader")
 account=await account_request("login",username,"password123!")
 check(account.ok and account.token.length()==64,"log in for authenticated plaza access")
 if not account.ok:print("LOGIN FAILURE: ",account.message);quit(1);return
 var result=await request({"action":"list","page":0},"a".repeat(64))
 check(not result.get("ok",false) and result.get("auth_required",false),"cloud rejects invalid session on plaza read")
 var upload={"action":"upload","title":"异画灵梦","description":"测试套牌说明\n保留上传者异画。","tags":["灵梦","异画",username],"deck_code":Store.encode(source)}
 result=await request(upload,account.token)
 check(result.get("ok",false),"Godot compressed deck code uploads through encrypted session envelope")
 if not result.get("ok",false):print(result);quit(1);return
 var post_id=int(result.id)
 result=await request({"action":"detail","id":post_id},account.token)
 check(result.get("ok",false) and result.get("deck",{}).get("nickname","")==username and not result.get("deck",{}).has("username"),"cloud exposes the author's nickname without their login id")
 if not result.get("ok",false):print("DETAIL FAILURE: ",result);quit(1);return
 var post=result.deck
 var deck=Store.decode(post.deck_code).get("deck",{})
 check(not deck.is_empty() and Art.selected(deck,deck.leader,Store.CARDS)=="tts_151600","cloud round trip preserves the uploaded leader alternate art")
 check(post.description==upload.description and post.tags==upload.tags,"detail returns title, multiline description and tags")
 result=await request(dict_extra(upload,{"image":"data:image/png;base64,AAAA"}),account.token)
 check(not result.get("ok",false),"relay and store reject asset fields")
 result=await request(dict_extra(upload,{"tags":["1","2","3","4","5","6","7","8","9","10","11"]}),account.token)
 check(not result.get("ok",false),"cloud rejects eleven tags")
 app=load("res://main.tscn").instantiate()
 app.tutorial_local_directory="res://work/account-plaza-checks/tutorials"
 DirAccess.make_dir_recursive_absolute(app.tutorial_local_directory)
 app.account_session_path="res://work/deck-plaza-tests/no-session.json"
 app.deck_plaza_server_url=server_url;root.add_child(app);await process_frame
 app.draft=source.duplicate(true);app.dirty=true;app.editor();await process_frame
 check(app.screen.find_child("DeckPlazaButton",true,false)!=null and app.screen.find_child("DeckUploadButton",true,false)!=null,"desktop deck editor exposes both plaza buttons")
 var original=app.draft.duplicate(true)
 app.open_deck_plaza();await process_frame
 check(app.page=="account" and app.deck_account_return=="list","signed-out plaza entry opens login")
 app.return_from_account();await process_frame
 check(app.page=="editor" and app.dirty and app.draft==original,"returning from login preserves unsaved deck")
 app.upload_current_deck();await process_frame
 check(app.page=="account" and app.deck_account_return=="upload","signed-out upload opens login")
 app.account_client=Account.new();app.add_child(app.account_client);app.account_client.session_token=account.token;app.account_client.nickname=username;app.account_action="login"
 app.account_request_finished(true,"登录成功",username);await process_frame;await process_frame
 check(app.page=="deck_plaza" and app.deck_plaza_ui.mode=="upload","successful login resumes the requested upload")
 var view=app.deck_plaza_ui
 view.tags_input.text="1，2，3，4，5，6，7，8，9，10，11";view.submit_upload()
 check(not view.busy and view.notice.text.contains("十个"),"upload form rejects eleven Chinese-comma tags locally")
 check(Plaza.parse_tags("灵梦，速攻").get("tags",[])==["灵梦","速攻"] and Plaza.parse_tags("灵梦,速攻").has("error"),"tags use Chinese commas")
 view.title_input.text="表单上传";view.description_input.text="表单描述";view.tags_input.text="灵梦，速攻";view.submit_upload();await settled(view)
 check(view.mode=="list" and not view.posts.is_empty(),"successful form upload opens tiled plaza")
 check(view.grid.get_child(0).name.begins_with("PlazaTile"),"plaza displays decks as tiles")
 var color_bar=view.body.find_child("PlazaColorFilters",true,false)
 check(color_bar.get_child(1).size.y<=app.ui_metrics.hit+1 and color_bar.get_child(0).get_global_rect().end.x<=color_bar.get_child(1).get_global_rect().position.x,"desktop color swatches stay at button height without covering the caption")
 view.search_fields.leader.text="灵梦";view.search_fields.tag.text=username;view.search_fields.color_text.text="红黄";view.apply_search();await settled(view)
 print("SEARCH DIAGNOSTIC: notice=",view.notice.text," posts=",view.posts.map(func(p):return {"id":p.id,"nickname":p.nickname,"tags":p.tags,"colors":p.colors})," filters=",view.filters)
 check(view.posts.size()==1 and int(view.posts[0].id)==post_id,"combined leader, tag and text color search finds the deck across the plaza")
 for tags in [username+"，异画"," 异画 , "+username+",异画， "]:
  view.search_fields.tag.text=tags;view.apply_search();await settled(view)
  check(view.posts.size()==1 and int(view.posts[0].id)==post_id,"comma-separated tags require every tag through the actual search form")
 view.search_fields.tag.text=username+",不存在";view.apply_search();await settled(view)
 check(view.posts.is_empty(),"a missing tag excludes the deck even when another tag matches")
 view.search_fields.tag.text=username+",异画";view.apply_search();await settled(view)
 view.toggle_color("黑");await settled(view)
 print("SWATCH DIAGNOSTIC: notice=",view.notice.text," count=",view.posts.size()," filters=",view.filters)
 check(view.posts.is_empty(),"black color swatch excludes decks that lack black")
 view.toggle_color("黑");await settled(view)
 check(view.posts.size()==1,"toggling a color swatch off restores the matching deck")
 view.reset_search();await settled(view)
 await screenshot("res://work/deck-plaza-tests/desktop-plaza.png")
 view.fetch_detail(post_id);await settled(view)
 check(view.mode=="detail" and view.current_post.title=="异画灵梦","tile opens full deck detail")
 var overview=view.body.find_child("PlazaDeckOverview",true,false)
 check(overview!=null and overview.faces.get("70")==app.texture("70","tts_151600"),"plaza displays the original uploader's alternate leader art")
 await screenshot("res://work/deck-plaza-tests/desktop-detail.png")
 view.download_deck()
 var downloaded=app.decks.filter(func(d):return d.name=="异画灵梦")
 check(downloaded.size()==1 and downloaded[0].id!=source.id and downloaded[0].art_overrides==source.art_overrides,"download saves an independent local mdeck with alternate art")
 check(app.dirty and app.draft==original,"download leaves the editing draft intact")
 var pagination_ids=[]
 for i in range(7):
  result=await request(dict_extra(upload,{"title":"分页套牌 %d · 较长的套牌标题用于验证完整单行布局" % i,"tags":["分页验收",username,"较长的标签内容用于检查套牌高度"]}),account.token)
  check(result.get("ok",false),"upload enough decks to cross a server page")
  if result.get("ok",false):pagination_ids.append(int(result.id))
 app.is_android=true;app.layout_dpi_override=360;app.editor();await process_frame;await process_frame
 check(app.screen.find_child("DeckPlazaButton",true,false)!=null and app.screen.find_child("DeckUploadButton",true,false)!=null,"Android editor exposes plaza and upload buttons")
 await screenshot("res://work/deck-plaza-tests/android-editor.png")
 app.open_deck_plaza();view=app.deck_plaza_ui;await settled(view)
 check(not view.posts.is_empty() and view.grid.columns>=1 and view.grid.get_global_rect().end.x<=app.screen.get_global_rect().end.x+1,"Android tiled plaza fits the safe width")
 var plaza_scroll=view.body.find_child("PlazaScroll",true,false) as ScrollContainer
 check(plaza_scroll.size.y>=app.screen.size.y*0.5,"Android plaza reserves at least half the safe height for decks")
 check(not view.color_filters.visible,"Android color filters start collapsed")
 check(view.grid.get_child_count()<=view.grid.columns and plaza_scroll.get_global_rect().grow(1).encloses(view.grid.get_global_rect()),"Android displays a complete deck row without scrolling")
 var page_ids=[]
 while true:
  for tile in view.grid.get_children():page_ids.append(int(str(tile.name).trim_prefix("PlazaTile")))
  if view.next_button.disabled:break
  view.next_button.pressed.emit();await settled(view)
 var unique_ids={}
 for id in page_ids:unique_ids[id]=true
 check(page_ids.size()==9 and page_ids.size()==unique_ids.size(),"Android next page reaches every deck exactly once across cached and server pages")
 check(view.page_label.text=="第 %d / %d 页" % [view.visible_pages(),view.visible_pages()] and view.next_button.disabled,"Android final page reports the total and disables next")
 while not view.previous_button.disabled:
  view.previous_button.pressed.emit();await settled(view)
 check(view.page_index==0 and view.page_offset==0 and view.previous_button.disabled,"Android previous page returns across server pages to the first row")
 plaza_scroll=view.body.find_child("PlazaScroll",true,false) as ScrollContainer
 var search_row=view.body.find_child("PlazaSearch",true,false) as HBoxContainer
 check(search_row.size.y<=app.ui_metrics.hit+10,"Android search occupies one touch-height row")
 for field in view.search_fields.values():
  check(field.size.y>=app.ui_metrics.hit and app.screen.get_global_rect().encloses(field.get_global_rect()),"Android search input keeps its touch target inside the screen")
 var compact_height=plaza_scroll.size.y
 view.search_fields.tag.text="未提交的标签"
 view.toggle_color_filters();await process_frame;await process_frame
 check(view.color_filters.visible and view.search_fields.tag.text=="未提交的标签" and plaza_scroll.size.y<compact_height,"expanding colors preserves typed search and leaves a deck viewport")
 check(plaza_scroll.get_global_rect().grow(1).encloses(view.grid.get_global_rect()),"expanded Android filters keep the complete deck row visible")
 check(app.screen.get_global_rect().grow(1).encloses(view.grid.get_global_rect()) and app.screen.get_global_rect().grow(1).encloses(view.next_button.get_global_rect()),"expanded Android filters keep decks and pagination inside the safe screen")
 await screenshot("res://work/deck-plaza-tests/android-plaza-expanded.png")
 color_bar=view.body.find_child("PlazaColorFilters",true,false)
 check(color_bar.get_child(1).size.y<=app.ui_metrics.hit+1 and color_bar.get_child(0).get_global_rect().end.x<=color_bar.get_child(1).get_global_rect().position.x,"Android color swatches use normal touch height without text overlap")
 view.toggle_color("黑");await settled(view)
 check(view.color_filters.visible and view.color_filter_button.text.contains("1") and "黑" in view.filters.colors,"color filtering preserves its expanded state and exposes the active count")
 view.toggle_color_filters();await process_frame;await process_frame
 check(not view.color_filters.visible and view.color_filter_button.text.contains("1") and "黑" in view.filters.colors,"collapsing colors keeps the active filter visible in the toggle")
 view.reset_search();await settled(view)
 plaza_scroll=view.body.find_child("PlazaScroll",true,false) as ScrollContainer
 check(not view.color_filters.visible and view.color_filter_button.text=="颜色筛选" and view.filters.colors.is_empty(),"clearing filters restores the compact plaza and resets the active count")
 var start=plaza_scroll.get_global_rect().get_center()
 var touch=InputEventScreenTouch.new();touch.index=0;touch.position=start;touch.pressed=true
 root.push_input(touch,true);await process_frame
 check(view.mode=="list","Android tile touch waits for release before opening details")
 for step in range(1,5):
  var drag=InputEventScreenDrag.new();drag.index=0;drag.position=start-Vector2(0,step*30);root.push_input(drag,true);await process_frame
 touch=touch.duplicate();touch.position=start-Vector2(0,120);touch.pressed=false;root.push_input(touch,true);await process_frame
 check(view.mode=="list" and plaza_scroll.scroll_vertical==0,"Android swipe leaves the fixed deck page visible without opening a deck")
 plaza_scroll.scroll_vertical=0;await process_frame
 var tap=InputEventMouseButton.new();tap.button_index=MOUSE_BUTTON_LEFT;tap.position=start;tap.global_position=start;tap.pressed=true
 root.push_input(tap,true);await process_frame
 check(view.mode=="list","Android mouse echo does not open a deck on touch down")
 tap=tap.duplicate();tap.pressed=false;root.push_input(tap,true);await settled(view)
 check(view.mode=="detail","Android short tap still opens the deck on release")
 view.show_list();await process_frame;await process_frame
 await screenshot("res://work/deck-plaza-tests/android-plaza.png")
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 for dimensions in [Vector2i(2340,1080),Vector2i(1280,720)]:
  root.size=dimensions;app.layout_dpi_override=240
  await process_frame;await process_frame
  app.open_deck_plaza();view=app.deck_plaza_ui;await settled(view)
  plaza_scroll=view.body.find_child("PlazaScroll",true,false) as ScrollContainer
  check(plaza_scroll.size.y>=app.screen.size.y*0.6,"Android %s keeps most of the safe height for decks" % dimensions)
  var safe=app.screen.get_global_rect().grow(1)
  var controls=view.search_fields.values()+[view.color_filter_button,view.body.find_child("PlazaSearchButton",true,false),view.body.find_child("PlazaClearSearch",true,false),view.mine_button,view.following_button,view.upload_button,view.refresh_button,view.back_button]
  check(controls.all(func(control):return safe.encloses(control.get_global_rect()) and control.size.y>=app.ui_metrics.hit),"Android %s search controls fit with full touch targets" % dimensions)
  check(view.grid.get_child_count()<=view.grid.columns and plaza_scroll.get_global_rect().grow(1).encloses(view.grid.get_global_rect()) and plaza_scroll.scroll_vertical==0,"Android %s fits a complete deck row without scrolling" % dimensions)
  check(safe.encloses(view.previous_button.get_global_rect()) and safe.encloses(view.next_button.get_global_rect()),"Android %s keeps pagination visible" % dimensions)
  view.toggle_color_filters();await process_frame;await process_frame
  check(plaza_scroll.get_global_rect().grow(1).encloses(view.grid.get_global_rect()),"Android %s expanded filters still fit a complete deck row" % dimensions)
  check(safe.encloses(view.grid.get_global_rect()) and safe.encloses(view.next_button.get_global_rect()),"Android %s expanded filters keep decks and pagination inside the safe screen" % dimensions)
  view.toggle_color_filters();await process_frame;await process_frame
  print("PLAZA_LAYOUT: ",dimensions," safe=",app.screen.size," deck_viewport=",plaza_scroll.size," hit=",app.ui_metrics.hit)
  await screenshot("res://work/deck-plaza-tests/android-plaza-%dx%d.png" % [dimensions.x,dimensions.y])
 root.size=Vector2i(1600,900);app.layout_dpi_override=360
 await process_frame;await process_frame
 app.upload_current_deck();view=app.deck_plaza_ui;await process_frame;await process_frame
 view.title_input.text="保留的上传标题";view.description_input.text="保留的描述";view.tags_input.text="灵梦，测试"
 app.refresh_responsive_layout();await process_frame;await process_frame
 check(view.title_input.text=="保留的上传标题" and view.description_input.text=="保留的描述" and view.tags_input.text=="灵梦，测试","Android reflow preserves the upload form")
 await screenshot("res://work/deck-plaza-tests/android-upload.png")
 app.editor();app.dirty=false;app.open_deck_plaza();view=app.deck_plaza_ui;await settled(view)
 for id in pagination_ids:await request({"action":"delete","id":id},account.token)
 view.toggle_mine();await settled(view)
 check(view.mine and view.posts.size()==2 and view.posts.all(func(p):return p.owned and p.nickname==username and not p.has("username")),"my uploads lists only the signed-in player's posts")
 plaza_scroll=view.body.find_child("PlazaScroll",true,false) as ScrollContainer
 check(plaza_scroll.get_global_rect().grow(1).encloses(view.grid.get_global_rect()),"Android my uploads also fits a complete row")
 await screenshot("res://work/deck-plaza-tests/android-my-uploads.png")
 view.fetch_for_edit(post_id);await settled(view);await process_frame
 check(app.page=="editor" and app.editing_uploaded_deck() and app.draft.main==source.main and app.draft.art_overrides==source.art_overrides,"editing a cloud deck loads its cards and alternate art into the actual editor")
 check(app.screen.find_child("DeckUploadButton",true,false).text=="更新套牌","cloud edit session exposes update rather than a new upload")
 app.selected="103";app.add_to("main")
 app.upload_current_deck();view=app.deck_plaza_ui;await process_frame;await process_frame
 check(view.mode=="edit" and view.description_input.text==upload.description,"editor update retains the original description and tags")
 view.title_input.text="组卡器修改";view.tags_input.text="灵梦，更新";view.submit_upload();await settled(view)
 check(view.mode=="list" and view.mine,"updating a deck returns to my uploads")
 result=await request({"action":"detail","id":post_id},account.token)
 check(result.get("ok",false) and result.deck.title=="组卡器修改" and Store.decode(result.deck.deck_code).deck.main.has("103") and result.deck.colors==["红","绿","黄"],"editor changes update the same cloud deck and recompute its colors")
 if not result.get("ok",false):print("UPDATED DETAIL FAILURE: ",result)
 var other_username=username+"x";print("PLAZA_TEST_USER=",other_username)
 var other=await account_request("register",other_username,"password123!")
 other=await account_request("login",other_username,"password123!")
 if not other.ok:check(false,"other player logs in for ownership checks");print("OTHER LOGIN FAILURE: ",other.message);quit(1);return
 var nickname_client=Account.new();root.add_child(nickname_client);nickname_client.server_url=server_url
 nickname_client.call_deferred("update_nickname","关注作者昵称",other.token);await nickname_client.finished;nickname_client.queue_free()
 var foreign_upload=await request(dict_extra(upload,{"title":"关注作者套牌"}),other.token)
 if not foreign_upload.get("ok",false):check(false,"other author uploads a deck for following");quit(1);return
 var foreign_id=int(foreign_upload.id)
 view.fetch_detail(foreign_id);await settled(view)
 var follow_button=view.body.find_child("PlazaFollowAuthor",true,false)
 var author_label=view.body.find_child("PlazaAuthorNickname",true,false)
 check(follow_button!=null and author_label.text=="上传玩家：关注作者昵称" and not author_label.text.contains(other_username),"follow entry is in deck detail and displays only the author's nickname")
 check(not view.current_post.has("elo") and not view.current_post.has("username") and not view.current_post.has("player_id"),"deck detail does not expose Elo or account ids")
 follow_button.pressed.emit();await settled(view)
 check(view.current_post.following and view.body.find_child("PlazaFollowAuthor",true,false).text=="取消关注作者","detail follow button persists the author follow")
 view.body.find_child("PlazaReturnToList",true,false).pressed.emit();await settled(view)
 check(view.body.find_child("PlazaFollowAuthor",true,false)==null,"following authors is available from detail")
 view.following_button.pressed.emit();await settled(view)
 check(view.following and not view.mine and view.posts.size()==1 and int(view.posts[0].id)==foreign_id,"only-followed filter shows uploaded decks from followed authors")
 app.editor();app.open_deck_plaza();view=app.deck_plaza_ui;await settled(view)
 check(view.following and view.posts.size()==1,"reopening the plaza preserves the only-followed filter")
 view.fetch_detail(foreign_id);await settled(view);view.body.find_child("PlazaFollowAuthor",true,false).pressed.emit();await settled(view)
 view.body.find_child("PlazaReturnToList",true,false).pressed.emit();await settled(view)
 check(view.following and view.posts.is_empty(),"unfollowing refreshes the filtered plaza")
 view.toggle_mine();await settled(view)
 await request({"action":"delete","id":foreign_id},other.token)
 result=await request({"action":"delete","id":post_id},other.token)
 check(not result.get("ok",false) and result.get("message","").contains("只能编辑或删除"),"cloud rejects deletion by another player")
 result=await request(dict_extra(upload,{"action":"edit","id":post_id}),other.token)
 check(not result.get("ok",false) and result.get("message","").contains("只能编辑或删除"),"cloud rejects editing by another player")
 var own_posts=view.posts.filter(func(p):return int(p.id)==post_id)
 if own_posts.is_empty():check(false,"updated deck remains in my uploads");print("MY UPLOADS FAILURE: ",view.notice.text);quit(1);return
 var own_post=own_posts[0]
 view.delete_post(own_post);await process_frame
 var confirmation: ConfirmationDialog=null
 for child in app.get_children():
  if child is ConfirmationDialog:confirmation=child
 check(confirmation!=null,"deleting an upload presents an explicit confirmation")
 if confirmation!=null:confirmation.confirmed.emit();await settled(view)
 result=await request({"action":"detail","id":post_id},account.token)
 check(not result.get("ok",false) and view.posts.size()==1,"owner can delete a post and my uploads refreshes")
 app.deck_login_expired("list","登录已失效，请重新登录");await process_frame
 check(app.page=="account" and app.account_token.is_empty(),"expired cloud login returns to login page")
 print("DECK PLAZA: ",checks," checks; failures=",errors)
 quit(0 if errors.is_empty() else 1)

func dict_extra(original: Dictionary,extra: Dictionary) -> Dictionary:
 var result=original.duplicate(true);result.merge(extra,true);return result
