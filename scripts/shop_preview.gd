extends Control
## A presentation-only board: no DuelView, command gateway, AI, match recorder
## or inventory writes. Only the explicit preview controls receive input.
signal closed
const Duel=preload("res://scripts/rules/duel_engine.gd")
const Table=preload("res://scripts/duel_table.gd")
const Store=preload("res://scripts/deck_store.gd")
const Profiles=preload("res://scripts/rules/leader_emotes.gd")
const Bubble=preload("res://scripts/emote_bubble.gd")
const Icon=preload("res://scripts/emote_icon.gd")
const Registry=preload("res://fx/fx_registry.gd")
const Stage=preload("res://fx/fx_stage.gd")
const KINDS=["greeting","praise","mistake","surprise","threat","surrender"]
const LOOP_GAP=0.8
var host
var item: Dictionary
var engine
var table
var viewport: SubViewport
var surface: TextureRect
var stage
var subject: Dictionary
var spell_target: Dictionary={}
var header: HBoxContainer
var title: Label
var hint: Label
var exit_button: Button
var emote_bar: HBoxContainer
var bubble: Control
var bubble_remaining=0.0
var loop_remaining=0.0
var entrance_landing=Transform3D.IDENTITY
var entrance_from=Transform3D.IDENTITY
var entrance_elapsed=0.0
var entrance_duration=0.0
var entrance_ease="cubic_in_out"
var entrance_flying=false
var entrance_proxy=false
var effect_available=false
var closing=false
var touch_button: Button
var touch_finger=-1
var suppress_mouse_until=0

static func supports(product: Dictionary) -> bool:
 return str(product.get("category","")) in ["emotes","entrance","spell"]

func build(app,product: Dictionary):
 host=app;item=product.duplicate(true);name="ShopPreview"
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter=Control.MOUSE_FILTER_STOP
 var background=ColorRect.new();background.color=Color("#120d1b");add_child(background)
 background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 background.mouse_filter=Control.MOUSE_FILTER_IGNORE
 viewport=SubViewport.new();viewport.own_world_3d=true
 viewport.transparent_bg=true
 viewport.physics_object_picking=false;viewport.gui_disable_input=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.msaa_3d=Viewport.MSAA_4X
 add_child(viewport)
 surface=TextureRect.new();surface.name="PreviewBattlefield";add_child(surface)
 surface.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;surface.stretch_mode=TextureRect.STRETCH_SCALE
 surface.texture=viewport.get_texture();surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
 make_board()
 header=HBoxContainer.new();add_child(header)
 title=Label.new();header.add_child(title);title.text="预览 · "+str(item.get("name",""))
 title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 title.add_theme_color_override("font_color",host.GOLD);title.mouse_filter=Control.MOUSE_FILTER_IGNORE
 exit_button=host.button(header,"退出预览",Rect2(),func():closed.emit())
 exit_button.name="ExitShopPreview"
 hint=Label.new();add_child(hint);hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
 hint.add_theme_color_override("font_color",host.WHITE)
 emote_bar=HBoxContainer.new();emote_bar.name="PreviewEmotes";add_child(emote_bar)
 if item.category=="emotes":
  hint.text="点击表情，自由试用对话 · 无冷却"
  for kind in KINDS:
   var button=host.button(emote_bar,Profiles.LABELS[kind],Rect2(),show_emote.bind(kind))
   button.name="PreviewEmote_"+kind;button.icon=Icon.texture(kind,24)
   button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 else:
  emote_bar.hide();configure_effect()
 relayout();resized.connect(relayout)
 var controls: Array[Control]=[exit_button]
 for button in emote_bar.get_children():controls.append(button)
 for index in range(controls.size()):
  var previous=controls[index].get_path_to(controls[(index-1+controls.size())%controls.size()])
  var next=controls[index].get_path_to(controls[(index+1)%controls.size()])
  controls[index].focus_previous=previous;controls[index].focus_next=next
  controls[index].focus_neighbor_left=previous;controls[index].focus_neighbor_right=next
  controls[index].focus_neighbor_top=previous;controls[index].focus_neighbor_bottom=next
 exit_button.grab_focus()

