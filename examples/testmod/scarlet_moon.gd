extends RefCounted
## Scarlet sisters and the lunar treasures use only the public mod context.
func validate(p: Dictionary) -> String:return "" if p.keys().size()==1 else "该能力不接受额外参数"
func id(p: Dictionary) -> String:return p["能力"].get_file()
func refs(ctx,cards: Array) -> Array:return cards.map(func(c):return ctx.ref(c))
func vampire(ctx,c: Dictionary) -> bool:return "吸血鬼" in ctx.info(c.card_id).race
func yellow_green(ctx,c: Dictionary) -> bool:
 var colors=ctx.colors(ctx.ref(c))
 return colors.size()==2 and "黄" in colors and "绿" in colors
func picked(t: Dictionary,index: int=0) -> Array:return t.get("picks",[])[index] if t.get("picks",[]).size()>index else []
func group(pool: Array,title: String,minimum: int=1,private_choice: bool=false) -> Dictionary:
 return {"pool":pool,"min":minimum,"max":1,"title":title,"cost":private_choice,"exclude_previous":true}
func select(groups: Array,key: String="scarlet_moon") -> Array:return [{"selection_id":key,"selection":groups}]
func modifier(key: String,value: Variant,operation: String="set") -> Array:return [{"id":key,"layer":30,"operation":operation,"value":value}]
func describe_action(ctx,p: Dictionary) -> Dictionary:
 var options=[{"none":true}];var who=ctx.controller()
 match id(p):
  "forbidden_game":options=select([group(refs(ctx,ctx.units(who).filter(func(c):return vampire(ctx,c))),"你操控的目标吸血鬼"),group(refs(ctx,ctx.units(1-who)),"对手操控的目标单位")])
  "forbidden_fruits":options=refs(ctx,ctx.units().filter(func(c):return vampire(ctx,c) and ctx.info(c.card_id).kind=="自机"))
  "vlad_curse":options=refs(ctx,ctx.cards_in(who,"grave").filter(func(c):return vampire(ctx,c) and ctx.info(c.card_id).kind in ["单位","自机"]))
  "scarlet_meister":options=ctx.damage_targets()
  "chanting_youka":
   options=[]
   var pool=refs(ctx,ctx.units(who).filter(func(c):return c.uid!=ctx.source().uid and yellow_green(ctx,c)))
   for mode in ["counter","bounce"]:
    options.append({"selection_id":"chanting:"+mode,"mode":"放置两个+1/+1/+1指示物" if mode=="counter" else "移回拥有者手上，你抓两张牌","chant_mode":mode,"selection":[group(pool,"目标其他黄绿双色单位")]})
  "treasure_prepare":
   if ctx.source().card_id=="testmod/dragon_jewel":options=[{"player":0},{"player":1}]
   elif ctx.source().card_id=="testmod/salamander_shield":options=ctx.damage_targets()
 return {"options":options}

func collect_triggers(ctx,ev: Dictionary,p: Dictionary) -> Array:
 match id(p):
  "treasure_prepare","hourai_search":return [{}] if ev.phase=="prepare" and ev.active==ctx.controller() else []
  "treasure_end":return [{}] if ev.phase=="end" and ev.active==ctx.controller() else []
 return [{}]

func get_modifiers(ctx,q: Dictionary,p: Dictionary) -> Array:
 var source=ctx.source();var same=q.get("card",{}).get("uid",-1)==source.uid
 match id(p):
  "treasure_extra":
   if q.kind=="extra_prepare" and q.controller==ctx.controller():return modifier("additional_prepare",1,"add")
  "hourai_chromatic":
   if q.kind=="keyword" and q.keyword=="极彩" and q.card.owner==ctx.controller() and ctx.info(q.card.card_id).kind=="道具":return modifier("chromatic_items",true)
  "curse_permission":
   if q.kind=="character_permission" and same and q.controller==ctx.controller() and ctx.leaders(ctx.controller()).any(func(c):return "蕾米莉亚" in ctx.info(c.card_id).character) and ctx.cards_in(ctx.controller(),"grave").any(func(c):return "蕾米莉亚" in ctx.info(c.card_id).character):return modifier("grave_character",true)
  "night_timing":
   if same and q.kind=="action_lock" and q.action=="cast" and (ctx.phase()!="prepare" or ctx.active_player()!=ctx.controller()):return modifier("prepare_only",true)
   if same and q.kind=="cast_fast":return modifier("prepare_cast",true)
 return []

