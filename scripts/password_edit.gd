extends LineEdit

func _init():
 secret=true
 virtual_keyboard_type=LineEdit.KEYBOARD_TYPE_PASSWORD

func _notification(what: int):
 # LineEdit reopens the desktop IME when drawing its caret, so also close it
 # after redraws and composition updates, not only when focus first enters.
 if what in [NOTIFICATION_FOCUS_ENTER,NOTIFICATION_DRAW,NOTIFICATION_WM_WINDOW_FOCUS_IN,MainLoop.NOTIFICATION_OS_IME_UPDATE] and is_inside_tree() and has_focus():
  cancel_ime()