func make_board():
 engine=Duel.new(Store.CARDS);engine.configure_mods(false)
 # Construct static players directly: starting a real match would draw cards,
 # invoke leader abilities and initialize task probes.
 var leader_id=str(item.get("leader_id","character-rei-001"))
 if not engine.cards.has(leader_id):leader_id="character-rei-001"
 for who in range(2):
  var id=leader_id if who==0 else "character-mar-ex" if leader_id=="character-rei-001" else "character-rei-001"
  var leader=engine.make_card(id,who,"field" if who==0 else "leader",true)
  leader.entered=-1
  engine.players.append({"life":20,"deck":[],"hand":[],"field":[leader] if who==0 else [],"palette":[],"grave":[],"exile":[],"leader":leader,"potato":false,"mulligan_done":true,"turns":1})
 engine.phase="main";engine.active=0;engine.priority=0;engine.turn=1
 subject=engine.players[0].leader
 if item.category in ["entrance","spell"]:
  var card_id=str(item.get("card_id",leader_id if item.category=="entrance" else "spell-fdf-017"))
  if not engine.cards.has(card_id):card_id=leader_id if item.category=="entrance" else "spell-fdf-017"
  if item.category=="spell" or card_id!=leader_id:
   engine.players[0].leader.zone="leader";engine.players[0].field.clear()
   var zone="palette" if item.category=="spell" else "field"
   subject=engine.make_card(card_id,0,zone);subject.entered=-1;engine.players[0][zone].append(subject)
  if item.category=="spell":
   var leader=engine.players[0].leader;leader.zone="field";engine.players[0].field.append(leader)
   spell_target=engine.make_card("character-mar-ex",1,"field");spell_target.entered=-1;engine.players[1].field.append(spell_target)
 for who in range(2):engine.leader_emote_profiles.append(Profiles.make_profile(engine,who))
 table=Table.new();viewport.add_child(table)
 table.condition_hint_provider=func(_card):return false
 table.build(engine,host.texture,host.battlefield_background)
 table.set_top_down_view(host.top_down_view)
 # Units land in the center; spell cards sit sideways along the right edge.
 var node=subject_node()
 node.position=Vector3(0,0.04,1.8);node.scale=Vector3.ONE*1.15
 entrance_landing=node.global_transform
 if not spell_target.is_empty():
  table.visuals["card_"+str(engine.players[0].leader.uid)].position=Vector3(-2.4,0.04,1.4)
  table.visuals["card_"+str(spell_target.uid)].position=Vector3(1.8,0.04,-1.5)
  node.position=Vector3(5.5,0.04,1.4)
  node.rotation.y=PI/2
 table.camera_distance=0.62;table.top_down_camera_size=12.0;table.set_camera()

func subject_node() -> Node3D:
 return table.visuals.get("card_"+str(subject.uid))

func configure_effect(registry=null):
 entrance_flying=false
 if is_instance_valid(stage):stage.stop_all();stage.queue_free()
 var source=registry if registry!=null else Registry.new()
 source.reload()
 var selected=Registry.new();selected.loaded=true;selected.allow_all=true
 var bound=str(item.get("fx",""))
 if bound.is_empty():bound=str(item.id)
 for definition in source.by_category(str(item.category)):
  if str(definition.id)==bound or str(definition.get("shop_product",""))==bound:
   selected.definitions[definition.id]=definition.duplicate(true)
 stage=Stage.new();stage.use_registry(selected);table.add_child(stage)
 # One preview clock keeps the flying card, its effects and landing in sync.
 stage.auto_step=true;stage.set_process(false)
 effect_available=not selected.definitions.is_empty()
 hint.text="入场特效循环播放" if item.category=="entrance" else "符卡特效循环播放"
 if effect_available:play_effect()
 else:hint.text="此商品的特效暂不可预览"

