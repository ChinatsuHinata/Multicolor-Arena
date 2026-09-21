from pathlib import Path
import shutil,re
R=Path(__file__).resolve().parents[1];O=R/'work/v014';O.mkdir(exist_ok=True)
B=R/'work/v014-backup';B.mkdir(exist_ok=True)
for rel in ['scripts','tests','docs','saves','data','开发者日志.md','使用说明.md']:
 p=R/rel;q=B/rel
 if not q.exists():
  if p.is_dir():shutil.copytree(p,q)
  else:shutil.copy2(p,q)
def edit(rel,fn):
 p=R/rel;s=p.read_text(encoding='utf-8-sig');p.write_text(fn(s),encoding='utf-8')
def engine(s):
 s=s.replace('var catalogue_retargeting=false','var catalogue_retargeting=false\nvar presentation_events: Array=[]\nvar reveal_serial=0')
 marker='func history_art(c: Dictionary) -> Array:'
 s=s.replace(marker,'''func reveal_card(c: Dictionary,edge: String=""):
 if c.is_empty(): return
 reveal_serial+=1
 presentation_events.append({"type":"reveal","serial":reveal_serial,"card":c.duplicate(true),"edge":edge})
 record_history("展示 · "+cards[c.card_id].name,history_art(c))
 revision+=1

'''+marker)
 s=s.replace('forced_cast={};extra_turns=[]','forced_cast={};extra_turns=[];presentation_events.clear();reveal_serial=0')
 s=s.replace('var shown=find_card(r.uid); record_history("展示 · "+cards[shown.card_id].name,history_art(shown))','var shown=find_card(r.uid); reveal_card(shown)')
 s=s.replace(' Extra.on_enter(self,c)\n return true\nfunc to_grave', ' replace_melody(c)\n Extra.on_enter(self,c)\n return true\nfunc is_melody(c: Dictionary) -> bool:\n return not c.is_empty() and "乐章" in cards[c.card_id].get("spell_type","")\nfunc replace_melody(incoming: Dictionary,silent: bool=false):\n if not is_melody(incoming): return\n # 2.34f: a rule action, never a destroy effect or a separate stack object.\n for old in (players[0].field+players[1].field).duplicate():\n  if old.uid==incoming.uid or not is_melody(old): continue\n  note("规则动作 · 乐章替换 · "+cards[old.card_id].name,history_art(old))\n  history.back().rule_action=true\n  if silent:\n   detach(old);old.owner=old.get("original_owner",old.owner);shift(old,"grave");players[old.owner].grave.append(old)\n  else: move_to(old,"grave",false)\nfunc to_grave')
 s=s.replace('c.timer=int(cards[c.card_id].get("time",0))\n passes=0','c.timer=int(cards[c.card_id].get("time",0));replace_melody(c,true)\n passes=0')
 return s
edit('scripts/rules/duel_engine.gd',engine)
for rel in ['scripts/rules/precon_abilities.gd','scripts/rules/excel_abilities.gd','scripts/rules/catalogue_abilities.gd']:
 def reveal(s):
  s=re.sub(r'e.record_history\("展示 · "\+e.cards\[(\w+)\.card_id\].name,e.history_art\(\1\)\)',r'e.reveal_card(\1)',s)
  if rel.endswith('catalogue_abilities.gd'):s=s.replace('e.reveal_card(c)','e.reveal_card(c,"top" if from_top else "bottom" if c.zone=="deck" else "")')
  if rel.endswith('precon_abilities.gd'):
   s=s.replace('   if k=="scarlet_anthem":\n    for c in (e.players[0].field+e.players[1].field).duplicate():\n     if "乐章" in e.cards[c.card_id].get("spell_type",""): e.move_to(c,"grave")\n','')
  if rel.endswith('excel_abilities.gd'):
   s=s.replace('e.players[who].field.append(c);entered.append(c)','e.players[who].field.append(c);e.replace_melody(c);entered.append(c)')
  return s
 edit(rel,reveal)

