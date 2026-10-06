extends "res://scripts/tutorial/sequence.gd"
const Commands=preload("res://scripts/tutorial/battle_commands.gd")
var executing=false

func waiting_student(config: Dictionary) -> bool:
 return playing and index<config.actions.size() and config.actions[index].get("player",-1)==int(config.get("student",0))

func permits(adapter,config: Dictionary,seat: int,command: Dictionary) -> bool:
 if executing or not playing:return true
 if not waiting_student(config) or seat!=int(config.get("student",0)):return false
 var action=Commands.encode(adapter,seat,command)
 return not action.is_empty() and Commands.matches(adapter,config.actions[index],action)

func accepted(config: Dictionary,seat: int):
 if not executing and waiting_student(config) and seat==int(config.get("student",0)):
  index+=1;delay_remaining=ACTION_PAUSE_SECONDS

func tick_interactive(adapter,config: Dictionary,delta: float,busy: bool) -> String:
 if waiting_student(config):return ""
 executing=true
 var reason=super.tick(adapter,config,delta,busy,true)
 executing=false
 return reason
