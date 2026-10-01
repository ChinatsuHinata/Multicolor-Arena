extends SceneTree

var errors=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 if ok:print("PASS: ",label)
 else:errors.append(label);push_error(label)
func run():
 var app=load("res://main.tscn").instantiate();root.add_child(app)
 await process_frame
 app.account_name="sample_user";app.account_nickname="云端玩家";app.account_token="f".repeat(64)
 app.online();await process_frame
 var lobby=app.screen.get_node_or_null("./LanLobby")
 if lobby==null:
  for child in app.screen.get_children():
   if child.get_script()!=null and child.get_script().resource_path=="res://net/lan_lobby.gd":lobby=child;break
 check(lobby!=null,"online lobby opens")
 if lobby==null:quit(1);return
 lobby.set_cloud_mode(true);lobby.cloud_directory.stop();await process_frame
 check(lobby.cloud_selected and lobby.cloud_title_input!=null and lobby.cloud_password_input.secret,"cloud switch shows room creation and password fields")
 lobby.cloud_directory.rooms=[{"id":"ABCDEF123456","name":"云端玩家的房间","owner":"云端玩家","locked":true,"format":3,"status":"lobby","version":lobby.session.fingerprint,"seats":["云端玩家","","","","","","",""]}]
 lobby.refresh_cloud_rooms();await process_frame
 check(lobby.cloud_rooms_list.get_child_count()==1,"cloud directory shows room")
 var grid=lobby.cloud_rooms_list.get_child(0).get_child(0).get_child(1) as GridContainer
 check(grid!=null and grid.get_child_count()==8 and grid.get_child(0).disabled and not grid.get_child(7).disabled,"eight seats show occupancy and available spectator seat")
 print("CLOUD UI: ",errors.size()," failures")
 quit(0 if errors.is_empty() else 1)
