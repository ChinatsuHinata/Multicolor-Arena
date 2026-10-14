extends "res://tests/support/ui_base.gd"

func frames(count: int=6):
 for i in range(count):await process_frame

func system_back():
 root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
 await frames()

func key(code: int,echo: bool=false):
 var event=InputEventKey.new();event.keycode=code;event.pressed=true;event.echo=echo
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;event.echo=false;root.push_input(event,true)
 await frames()

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/android-system-back/"+str(Time.get_ticks_usec()))
 root.size=Vector2i(1600,900);root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();app.is_android=true
 app.settings_path=Store.Paths.root_override+"/settings.json"
 root.add_child(app);await frames()
 expect(ProjectSettings.get_setting("application/config/quit_on_go_back")==false and not quit_on_go_back,"Android system back cannot trigger the default application exit")
 await system_back();await system_back()
 expect(app.page=="menu" and not quit_on_go_back,"system back on the main menu keeps the game running")

 app.draft=Store.blank("系统返回测试");app.draft.rule_set="test";app.draft.leader="70";app.draft.main=["53"]
 app.dirty=true;app.editor();await frames()
 var before=app.draft.duplicate(true)
 var editor=app.editor_ui
 editor.show_details("53");await frames()
 app.open_menu_popup("测试菜单",[["测试操作",func():pass]]);await frames()
 await system_back()
 expect(not app.menu_popup_open() and is_instance_valid(editor.details_overlay),"one system back closes only the top menu above card details")
 await system_back()
 expect(not is_instance_valid(editor.details_overlay) and app.draft==before and app.dirty and not quit_on_go_back,"next system back closes details and preserves unsaved deck edits")
 app.editor();await frames();await system_back()
 expect(app.page=="editor" and app.draft==before and app.dirty and not quit_on_go_back,"rebuilding the editor never restores automatic exit")

 app.open_editor_deck_picker();await frames();await system_back()
 expect(not app.deck_picker_open() and app.page=="editor" and app.draft==before,"system back cancels the deck picker without choosing or discarding a deck")
 var confirmation={"accepted":false}
 app.confirm_action("放弃修改？",func():confirmation.accepted=true);await frames()
 await system_back()
 expect(not confirmation.accepted and not app.get_children().any(func(child):return child is ConfirmationDialog and child.visible),"system back presses cancel in the focused confirmation dialog")
 expect(app.draft==before and app.dirty,"canceling a confirmation preserves the draft")

 app.load_legacy_test_decks();app.clear_page("battle")
 view=preload("res://scripts/duel_view.gd").new();view.is_android=true
 app.duel_view=view;app.screen.add_child(view);view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 view.begin(app,app.decks[app.player_choice],app.decks[app.ai_choice],0,42)
 view.set_process(false);e=view.engine;clean()
 var hand=put("53","hand");put("53","palette")
 view.render();await settle()
 var battle_before=snapshot()
 view.request_cast(hand.uid);await frames()
 expect(not view.local.is_empty() and view.android_back_button.visible,"selecting a playable card exposes the existing cancel action")
 view.android_back_button.pressed.emit();await frames()
 var button_local=view.local.duplicate(true);var button_selection=view.selection.duplicate()
 expect(button_local.is_empty() and snapshot()==battle_before,"the on-screen cancel abandons the cast without changing game state")
 view.request_cast(hand.uid);await frames();await system_back()
 expect(view.local==button_local and view.selection==button_selection and snapshot()==battle_before,"native back produces the same cast cancellation as the on-screen button")
 view.request_cast(hand.uid);await frames();await key(KEY_BACK,true)
 expect(not view.local.is_empty(),"repeated back key events do not perform extra cancellations")
 await key(KEY_BACK)
 expect(view.local.is_empty() and snapshot()==battle_before,"an Android back key event also cancels the current cast")
 view.request_cast(hand.uid);await frames();await key(KEY_ESCAPE)
 expect(view.local.is_empty() and snapshot()==battle_before,"Android Escape shares the cancel action")
 view.request_cast(hand.uid);await frames()
 var cancel=InputEventAction.new();cancel.action="ui_cancel";cancel.pressed=true
 root.push_input(cancel,true);await frames()
 expect(view.local.is_empty() and snapshot()==battle_before,"ui_cancel itself reaches the battle cancel action")

 view.request_cast(hand.uid);await frames();view.open_tools_menu();await frames()
 await system_back()
 expect(not app.menu_popup_open() and not view.local.is_empty() and snapshot()==battle_before,"system back closes the battle menu without canceling the selection underneath")
 await system_back()
 expect(view.local.is_empty() and snapshot()==battle_before,"the following back cancels the underlying selection")
 view.open_android_help();await frames();await system_back()
 expect(not is_instance_valid(view.modal_root) and not view.modal and snapshot()==battle_before,"system back closes the battle help overlay without changing gameplay")
 var attacker=put("53","field");view.attack_preview_uid=attacker.uid;view.render();await frames()
 battle_before=snapshot();await system_back()
 expect(view.attack_preview_uid==0 and snapshot()==battle_before,"system back cancels an attack preview without declaring the attack")
 await system_back();await system_back()
 expect(app.page=="battle" and not quit_on_go_back and snapshot()==battle_before,"back without an active selection keeps the battle running")
 app.is_android=false;view.is_android=false
 view.selection=[hand.uid];await system_back()
 expect(view.selection==[hand.uid],"desktop ignores the Android native back notification")
 print("ANDROID SYSTEM BACK: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await frames();quit(1 if not failures.is_empty() else 0)
