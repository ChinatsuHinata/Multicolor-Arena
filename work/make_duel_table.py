from pathlib import Path
r=Path(r'C:\Users\tzx20\Documents\test')
s=(r/'scripts/battle_table.gd').read_text(encoding='utf-8-sig')
s=s.replace('signal field_selected(index: int, enemy: bool)','signal object_selected(uid: int)\nsignal avatar_selected(who: int)\nsignal stack_selected(id: int)')
a=s.index('func build(');b=s.index(' texture_provider=provider',a)
s=s[:a]+'''var duel
var reserved: Array=[]
var chosen: Array=[]
func build(engine, provider: Callable, mat_path: String, payment_reservations: Array=[], selection: Array=[]):
 duel=engine
 reserved=payment_reservations
 chosen=selection
'''+s[b:]
a=s.index(' pile("pdeck"');b=s.index('\nfunc plane',a)
s=s[:a]+''' for who in range(2):
  var p=duel.players[who]
  var enemy=who==1
  var z=-1.0 if enemy else 1.0
  var side=-1.0 if enemy else 1.0
  pile("adeck" if enemy else "pdeck",p.deck.map(func(c): return c.card_id),Vector3(9.0*side,0,3.6*z),false,enemy)
  pile("agrave" if enemy else "pgrave",p.grave.map(func(c): return c.card_id),Vector3(9.0*side,0,0.4*z),true,enemy)
  surface_label("牌库",Vector3(9.0*side,0.04,5.15*z),Color("#d3c9b4"))
  surface_label("墓地",Vector3(9.0*side,0.04,1.9*z),Color("#d3c9b4"))
  if p.leader.zone=="leader":
   render_card(p.leader,Vector3(-8.7*side,0.04,3.4*z),enemy)
   if p.leader.timer>0: surface_label("计时 %d" % p.leader.timer,Vector3(-8.7*side,0.2,4.9*z),Color("#e9c871"))
  var unit_index=0
  var groups={}
  for c in p.field:
   if duel.is_unit(c):
    var x=-3.0+unit_index*2.4
    render_card(c,Vector3(x,0.08,0.9*z),enemy)
    surface_label("%d / %d · %d" % [duel.cards[c.card_id].power,duel.cards[c.card_id].health-c.damage,duel.cards[c.card_id].spirit],Vector3(x,0.1,2.13*z),Color("#f2dbac"),0.003)
    unit_index+=1
   else:
    var group=["164","165","167","170"].find(c.card_id)
    var n=groups.get(group,0)
    render_card(c,Vector3(-4.8+group*2.15+n*0.16,0.06+n*0.065,3.3*z),enemy)
    groups[group]=n+1
  var palette=p.palette
  for i in range(palette.size()):
   render_card(palette[i],Vector3(-5.8+(i%8)*1.62,0.08+(i/8)*0.09,5.65*z+(i/8)*0.35*z),enemy,true)
  if p.potato:
   render_card({"uid":-100-who,"card_id":"potato","tapped":false,"owner":who},Vector3(7.0*side,0.09,5.65*z),enemy,true)
  surface_label("人机  %d" % p.life if enemy else "你  %d" % p.life,Vector3(0,0.2,7.35*z),Color("#dbeafa") if enemy else Color("#f6d396"),0.005)
  var avatar=hitbox(Vector3(0,0.3,7.35*z),Vector3(3.2,0.5,0.8))
  avatar.set_meta("kind","avatar"); avatar.set_meta("who",who)
  if enemy:
   surface_label("手牌 %d" % p.hand.size(),Vector3(4.5,0.04,-7.35),Color("#bccbdd"),0.003)
 for i in range(duel.stack.size()):
  var entry=duel.stack[i]
  var id=entry.card.card_id if entry.kind=="card" else entry.source.card_id
  var at=Vector3(6.0+i*0.27,0.8+i*0.23,-0.65-i*0.23)
  var mesh=plane(at,Vector2(2.2,3.08),face_material(id))
  mesh.rotation.x=deg_to_rad(35)
  mesh.rotation.y=deg_to_rad(-8+i*3)
  var area=hitbox(at,Vector3(2.2,0.12,3.08))
  area.rotation=mesh.rotation
  area.set_meta("kind","stack"); area.set_meta("stack_id",entry.id)
 if not duel.stack.is_empty():
  surface_label("对抗  %d" % duel.stack.size(),Vector3(6.2,0.2,2.3),Color("#edd394"),0.004)

func render_card(c: Dictionary,at: Vector3,enemy: bool,palette: bool=false):
 var is_reserved=reserved.any(func(r): return r.uid==c.uid)
 var tapped=c.tapped or is_reserved
 var size=CARD_SIZE*0.8 if palette else CARD_SIZE
 var mesh=plane(at,size,face_material(c.card_id))
 mesh.rotation.y=(PI if enemy else 0.0)+(PI/2 if tapped else 0.0)
 var area=hitbox(at,Vector3(size.x,0.15,size.y))
 area.rotation.y=mesh.rotation.y
 area.set_meta("kind","object"); area.set_meta("uid",c.uid)
 if c.uid in chosen or is_reserved:
  var outline=plane(at-Vector3(0,0.015,0),size+Vector2(0.17,0.17),make_material(Color("#e5bd62")))
  outline.rotation.y=mesh.rotation.y
 if palette:
  var colors=["任意"] if c.card_id=="potato" else duel.cards[c.card_id].colors
  surface_label(" / ".join(colors),at+Vector3(0,0.06,1.03),Color("#e9d6aa"),0.0025)
 if is_reserved: surface_label("预付",at+Vector3(0,0.12,0),Color("#ffe398"),0.003)
'''+s[b:]
a=s.index('    if hit.get_meta("kind"');b=s.index('   return',a)
s=s[:a]+'''    match hit.get_meta("kind",""):
     "object": call_deferred("emit_signal","object_selected",hit.get_meta("uid"))
     "avatar": call_deferred("emit_signal","avatar_selected",hit.get_meta("who"))
     "stack": call_deferred("emit_signal","stack_selected",hit.get_meta("stack_id"))
     "pile": call_deferred("emit_signal","pile_selected",hit.get_meta("zone"))
'''+s[b:]
(r/'scripts/duel_table.gd').write_text(s,encoding='utf-8')
