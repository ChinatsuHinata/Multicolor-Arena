extends "res://scripts/tutorial/runtime.gd"
## Recording observes the private native host without advancing a lesson.
var recorder

func authorize_ui_action(id: String,_args: Dictionary) -> bool:
 return id in preload("res://scripts/tutorial/ui_actions.gd").ALLOWED and not recorder.replaying and (recorder.points.is_empty() or recorder.recording) and recorder.actions.size()<600

func ui_action_applied(id: String,args: Dictionary):
 adapter.last_ui_action={"id":id,"args":args.duplicate(true)}
 recorder.accepted(id,args)

func reject_ui_action(_id: String,_args: Dictionary,detail: String=""):
 if not detail.is_empty():task_failed.emit(detail)

func tick(_delta: float=1.0/60.0):
 pass