func resolve(ctx,f: Dictionary,a: Dictionary) -> Dictionary:
 var who=f.owner
 match id(f.params):
  "forbidden_game":
   var first=picked(f.target);var second=picked(f.target,1)
   if not first.is_empty() and not second.is_empty():ctx.fight(first[0],second[0])
   ctx.grant_cast(ctx.ref(f.source),0,true,"grave")
  "forbidden_fruits":
   if f.step==0:ctx.draw(who,3);return {"step":1,"continue":true}
   ctx.force_leader(f.target,3)
  "vlad_curse":
   if f.step==0:ctx.enter(ctx.ref(f.source),3);return {"step":1,"continue":true}
   var anchors=ctx.cards_in(who,"field").filter(func(c):return c.uid==f.source.uid)
   var target=ctx.card(f.target)
   if not anchors.is_empty() and not target.is_empty() and target.zone=="grave":ctx.linked_enter(f.target,ctx.ref(anchors[0]))
  "scarlet_meister":
   if f.step==0:ctx.damage(f.target,6,"dealt");return {"step":1,"continue":true}
   var remaining=int(ctx.result("dealt")) if f.step==1 else int(f.data.get("remaining",0))
   if remaining>0:
    var count=mini(100,remaining);ctx.tokens(who,"testmod/scarlet_bat",count)
    return {"step":2,"continue":true,"data":{"remaining":remaining-count}}
   for c in ctx.units(who):ctx.buff(ctx.ref(c),{"疾行":true})
  "chanting_youka":
   var targets=picked(f.target)
   if not targets.is_empty() and not ctx.card(targets[0]).is_empty() and not targets[0].get("invalid",false):
    if f.target.chant_mode=="counter":ctx.counters(targets[0],2)
    else:ctx.move(targets[0],"hand");ctx.draw(who,2)
  "treasure_prepare":
   match f.source.card_id:
    "testmod/dragon_jewel":ctx.mill(int(f.target.get("player",1-who)),1)
    "testmod/buddha_diamond":ctx.life(who,2)
    "testmod/salamander_shield":ctx.damage(f.target,3)
    "testmod/life_spring":
     if f.step==0:return {"step":1,"choice":[{"none":true,"exile":true,"mode":"移除牌库顶牌，本回合减任意2费使用"},{"none":true,"exile":false,"mode":"不移除"}]}
     if f.step==1:
      if not a.exile:return {"done":true}
      var top=ctx.top(who,1)
      if top.is_empty():return {"done":true}
      ctx.move(ctx.ref(top[0]),"exile");return {"step":2,"continue":true,"data":{"uid":top[0].uid}}
     var exiled=ctx.cards_in(who,"exile").filter(func(c):return c.uid==f.data.uid)
     if not exiled.is_empty():ctx.grant_cast(ctx.ref(exiled[0]),2)
  "treasure_end":ctx.damage({"player":who},3)
  "hourai_search":
   if f.step==0:
    var pool=refs(ctx,ctx.cards_in(who,"deck").filter(func(c):return ctx.info(c.card_id).kind=="道具"))
    return {"step":1,"choice":select([group(pool,"搜寻至多一张道具牌",0,true)],"hourai_search")}
   for target in picked(a):ctx.move(target,"hand")
   ctx.shuffle_deck(who)
  "eternal_night":
   if f.step==0:ctx.draw(who,1);ctx.life(who,5);return {"step":1,"continue":true}
   ctx.end_turn()
 return {"done":true}
