extends RefCounted
## External trusted pack. All state changes go through the engine context.
func validate(p: Dictionary) -> String:return "" if p.keys().size()==1 else "该能力不接受额外参数"
func id(p: Dictionary) -> String:return p["能力"].get_file()
func refs(ctx,cards: Array) -> Array:return cards.map(func(c):return ctx.ref(c))
func picked(t: Dictionary,index: int=0) -> Array:return t.get("picks",[])[index] if t.get("picks",[]).size()>index else []
func group(pool: Array,minimum: int,maximum: int,title: String,private_choice: bool=false) -> Dictionary:
 return {"pool":pool,"min":mini(minimum,pool.size()),"max":mini(maximum,pool.size()),"title":title,"cost":private_choice,"exclude_previous":true}
func selection(groups: Array) -> Array:return [{"selection_id":"testmod_choice","selection":groups}]
func next(step: int,choices: Array,data: Dictionary={}) -> Dictionary:return {"step":step,"choice":choices,"data":data}
func describe_action(ctx,p: Dictionary) -> Dictionary:
 var options=[{"none":true}]
 match id(p):
  "blade","fuel_trigger":options=refs(ctx,ctx.units())
  "recitation":options=refs(ctx,ctx.units(ctx.controller()))
  "ship":options=selection([group(refs(ctx,ctx.units()),0,4,"至多4个目标单位")])
  "sutra":
   var pool=refs(ctx,ctx.cards_in(ctx.controller(),"palette").filter(func(c):return c.tapped))
   var n=int(ctx.event().get("x",0));options=selection([group(pool,n,n,"重置颜色盘")])
  "superhuman":
   options=[]
   for x in range(ctx.x_limit()+1):options.append({"none":true,"x":x,"mode":"X = %d" % x})
 return {"options":options}

func collect_triggers(ctx,ev: Dictionary,p: Dictionary) -> Array:
 match id(p):
  "recitation":return [{}] if ev.phase=="end" and ev.active==ctx.controller() else []
  "sutra":
   var info=ctx.info(ev.card.card_id)
   return [{"x":ev.x}] if ev.controller==ctx.controller() and "绿" in info.colors and not info.variable_cost.is_empty() else []
  "visitor":return [{}] if ev.controller!=ctx.controller() else []
 return [{}]

func get_modifiers(ctx,q: Dictionary,p: Dictionary) -> Array:
 var source=ctx.source();var self_card=q.get("card",{}).get("uid",-1)==source.uid
 match id(p):
  "utsuho_stats":
   if q.kind=="stat" and self_card and q.layer==30:return [{"id":"library","layer":30,"operation":"add","value":-ctx.cards_in(ctx.controller(),"deck").size()}]
   if q.kind=="keyword" and self_card and q.keyword=="疾行":return [{"id":"haste","layer":30,"operation":"set","value":true}]
  "byakuren_guard":
   if q.kind=="target_tax" and q.layer==30 and q.controller!=ctx.controller() and q.targets.any(func(r):return r.get("uid",-1)==source.uid):return [{"id":"target_tax","layer":30,"operation":"add","value":2}]
   if q.kind=="keyword" and self_card and q.keyword=="英勇":return [{"id":"brave","layer":30,"operation":"set","value":true}]
  "resonance":
   if q.kind=="stat" and q.layer==30 and q.card.zone=="field" and q.card.owner==ctx.controller() and ctx.info(q.card.card_id).kind in ["单位","自机"]:return [{"id":"timer_aura","layer":30,"operation":"add","value":source.timer}]
 return []

func get_replacements(ctx,change: Dictionary,p: Dictionary) -> Array:
 if change.owner!=ctx.controller():return []
 match id(p):
  "double_x":
   if change.type=="cast_x" and ctx.active_player()==change.owner and ctx.x_casts(change.owner)==0:return [{"id":"double","optional":true,"x":int(change.x)*2}]
 return []