def table(s):
 s=s.replace('const SLOT_SCALE=0.82','const SLOT_SCALE=0.82\nconst FIELD_SCALE=0.76\nconst NEAREST_CAMERA=0.77')
 s=s.replace('var camera_distance=1.02','var camera_distance=NEAREST_CAMERA')
 s=s.replace('func set_camera():\n camera.position','func set_camera():\n camera_distance=NEAREST_CAMERA\n camera.position')
 s=s.replace('Vector3(0,0,0.5)','Vector3(0,0,0)')
 s=s.replace('"palette": return Vector3(0,0.035,5.7*side)','"palette": return Vector3(0,0.035,6.8*side)')
 start=s.index('  var unit_index=0');end=s.index(' for i in range(duel.stack.size()):',start)
 s=s[:start]+'''  var groups={"unit":[],"item":[],"support":[],"melody":[]}
  for c in p.field:
   groups[field_group(c)].append(c)
  for group in groups:
   var list=groups[group]
   for i in range(list.size()):
    var c=list[i];var at=field_position(group,i,list.size(),who)
    var d=description(c,at,FIELD_SCALE)
    d.group=group
    if group in ["support","melody"]:d.rotation.y+=PI/2
    if c.uid in chosen:d.at.y+=0.055
    result[d.key]=d
  for i in range(p.palette.size()):
   var stride=minf(1.86,13.02/maxi(1,p.palette.size()-1))
   var d=description(p.palette[i],Vector3((-6.51+i*stride)*side,0.035+i*0.002,6.8*side),FIELD_SCALE)
   result[d.key]=d
  if p.potato:
   var c={"uid":-100-who,"card_id":"potato","owner":who,"zone":"palette","tapped":false}
   var d=description(c,Vector3(-7.95*side,0.035,6.8*side),0.52);result[d.key]=d
'''+s[end:]
 marker='func sync(payment_reservations:'
 pos=s.index(marker)
 s=s[:pos]+'''func field_group(c: Dictionary) -> String:
 if duel.is_unit(c):return "unit"
 if duel.is_melody(c):return "melody"
 return "item" if duel.cards[c.card_id].kind=="道具" else "support"
func field_position(group: String,index: int,count: int,who: int) -> Vector3:
 var side=1.0 if who==0 else -1.0
 var at=Vector3.ZERO
 match group:
  "unit":at=Vector3(-6.4+index*minf(2.56,12.8/maxi(1,count-1)),0.035+index*0.002,1.55)
  "item":at=Vector3(-6.35+(index%4)*1.76,0.035+(index/4)*0.025,4.3+(index/4)*0.22)
  "support":at=Vector3(1.35+(index%3)*2.3,0.035+(index/3)*0.025,4.3+(index/3)*0.22)
  "melody":at=Vector3(9.2,0.04,0)
 at.x*=side;at.z*=side
 return at

'''+s[pos:]
 s=s.replace('  camera_distance=clampf(camera_distance+(-0.025 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 0.025),0.77,1.18)\n  set_camera(); return','  return')
 s=s.replace('if depth>=4.65 and depth<=7.35: return "palette"','if depth>=5.65 and depth<=7.95: return "palette"').replace('if depth>=0.25 and depth<4.65: return "field"','if depth>=0.1 and depth<5.65: return "field"')
 s=s.replace(' var depth=at.z*(1 if owner==0 else -1)',' if absf(at.x-(9.2 if owner==0 else -9.2))<1.2 and absf(at.z)<1.0:return "field"\n var depth=at.z*(1 if owner==0 else -1)')
 return s
edit('scripts/duel_table.gd',table)