func play_effect():
 stage.clear()
 loop_remaining=LOOP_GAP
 if item.category=="entrance":
  play_entrance()
  return
 var node=subject_node()
 var context={"parent":null,"node":node,"center":node.global_position,"card_size":Table.CARD_SIZE,"uid":subject.uid,"card_id":subject.card_id}
 if item.category=="spell":
  var leader=engine.players[0].leader;var leader_info=engine.cards[leader.card_id]
  context.merge({"owner":0,"requires_character":engine.cards[subject.card_id].get("requires_character",""),"palette_character_spells":engine.players[0].palette.filter(func(card):return not str(engine.cards[card.card_id].get("requires_character","")).is_empty()).size(),"units":[{"uid":leader.uid,"owner":0,"card_id":leader.card_id,"character":leader_info.get("character",""),"kind":leader_info.kind,"deck_leader":true,"position":table.visuals["card_"+str(leader.uid)].global_position}],"targets":[{"uid":spell_target.uid,"position":table.visuals["card_"+str(spell_target.uid)].global_position}]})
 var started=stage.play(str(item.category),context)
 effect_available=not started.is_empty()
 if not effect_available:hint.text="此商品的特效暂不可预览"

func entrance_context() -> Dictionary:
 return {"node":subject_node(),"uid":subject.uid,"card_id":subject.card_id,"card_size":Table.CARD_SIZE,"landing":entrance_landing,"travel":entrance_duration}

func play_entrance():
 var node=subject_node()
 entrance_elapsed=0.0;entrance_duration=table.animation_duration
 entrance_ease="cubic_in_out";entrance_flying=true;entrance_proxy=false
 entrance_from=Transform3D(Basis.from_euler(Vector3(deg_to_rad(40),deg_to_rad(-7),0)).scaled(entrance_landing.basis.get_scale()*0.8),entrance_landing.origin+Vector3(-2.8,1.4,-3.2))
 node.global_transform=entrance_from;node.show()
 var context=entrance_context()
 context.merge({"parent":null,"timings":["before"],"flight":{"from":entrance_from,"to":entrance_landing,"seconds":entrance_duration,"ease":entrance_ease,"texture":host.texture(subject.card_id)}})
 var started=stage.play("entrance",context)
 for module in started:
  if not module.owns_flight():continue
  entrance_proxy=true
  entrance_duration=module.flight_seconds()
  entrance_ease=str(module.ctx.flight.get("ease",entrance_ease))
  break
 node.visible=not entrance_proxy

func advance_effects(delta: float):
 if not is_instance_valid(stage):return
 if entrance_flying:
  var step=minf(delta,maxf(0,entrance_duration-entrance_elapsed))
  entrance_elapsed=minf(entrance_elapsed+step,entrance_duration)
  var u=clampf(entrance_elapsed/maxf(entrance_duration,0.001),0,1)
  if entrance_ease=="sine_in_out":u=-(cos(PI*u)-1)/2
  elif entrance_ease!="linear":u=4*u*u*u if u<0.5 else 1-pow(-2*u+2,3)/2
  subject_node().global_transform=entrance_from.interpolate_with(entrance_landing,u)
  stage.advance_all(step)
  delta-=step
  if entrance_elapsed>=entrance_duration:
   entrance_flying=false
   subject_node().global_transform=entrance_landing;subject_node().show()
   stage.landed(subject.uid)
   var context=entrance_context();context.merge({"parent":subject_node(),"travel":0.0,"timings":["after"]},true)
   stage.play("entrance",context)
 if delta>0:stage.advance_all(delta)

func show_emote(kind: String):
 if closing or item.category!="emotes" or kind not in KINDS:return
 if is_instance_valid(bubble):remove_child(bubble);bubble.queue_free()
 bubble=Bubble.new();add_child(bubble);bubble.name="PreviewEmoteBubble"
 bubble.scale=Vector2.ONE*clampf(host.ui_metrics.body/24.0,1.0,1.5)
 bubble.size.x=minf(420 if host.is_android else 360,host.ui_metrics.safe.size.x-24)
 var profile=Profiles.profile(engine,0)
 bubble.configure(str(profile.lines[kind]),kind,true,str(profile.leader_id)=="character-fdn-026")
 bubble_remaining=4.0;place_bubble()

func place_bubble():
 if not is_instance_valid(bubble):return
 var point=table.camera.unproject_position(subject_node().global_position+Vector3(0,0,-Table.CARD_SIZE.y*0.55))
 point=surface.position+point*surface.size/Vector2(viewport.size)
 var safe=host.ui_metrics.safe.grow(-8)
 var dimensions=bubble.size*bubble.scale
 bubble.position=Vector2(clampf(point.x-dimensions.x*0.5,safe.position.x,safe.end.x-dimensions.x),clampf(point.y-dimensions.y,surface.position.y,surface.get_rect().end.y-dimensions.y))
 bubble.set_tip_x((point.x-bubble.position.x)/bubble.scale.x)

