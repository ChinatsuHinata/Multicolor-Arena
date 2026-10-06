extends "res://scripts/tutorial/editor_host.gd"
## Reuse the isolated tutorial editor and its I/O gate for authoring decks.
var on_apply: Callable

func configure(scene_owner,runtime):
 super.configure(scene_owner,runtime)
 tidy_controls()

func tidy_controls(node: Node=self):
 if node is Button:
  var id=Actions.identify(node)
  if id in ["editor.external","editor.export","editor.import","editor.delete"] or node.text in ["套牌广场","上传套牌","卡组截图","打开 deck 文件夹","打开截图文件夹","组卡教程","使用卡组","使用","更多","工具","新建","重命名","清空卡组","删除卡组"]:node.hide()
  elif id=="editor.save":node.set_meta("tutorial_action",id);node.text="应用教学卡组"
  elif id=="editor.return_menu":node.set_meta("tutorial_action",id);node.text="应用并返回"
 for child in node.get_children():tidy_controls(child)

func menu():
 on_apply.call(draft.duplicate(true))

func save_deck():
 menu()

func guard(action: Callable):
 if action.get_method()=="menu":menu()
 else:super.guard(action)

func perform(id: String,args: Dictionary,action: Callable) -> bool:
 if id in ["editor.return_menu","editor.save"]:menu();return true
 return super.perform(id,args,action)