def view(s):
 s=s.replace('const STAGE=Rect2(246,100,1030,558)','const STAGE=Rect2(246,112,1108,546)')
 s=s.replace('const HAND=Rect2(246,663,1030,232)','const HAND=Rect2(246,663,1108,232)')
 s=s.replace('const SIDEBAR=Rect2(1290,163,294,477)','const SIDEBAR=Rect2(1366,100,218,660)\nconst INSPECTION=Rect2(16,100,218,660)\nvar reveal_player')
 s=s.replace('inspection.position=Vector2(16,100); inspection.size=Vector2(218,660)','inspection.position=INSPECTION.position; inspection.size=INSPECTION.size')
 s=s.replace(' banner=layer(ui)',' reveal_player=preload("res://scripts/duel_reveal.gd").new();reveal_player.view=self;ui.add_child(reveal_player)\n banner=layer(ui)')
 s=s.replace('func stage_input(event: InputEvent):\n if table.combat_animating:', 'func stage_input(event: InputEvent):\n if revealing():return\n if table.combat_animating:')
 s=s.replace('func _process(delta):\n if engine==null: return','func _process(delta):\n if engine==null: return\n if not engine.presentation_events.is_empty() or revealing():\n  render();return')
 s=s.replace('func render():\n if not is_instance_valid(ui): return','func revealing() -> bool:\n return is_instance_valid(reveal_player) and reveal_player.busy\nfunc render():\n if not is_instance_valid(ui): return\n if is_instance_valid(reveal_player):\n  if not engine.presentation_events.is_empty():\n   reveal_player.enqueue(engine.presentation_events);engine.presentation_events.clear()\n  if revealing():return')
 s=s.replace('func _input(event: InputEvent):\n','func _input(event: InputEvent):\n if revealing():\n  get_viewport().set_input_as_handled();return\n')
 s=s.replace('func txt(text: String,rect: Rect2,font: int=18,color: Color=Color("#e8edf0"),parent: Node=null):\n','func right_rect(rect: Rect2) -> Rect2:\n if rect.position.x>=1290:\n  rect.position.x=SIDEBAR.position.x+(rect.position.x-1290)*218.0/294.0\n  rect.size.x*=218.0/294.0\n return rect\nfunc txt(text: String,rect: Rect2,font: int=18,color: Color=Color("#e8edf0"),parent: Node=null):\n if parent==null:rect=right_rect(rect)\n')
 s=s.replace('func btn(text: String,rect: Rect2,action: Callable,accent: bool=false,parent: Node=null):\n','func btn(text: String,rect: Rect2,action: Callable,accent: bool=false,parent: Node=null):\n if parent==null and rect.position.y>=90:rect=right_rect(rect)\n')
 s=s.replace('var target=Vector2(261+i*stride,680) if who==0 else Vector2(760-', 'var target=Vector2(HAND.position.x+15+i*stride,680) if who==0 else Vector2(STAGE.get_center().x-')
 s=s.replace('950.0/maxi(1,cards.size())','(HAND.size.x-80)/maxi(1,cards.size())')
 s=s.replace('root.visible=root.position.x>292 and root.position.y>140 and root.position.y<(790 if parts.zone=="stack" else 635)','root.visible=STAGE.grow(5).has_point(root.position) or parts.zone=="stack" and root.position.y<790')
 s=s.replace('var signature=inspect_id+str(inspect_uid)+inspect_caption+str(enabled)+str(current.get("courage",0))+str(current.get("moods",[]))','var counters=counter_lines(current)\n var signature=inspect_id+str(inspect_uid)+inspect_caption+str(enabled)+str(counters)+str(current.get("moods",[]))')
 s=s.replace(' if current.get("courage",0)>0:inspection_text.add_text("\\n勇气等级：%d" % current.courage)',' for line in counters:inspection_text.add_text("\\n"+line)')
 marker='func render_prompt():'
 s=s.replace(marker,'''func counter_lines(c: Dictionary) -> Array:
 var lines=[]
 for k in ["plus_counters","minus_counters","leader_counters","timer","poverty","scare","courage","dream","madness"]:
  var n=int(c.get(k,0))
  if n<=0:continue
  if k=="plus_counters":lines.append("属性指示物：+%d/+%d/+%d" % [n,n,n])
  elif k=="minus_counters":lines.append("属性指示物：-%d/-%d" % [n,n])
  else:
   var names={"leader_counters":"自机","timer":"计时","poverty":"贫穷","scare":"惊吓","courage":"勇气等级","dream":"梦违","madness":"狂乱"}
   lines.append(names[k]+"："+str(n))
 var colors=c.get("color_counters",[])
 for color in engine.COLORS:
  if colors.count(color)>0:lines.append(color+"色指示物："+str(colors.count(color)))
 for name in c.get("counters",{}):
  if c.counters[name]!=0:lines.append(str(name)+"："+str(c.counters[name]))
 return lines

'''+marker)
 s=s.replace('Rect2(12,10,212,35),20','Rect2(10,10,158,35),18').replace('Rect2(242,10,40,32)','Rect2(174,10,34,32)')
 s=s.replace('Vector2(104,34)','Vector2(76,34)').replace('Vector2(122,49)','Vector2(92,49)').replace('Vector2(160,34)','Vector2(116,34)')
 s=s.replace('Vector2(278,SIDEBAR.size.y-top-8)','Vector2(SIDEBAR.size.x-16,SIDEBAR.size.y-top-8)')
 s=s.replace('browser_cards.columns=3','browser_cards.columns=2').replace('Vector2(83,117)','Vector2(91,129)').replace('Rect2(0,0,83,116)','Rect2(0,0,91,128)')
 s=s.replace('Rect2(110,top+35,60,35)','Rect2(80,top+35,60,35)')
 return s
edit('scripts/duel_view.gd',view)
print('v0.14 backups and edits written')