func relayout():
 if not is_instance_valid(header):return
 var m=host.ui_metrics;var safe=m.safe;var gap=maxf(8,m.gap)
 header.position=safe.position+Vector2(gap,gap);header.size=Vector2(safe.size.x-gap*2,m.hit)
 host.ui_metrics.button(exit_button)
 title.add_theme_font_size_override("font_size",m.title)
 var hint_font=mini(m.small,28)
 hint.add_theme_font_size_override("font_size",hint_font)
 emote_bar.add_theme_constant_override("separation",int(gap))
 for button in emote_bar.get_children():
  host.ui_metrics.button(button);button.custom_minimum_size.x=0
 emote_bar.position=Vector2(safe.position.x+gap,safe.end.y-m.hit-gap)
 emote_bar.size=Vector2(safe.size.x-gap*2,m.hit)
 var bottom=emote_bar.position.y-gap if emote_bar.visible else safe.end.y-gap
 hint.position=Vector2(safe.position.x+gap,bottom-hint_font*1.6)
 hint.size=Vector2(safe.size.x-gap*2,hint_font*1.6)
 surface.position=Vector2(safe.position.x,header.position.y+m.hit+gap)
 surface.size=Vector2(safe.size.x,maxf(1,hint.position.y-surface.position.y-gap))
 viewport.size=Vector2i(surface.size)
 # Dense Android controls leave a shallower viewport. Bring the showcased
 # card closer so it remains readable instead of shrinking with the board.
 table.camera_frame_scale=clampf(surface.size.y/600.0,0.45,1.0)
 table.set_camera()
 place_bubble()

func _process(delta: float):
 if closing:return
 advance_effects(delta)
 if is_instance_valid(bubble):
  bubble_remaining-=delta
  if bubble_remaining<=0:remove_child(bubble);bubble.queue_free();bubble=null
  else:bubble.modulate.a=minf(1,bubble_remaining/0.3);place_bubble()
 if effect_available and is_instance_valid(stage) and not entrance_flying and stage.active.is_empty():
  loop_remaining-=delta
  if loop_remaining<=0:play_effect()

func handle_input(event: InputEvent):
 if closing:get_viewport().set_input_as_handled();return
 if event.is_action_pressed("ui_cancel") or event is InputEventKey and event.pressed and event.keycode==KEY_BACK:
  get_viewport().set_input_as_handled();closed.emit();return
 # Native touch activates only the explicit buttons. Suppress its synthetic
 # mouse companion so an exit cannot click through onto the restored shop.
 if event is InputEventScreenTouch:
  suppress_mouse_until=Time.get_ticks_msec()+300
  get_viewport().set_input_as_handled()
  if event.pressed and touch_finger==-1:
   touch_finger=event.index;touch_button=button_at(event.position)
  elif not event.pressed and event.index==touch_finger:
   var target=touch_button;touch_finger=-1;touch_button=null
   if is_instance_valid(target) and not event.canceled and target.get_global_rect().has_point(event.position):target.pressed.emit()
  return
 if event is InputEventScreenDrag:
  if event.index==touch_finger and is_instance_valid(touch_button) and not touch_button.get_global_rect().has_point(event.position):touch_button=null
  get_viewport().set_input_as_handled();return
 if event is InputEventMouse and (event.device==-1 or Time.get_ticks_msec()<suppress_mouse_until):
  get_viewport().set_input_as_handled();return
 # GUI owns normal mouse clicks, Tab/arrows and activation on our buttons.
 # Everything else is swallowed by the containing shop's unhandled input.

func button_at(point: Vector2) -> Button:
 if exit_button.get_global_rect().has_point(point):return exit_button
 for button in emote_bar.get_children():
  if button.is_visible_in_tree() and button.get_global_rect().has_point(point):return button
 return null

func shutdown():
 closing=true;entrance_flying=false;set_process(false)
 if is_instance_valid(stage):stage.stop_all()

