extends "res://tests/test_v092.gd"
func run():
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 clean()
 for id in ["50","51","52","53"]:put(id,"hand")
 for id in ["50","51","52","53"]:put(id,"hand",1)
 for i in range(15):put("50","deck");put("51","deck",1)
 view.render();await settle()
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/v0151/card-back-and-hand.png")
 view.hand_nodes[e.players[0].hand[0].uid].update_style(true,false)
 view.hand_nodes[e.players[0].hand[1].uid].update_style(true,true)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/v0151/hand-highlights.png")
 print("Card back loaded: ",app.texture("back").resource_path)
 quit()