func resolve(ctx,f: Dictionary,a: Dictionary) -> Dictionary:
 var who=f.owner;var kind=id(f.params)
 match kind:
  "utsuho_enter":
   if f.step==0:
    return next(1,[{"none":true,"mode":"移除牌库顶3张","exile":true},{"none":true,"mode":"不移除牌库顶牌","exile":false}])
   if f.step==1:
    if a.exile:
     for c in ctx.top(who,3):ctx.move(ctx.ref(c),"exile")
    return {"step":2,"continue":true}
   if f.step==2:
    var pool=refs(ctx,ctx.cards_in(who,"exile").filter(func(c):return ctx.info(c.card_id).requires_character=="灵乌路空" and ctx.info(c.card_id).kind=="符卡"))
    return next(3,selection([group(pool,0,1,"将至多一张灵乌路空角色符卡放回牌库",true)]))
   if f.step==3:
    if picked(a).is_empty():return {"done":true}
    return next(4,[{"none":true,"mode":"牌库顶","bottom":false},{"none":true,"mode":"牌库底","bottom":true}],{"card":picked(a)[0]})
   ctx.deck_move(f.data.card,a.bottom)
  "blade":
   if f.step==0:
    ctx.damage(f.target,3)
    return {"step":1,"continue":true}
   if f.step==1:
    var top=refs(ctx,ctx.top(who,4))
    if top.size()<4:
     for r in top:ctx.move(r,"exile")
     return {"done":true}
    return next(2,selection([group(top,3,3,"选择3张移除游戏",true)]),{"top":top})
   for r in f.data.top:
    if r in picked(a):ctx.move(r,"exile")
    else:ctx.deck_move(r,true)
  "ten_stars":
   if f.step==0:
    var top=refs(ctx,ctx.top(who,10));var hand=mini(2,top.size());var palette=mini(2,maxi(0,top.size()-hand))
    return next(1,selection([group(top,hand,hand,"选择入手的牌",true),group(top,palette,palette,"选择横置放入颜色盘的牌",true)]),{"top":top})
   for r in f.data.top:
    ctx.move(r,"hand" if r in picked(a,0) else "palette" if r in picked(a,1) else "exile",r in picked(a,1))
  "rod_enter":
   if f.step==0:ctx.draw(who,1);return {"step":1,"continue":true}
   for c in ctx.top(who,2):ctx.move(ctx.ref(c),"exile")
  "furnace_enter":
   if f.step==0:
    var pool=refs(ctx,ctx.cards_in(who,"exile").filter(func(c):return c.get("original_owner",c.owner)==who and c.card_id in ["testmod/fuel","testmod/control"]))
    return next(1,selection([group(pool,0,2,"将至多两张核燃料棒和／或御制棒洗回牌库",true)]))
   for r in picked(a):ctx.deck_move(r,true)
   if not picked(a).is_empty():ctx.shuffle_deck(who)
  "furnace_trigger":
   var source=ctx.card(ctx.ref(f.source))
   if source.get("zone","")=="exile":ctx.cast_now(ctx.ref(source),true)
  "fuel_trigger":ctx.damage(f.target,3)
  "control_trigger":ctx.tokens(who,"testmod/pillar",1)
  "visitor":ctx.draw(who,1);ctx.life(who,1)
  "recitation":ctx.counters(f.target,int(ctx.card(ctx.ref(f.source)).get("timer",f.source.timer)))
  "sutra":
   for r in picked(f.target):ctx.tap(r,false)
  "ship":
   for r in picked(f.target):ctx.counters(r,int(f.source.get("cast_x",0)))
  "superhuman":
   var x=int(f.source.get("cast_x",f.target.get("x",0)))
   if f.step==0:
    var leaders=ctx.leaders(who).filter(func(c):return c.zone=="leader" and ctx.info(c.card_id).character=="圣白莲")
    if leaders.size()==1:
     ctx.enter(ctx.ref(leaders[0]));return {"step":2,"continue":true}
    if leaders.size()>1:return next(1,refs(ctx,leaders))
    return {"step":2,"continue":true}
   if f.step==1:ctx.enter(a);return {"step":2,"continue":true}
   if f.step==2:
    var units=refs(ctx,ctx.units(who).filter(func(c):return ctx.info(c.card_id).character=="圣白莲"))
    if units.is_empty():return {"done":true}
    return next(3,units)
   ctx.counters(a,x)
   if x>10:ctx.buff(a,{"疾行":true})
 return {"done":true}
