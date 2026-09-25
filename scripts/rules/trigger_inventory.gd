extends RefCounted
## Printed MAIN triggered abilities. Static, replacement and activated abilities are excluded.
## Multiple trigger conditions in one ability still create one instance (FDF-065).
const MAIN_ROSTER=["letty_freeze","dai_search","medicine_kill","luna_life","mystia_life","hatate_replace","komachi_exile","star_destroy","seiga_death","akyuu_counter","keiki_copy","chen_counter","meiling_spell","seiga_imp","nazrin_draw","kyouko_shuffle","hourai_ping","koishi_coin","satori_scry","shanghai_draw","kanako_pillar","suika_attack","suwako_top","character-fdf-046","character-fdf-065","character-fdf-069","character-fdf-091","character-fdf-092","character-fdf-093","character-fdf-094","character-fdf-100","character-fdf-103","character-fdf-104","character-fdf-105","character-fdf-110","character-fdf-114","character-fdf-117","character-fdf-119","character-fdn-004","character-fdn-021","character-fdn-024","character-fdn-025","character-fdn-026","character-fdn-034","character-fdn-035","character-fdn-036","character-fdn-037","character-fdn-038","character-fdn-042","character-fdn-045","lily_color","kokoro_mood","character-htk-005","komachi_minus","character-lof-002","larva_sacrifice","shinmy_cast","character-ucs-003","character-ucs-016","character-ucs-020","character-ucs-021","character-ucs-023","character-ucs-025","sakuya_timer","character-ucs-034","character-ucs-036","orin_discard","parsee_catchup","character-ucs-044","character-ucs-056","miko_divide","kogasa_scare","kanako_cast","character-ucs-073","n21:ETO-001","n21:ETO-002","n21:ETO-003","n21:LOC-001","n21:SPX-005"]
const MAIN_PRECON=["miyoi_wine","mike_swap","eirin_return","yukari_blink","byakuren_x","tenshi_tap","marisa_untap","patch_exchange","seiran_exile","koakuma_palette","tokiko_search","marisa_search","patch_topthree","tewi_counters","kosuzu_destroy","sand_add","shou_shield","larva_draw","ramp_enter","oni_attack"]
const MAIN_EXTENSION=["enter_haste","enter_drain","enter_grave_damage","enter_sweep","enter_color_evasion","enter_blink","enter_fight","enter_palette_replace","enter_unblockable","enter_halfghost","leave_ufo","death_draw_life","death_drain","death_palette","death_damage","death_poverty","death_six","death_undying","death_devour","hand_autumn"]
static func force(e,who):
 for c in e.units(who).duplicate():
  var info=e.cards[c.card_id];var templates=[]
  for binding in info.abilities:
   var handler=binding.get("实现","");var k=binding.get("参数",{}).get("效果",handler)
   if handler=="roster" and k in MAIN_ROSTER:templates.append({"family":"roster","effect":k})
   if handler=="roster" and k=="character-fdf-109":templates.append({"family":"roster","effect":k})
   if handler=="roster" and k=="character-lof-004":templates.append({"family":"roster","effect":k})
   if handler=="roster" and k=="character-fdf-106":
    templates.append({"family":"roster","effect":k,"data":{"event":"enter"}})
    templates.append({"family":"roster","effect":k,"data":{"event":"death"}})
   if handler=="roster" and k=="character-fdf-101":templates.append({"family":"roster","effect":"cat:momiji_name"})
   if handler=="precon" and k in MAIN_PRECON:templates.append({"family":"precon","effect":k})
   if handler=="precon" and k=="sanae_end":templates.append({"family":"precon","effect":k})
   if handler=="extension" and k in MAIN_EXTENSION:templates.append({"family":"extension","effect":k})
   if handler=="marisa_enter":templates.append({"family":"demo","amount":int(binding.get("参数",{}).get("数值",1))})
  if "结晶" in info.get("keywords",[]):templates.append({"family":"extension","effect":"crystal"})
  # These properties may be granted to a unit by another resolved card.
  if c.get("drunk_counters",0)>0:templates.append({"family":"roster","effect":"n21:drunk_bottom"})
  if c.get("imp_growth",false):templates.append({"family":"roster","effect":"cat:imp_growth"})
  if c.has("rank_target"):templates.append({"family":"roster","effect":"cat:rank_death"})
  for repeat in range(2 if e.Cat.character(e,c,"秦心") else 1):
   for template in templates:
    var k=template.get("effect","")
    var data={"ref":e.ref_target(c),"power":e.stat(c,"power"),"x":int(c.get("cast_x",0)),"player":1-who,"owner":who,"value":0,"amount":0,"event":"forced"}
    data.merge(template.get("data",{}),true)
    if template.family=="demo":e.queue_trigger(who,c,template.amount,"主要触发能力");continue
    # Event-dependent recipients do not exist when triggering without an event.
    # Keep the trigger on the stack; it resolves with no event-derived damage target.
    if k in ["medicine_kill","komachi_minus","character-fdn-035"]:
     var first=e.triggers.size()
     e.Roster.event(e,c,"n21:event_without_recipient",optional(e,c,k),data)
     for i in range(first,e.triggers.size()):e.triggers[i].ability_text=e.Roster.text(e.cards[c.card_id],k)
     continue
    if k=="character-fdn-042":k="cat:utsuho_return"
    if template.family=="roster":e.Roster.event(e,c,k,optional(e,c,k),data)
    elif template.family=="precon":e.Pack.event(e,c,k,optional(e,c,k),data)
    else:e.Extra.event(e,c,k,optional(e,c,k),data)
static func optional(e,c,key):
 for binding in e.cards[c.card_id].abilities:
  if binding.get("参数",{}).get("效果","")==key:return "可以" in binding.get("名称","")
 return key in ["crystal","leave_ufo","death_undying","cat:utsuho_return"]
