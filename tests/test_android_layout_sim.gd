extends SceneTree
## Full interaction test, deliberately independent from production test helpers.
var checks=0
var failures=0
var sim
const KeywordGlossary=preload("res://scripts/keyword_glossary.gd")

func _initialize():
 call_deferred("run")

func expect(ok: bool,title: String) -> bool:
 checks+=1
 if not ok:failures+=1;print("FAIL: ",title)
 return ok

func settle():
 await create_timer(0.3).timeout

func click(key: String):
 if not sim.nodes.has(key):
  var card=sim.state.find_card(key.trim_prefix("hand-sheet-"))
  if not card.is_empty() and (card.seat==0 or card.get("user",-1)==0) and card.zone in ["hand","grave","exile","palette"]:
   var tab="hand" if card.zone=="hand" else "zone"
   if sim.hand_sheet!=tab:
    await click("hand-more" if tab=="hand" else "zone-more")
   var info=sim.placement("pager-hand-sheet").props
   for i in range(info.pages):
    if card.key in info.keys_by_page[i]:
     sim.anchors["hand-sheet"]=info.keys_by_page[i][0];sim.refresh();await settle();break
   key="hand-sheet-"+card.key
 if not expect(sim.nodes.has(key),"click exists: "+key):return
 var node=sim.nodes[key]
 var point=node.get_global_transform()*Vector2(node.props.get("hit_w",node.size.x)/2,node.size.y/2)
 await click_at(point)

func click_at(point: Vector2):
 var down=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;down.position=point;down.global_position=point
 root.push_input(down,true)
 await process_frame
 var up=InputEventMouseButton.new();up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;up.position=point;up.global_position=point
 root.push_input(up,true)
 await settle()

func hand(id: String) -> String:
 for card in sim.state.players[0].hand:
  if card.id==id:return card.key
 return "missing-"+id

func global_checks(title: String):
 var safe=Rect2(48,0,1204,600)
 var overlays=[]
 for item in sim.placements:
  if item.props.get("overlay",false) and item.key not in ["opponent-palette","zone-sheet","hand-sheet","perm-sheet"]:overlays.append(item)
 for item in sim.placements:
  if item.interactive or item.legal:
   var exception=item.kind=="card" and item.props.card.zone=="units" and not item.legal
   expect(item.key=="palette-label" or exception or (item.rect.size.x>=69.99 and item.rect.size.y>=69.99),title+" touch size "+item.key+" "+str(item.rect))
  if item.interactive:expect(safe.encloses(item.rect),title+" safe bounds "+item.key+" "+str(item.rect))
  if item.legal:
   if item.kind=="card" and item.props.card.zone=="units" and sim.state.phase=="TARGET":
    expect(sim.nodes[item.key].z_index>sim.nodes["guide"].z_index,title+" target unit and protruding stat badge paint above guide")
   for overlay in overlays:expect(not item.rect.intersects(overlay.rect),title+" target visible "+item.key+" vs "+overlay.key)
 var sheet=sim.placement("zone-sheet")
 if not sheet.is_empty():
  for item in sim.placements:
   if item.legal and not item.props.get("zone_cell",false):expect(not item.rect.intersects(sheet.rect),title+" zone sheet avoids legal item "+item.key)
  for area in [Rect2(0,0,258,600),Rect2(1042,0,258,600),Rect2(0,470,1300,130)]:expect(not sheet.rect.intersects(area),title+" zone sheet avoids rails and hand")
 var before=sim.state.snapshot();var rects={}
 hand_row_geometry(sim.placements,title)
 vertical_layout_geometry(title)
 for item in sim.placements:rects[item.key]=item.rect
 sim.refresh();await settle()
 var after={}
 for item in sim.placements:after[item.key]=item.rect
 expect(sim.state.snapshot()==before,title+" refresh preserves state")
 expect(rects==after,title+" refresh preserves all placement rectangles")

func shot(step: String):
 await global_checks(step)
 await sim.capture("res://work/android-layout-sim/v9/%s.png" % step)

func vertical_layout_geometry(title: String):
 var mat=sim.placement("mat");var melody=sim.placement("perm-zone--1-melody")
 var own_row=Rect2(268,246,764,146);var enemy_row=Rect2(268,90,764,146)
 var hand_band=Rect2(268,470,764,130);var toggle=Rect2(954,500,70,70)
 var midline=Rect2(268,236,764,10);var own_zones=[];var enemy_zones=[];var units=[[],[]]
 expect(mat.rect==Rect2(268,8,764,584) and mat.props.split_y==241 and sim.nodes.mat.props.split_y-8==233,title+" mat split uses absolute draft y=241 / local y=233")
 expect(melody.rect==Rect2(280,16,70,70),title+" shared melody in top band")
 turn_checks()
 for i in range(sim.state.PERM_ZONES.size()):
  var zone=sim.state.PERM_ZONES[i]
  var own=sim.placement("perm-zone-0-"+zone);var enemy=sim.placement("perm-zone-1-"+zone)
  own_zones.append(own);enemy_zones.append(enemy)
  expect(own.rect==Rect2(794+i*78,398,70,70) and enemy.rect==Rect2(794+i*78,16,70,70),title+" aligned permanent columns "+zone)
  expect(own.rect.position.x==enemy.rect.position.x and own.rect.position.y>=own_row.end.y and own.rect.end.y<hand_band.position.y,title+" own zones between units and hand "+zone)
  expect(enemy.rect.end.y<enemy_row.position.y,title+" enemy zones above units "+zone)
  for blocked in [melody.rect,Rect2(362,39,220,24),Rect2(600,0,184,96)]:expect(not enemy.rect.intersects(blocked),title+" enemy zone clears top band "+zone)
  for tile in [own,enemy]:
   expect(not tile.rect.intersects(midline) and tile.rect.size==Vector2(70,70) and sim.nodes[tile.key].size==Vector2(70,70),title+" zone keeps full hit rectangle outside midline "+tile.key)
   expect(sim.nodes[tile.key].z_index==20,title+" zone layer remains 20")
 for item in sim.placements:
  if item.kind!="card" or item.props.card.zone!="units":continue
  var seat=item.props.card.seat;var rect: Rect2=item.rect;var row=own_row if seat==0 else enemy_row
  var expected_size=Vector2(146,104) if item.props.card.tapped else Vector2(104,146)
  expect(rect.size==expected_size and rect.position.y==row.position.y+(146-expected_size.y)/2 and row.encloses(rect),title+" upright/tapped unit stays centered in its row "+item.key)
  expect(not rect.intersects(midline),title+" unit hit rectangle clears midline "+item.key)
  expect(sim.nodes[item.key].z_index==(46 if item.legal else 21),title+" unit keeps target/normal layer "+item.key)
  units[seat].append(item)
  for zone in (own_zones if seat==0 else enemy_zones):expect(not rect.intersects(zone.rect),title+" unit clears permanent entrance "+item.key)
  if seat==0:
   expect(not rect.intersects(hand_band) and not rect.intersects(toggle),title+" own unit clears hand and strip toggle "+item.key)
   # The stat pill ends at 400 for an upright unit; only its paint overlaps the zone's top 2 px.
   expect(rect.end.y+8<=400,title+" own stat pill ends at or above 400")
   var pill_band=Rect2(rect.position.x,rect.end.y-8,rect.size.x,16)
   for zone in own_zones:
    expect(sim.nodes[item.key].z_index>sim.nodes[zone.key].z_index,title+" own stat pill paints above full zone hit area")
    if pill_band.intersects(zone.rect):expect(pill_band.intersection(zone.rect).size.y==2,title+" own stat pill paint overlap is exactly 2 px")
 for own in units[0]:
  for enemy in units[1]:expect(not own.rect.intersects(enemy.rect),title+" opposing units never intersect")
 for seat in range(2):
  var y=own_row.position.y if seat==0 else enemy_row.position.y
  for dir in ["prev","next"]:
   var pager=sim.placement("page-units-%d-%s" % [seat,dir])
   if not pager.is_empty():expect(pager.rect==Rect2(268 if dir=="prev" else 962,y+(146-146)/2.0,70,146),title+" unit pager follows centered row formula")
 if sim.state.phase=="TARGET":
  var guide=sim.placement("guide");var regions=0
  expect(guide.rect==Rect2(300,472,700,120),title+" target guide exact bottom band")
  for zone in own_zones:expect(not guide.rect.intersects(zone.rect),title+" guide clears own permanent zones")
  for own in units[0]:expect(not guide.rect.intersects(own.rect),title+" guide clears own units")
  for item in sim.placements:
   if item.legal:expect(not guide.rect.intersects(item.rect),title+" guide clears every legal target "+item.key)
   if item.kind=="region":
    expect(item.rect==Rect2(312+regions*112,520,100,70) and guide.rect.encloses(item.rect),title+" region inside guide at y=520")
    regions+=1
  expect(regions==6,title+" guide retains six region buttons")
 if sim.state.phase=="PAY":
  var payment=sim.placement("payment");var candidates=sim.placement("candidates")
  expect(payment.rect==Rect2(330,418,640,174) and payment.props.overlay,title+" PAY panel remains an overlay")
  if not candidates.is_empty():expect(candidates.rect==Rect2(330,298,640,120) and candidates.props.overlay,title+" PAY candidate strip remains an overlay")
  for zone in own_zones+enemy_zones+[melody]:
   expect(not zone.interactive and not zone.props.clickable and sim.nodes[zone.key].mouse_filter==Control.MOUSE_FILTER_IGNORE,title+" PAY permanent entrance is not clickable "+zone.key)
  for zone in own_zones:expect(payment.rect.intersects(zone.rect) and sim.nodes.payment.z_index>sim.nodes[zone.key].z_index,title+" PAY may cover own zones")
 var classic=sim.placement("palette-classic")
 if not classic.is_empty():
  expect(classic.rect==Rect2(268,244,764,150) and classic.rect.encloses(own_row),title+" classic palette covers own unit row")
  expect(not classic.rect.intersects(hand_band),title+" classic palette clears hand")
  for zone in own_zones:expect(not classic.rect.intersects(zone.rect),title+" classic palette clears own permanent zones")

func allocation_ok(title: String):
 expect(sim.state.valid_allocation(),title+" each slot has a distinct untapped card of the required color")
 for i in range(sim.state.costs.size()):
  var card=sim.state.find_card(sim.state.allocation[i])
  expect(not card.tapped and sim.state.can_pay(card,sim.state.costs[i]),title+" slot %d legal" % i)

func opponent_click():
 sim.controls_open=true;sim.build_control_bar();await settle()
 await click_at(sim.control_buttons.opponent.get_global_rect().get_center())
 sim.controls_open=false;sim.build_control_bar();await settle()

func run_layout():
 sim.state.reset();sim.refresh();await settle()
 var state=sim.state
 expect(state.phase=="MAIN","idle MAIN")
 var summary=state.summary(0)
 print("summary=",summary)
 for color in {"total":11,"红":7,"蓝":5,"绿":4,"黄":4,"黑":5}:
  expect(summary[color]=={"total":11,"红":7,"蓝":5,"绿":4,"黄":4,"黑":5}[color],"idle summary "+color)
 for card in state.players[0].hand:expect(state.usable(card)==(card.id!="100"),"idle usability "+card.id)
 var big=state.recommend(state.cost_points(state.find_card(hand("58"))))
 var big_ids=[]
 for key in big:big_ids.append(state.find_card(key).id)
 expect("154" in big_ids and "134" in big_ids,"green four needs both tri-color and rainbow")
 await shot("idle")
 await click("summary-0-蓝")
 expect(state.drawer and state.drawer_filter=="蓝","blue summary opens filtered drawer")
 var groups=sim.nodes.drawer.find_children("*","Control",true,false)
 var tested=0
 for group in groups:
  if group.has_meta("contains_filter"):
   expect(is_equal_approx(group.modulate.a,1.0 if group.get_meta("contains_filter") else 0.35),"drawer group opacity "+group.get_meta("group_name"));tested+=1
 expect(tested==state.grouped(0).size(),"all drawer groups rendered")
 await shot("drawer")
 await click("summary-0-蓝");expect(not state.drawer,"same color closes drawer")
 await click(hand("spell-fdf-007"))
 if not expect(state.phase=="TARGET","spell-fdf-007 enters TARGET via mouse input"):return
 expect(state.targets(state.pending).size()==7,"all seven opposing palette cards are legal, including tapped")
 for card in state.players[1].palette:
  var item=sim.placement(card.key)
  expect(not item.is_empty() and item.legal and item.rect.size.x>=70 and item.rect.size.y>=70,"palette target visible and large "+card.id)
  if card.id in ["42","15"]:
   expect(item.rect.size==Vector2(98,70) and item.legal,"tapped palette target is landscape "+card.id)
   expect(sim.nodes[card.key].props.rotate_tapped and is_equal_approx(sim.nodes[card.key].art.rotation,PI/2),"tapped palette target art rotated "+card.id)
  for other in state.players[1].palette:
   if card.key!=other.key:expect(not item.rect.intersects(sim.placement(other.key).rect),"palette targets do not overlap "+card.id+" / "+other.id)
 for i in range(3):await click(state.players[1].palette[i].key)
 expect(state.selected.size()==3 and not sim.nodes.primary.button.disabled,"three targets enable confirm")
 await shot("target-palette")
 var palette_before=JSON.stringify(state.players[0].palette)
 await click("primary")
 if not expect(state.phase=="PAY","confirm palette targets enters PAY"):return
 allocation_ok("palette recommendation")
 var allocated_ids=[]
 for key in state.allocation:allocated_ids.append(state.find_card(key).id)
 expect("134" not in allocated_ids and "154" not in allocated_ids,"palette payment preserves rainbow and tri-color")
 await shot("pay-palette")
 await click("secondary-0")
 expect(state.phase=="MAIN" and JSON.stringify(state.players[0].palette)==palette_before,"cancel PAY restores source phase without spending")
 await opponent_click()
 if not expect(state.phase=="RESPOND" and state.stack.size()==1,"control bar opponent play enters RESPOND"):return
 expect(state.stack[0].id=="156","opponent object is Perfect Freeze")
 for card in state.players[0].hand:expect(state.usable(card)==(card.id in ["100","96"]),"response usability "+card.id)
 await shot("respond")
 await click(hand("100"))
 if not expect(state.phase=="TARGET","counter enters TARGET"):return
 var opponent_key=state.stack[0].key
 expect(state.targets(state.pending)==[opponent_key],"counter only targets opposing 156")
 await click(opponent_key)
 expect(state.selected==[opponent_key] and sim.placement(opponent_key).props.selected,"counter target selected gold")
 expect(sim.nodes.has("pending") and sim.placement("pending").props.pending,"pending dashed object exists")
 expect(sim.arrows.segments.size()>=2,"pending and existing object both have target arrows")
 await shot("target-counter")
 await click("primary")
 if not expect(state.phase=="PAY","counter confirm enters PAY"):return
 expect(state.costs==["黄","黄"],"counter payment has two yellow slots")
 allocation_ok("counter recommendation")
 await shot("pay-counter")
 await click("cost-0")
 expect(state.candidate_slot==0 and sim.nodes.has("candidates") and state.candidates(0).size()>0,"first cost slot opens candidates")
 await shot("pay-swap")
 var choice=state.candidates(0)[0]
 for card in state.candidates(0):
  if card.key!=state.allocation[0]:choice=card;break
 await click("candidate-"+choice.key)
 expect(state.candidate_slot==-1 and state.allocation[0]==choice.key,"candidate click replaces assignment and closes bar")
 allocation_ok("swapped counter")
 var tapped_before=state.players[0].palette.size()-state.summary(0).total
 var blue_key=state.players[0].units[0].key
 await click("primary")
 expect(state.phase=="OPP_THINK","activation enters OPP_THINK")
 var busy_disabled=true
 for item in sim.placements:
  if item.kind=="button" and not item.key.begins_with("zone-") and not item.props.get("disabled",false):busy_disabled=false
 expect(busy_disabled,"all design buttons are disabled while opponent thinks")
 await create_timer(0.85).timeout
 expect(state.phase=="RESOLVING","opponent yields after one second")
 await create_timer(0.8).timeout
 await settle()
 expect(state.phase=="MAIN" and state.stack.is_empty(),"counter resolves and stack returns MAIN")
 expect(not state.find_card(blue_key).tapped,"countered 156 does not tap Yakumo Ran")
 expect(state.players[0].palette.size()-state.summary(0).total==tapped_before+2,"activation taps exactly two palette cards")
 await shot("resolved")
 await opponent_click();await click(hand("96"))
 if not expect(state.phase=="TARGET","damage response enters TARGET"):return
 var counts=state.region_counts()
 expect(counts["战场"]==11 and counts["战场"]==state.players[0].units.size()+state.players[1].units.size(),"damage battlefield region counts all eleven units")
 expect(counts["玩家"]==2 and counts["对抗"]==0,"damage region has two players and no stack targets")
 expect(sim.placement("region-战场").props.count==11 and sim.placement("region-玩家").props.count==2,"region labels reflect legal target counts")
 await shot("target-damage")
 await click("secondary-0");expect(state.phase=="RESPOND","cancel damage returns RESPOND")
 await status_checks()

func unit_geometry(title: String):
 var rows=[[],[]]
 for item in sim.placements:
  if item.kind!="card":continue
  if item.props.card.zone=="hand":
   expect(not sim.nodes[item.key].props.get("rotate_tapped",false),title+" hand stays upright "+item.key);continue
  if item.props.card.zone!="units":continue
  var rect: Rect2=item.rect;var node=sim.nodes[item.key];var tapped=item.props.card.tapped
  expect(absf(rect.size.x-roundf(rect.size.y*1.4))<=1 if tapped else absf(rect.size.y-roundf(rect.size.x*1.4))<=1,title+" unit orientation "+item.key)
  expect(Rect2(48,0,1204,600).encloses(rect),title+" unit safe bounds "+item.key)
  expect(node.props.get("rotate_tapped",false),title+" unit rotates tapped art "+item.key)
  expect(is_equal_approx(node.art.rotation,PI/2 if tapped else 0.0),title+" settled art rotation "+item.key)
  var inset=maxf(2,minf(node.size.x,node.size.y)*0.035)
  var art_size=(Vector2(node.size.y,node.size.x) if tapped else node.size)-Vector2.ONE*inset*2
  expect(node.art.size.is_equal_approx(art_size) and node.art.pivot_offset.is_equal_approx(art_size/2) and node.art.position.is_equal_approx(node.size/2-art_size/2),title+" art centered within target geometry "+item.key)
  for other in rows[item.props.card.seat]:expect(not rect.intersects(other.rect),title+" row units do not overlap "+item.key+" / "+other.key)
  rows[item.props.card.seat].append(item)

func control_click(action: String):
 sim.controls_open=true;sim.build_control_bar();await settle()
 expect(is_equal_approx(sim.control_bar.position.x,(1300-sim.control_bar.size.x)/2),"expanded controls centered")
 await click_at(sim.control_buttons[action].get_global_rect().get_center())
 sim.controls_open=false;sim.build_control_bar();await settle()

func player_hold(seat: int):
 var point=sim.nodes["player-%d" % seat].get_global_rect().get_center()
 var down=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;down.position=point;down.global_position=point
 root.push_input(down,true);await create_timer(1.1).timeout
 var up=InputEventMouseButton.new();up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;up.position=point;up.global_position=point
 root.push_input(up,true);await process_frame

func status_checks():
 sim.state.reset();sim.refresh();await settle()
 var state=sim.state
 expect(state.phase=="MAIN","v2 idle MAIN")
 unit_geometry("initial")
 var kinds=[]
 for status in state.statuses(1):kinds.append(status.kind)
 expect(kinds==["coin","prevent","wine","counter"],"opposing initial status order")
 for seat in range(2):
  var key="status-%d" % seat;var item=sim.placement(key)
  if not expect(sim.nodes.has(key) and not item.is_empty(),"status row exists "+key):continue
  var node=sim.nodes[key];var drawn=node.get_meta("drawn_kinds");var overflow=node.get_meta("overflow")
  expect(drawn[0]=="coin","coin is always first "+key)
  expect(drawn.size()+overflow==state.statuses(seat).size(),"drawn and overflow account for every status "+key)
  expect(not item.interactive and not item.legal and not node.props.clickable and node.mouse_filter==Control.MOUSE_FILTER_IGNORE and node.z_index==25,"status is passive layer 25 "+key)
  if seat==1:expect(overflow>=1,"190px enemy status row overflows")
  for other in sim.placements:
   if other.key==key or other.key=="player-%d" % seat or other.kind in ["mat","band","label"]:continue
   expect(not item.rect.intersects(other.rect),"status avoids other placements "+key+" / "+other.key)
  var instance_id=node.get_instance_id()
  sim.refresh();await settle()
  expect(sim.nodes[key].get_instance_id()==instance_id,"refresh reuses status "+key)
  sim.refresh();await settle()
  expect(sim.nodes[key].get_instance_id()==instance_id,"repeat refresh reuses status "+key)
 expect(state.players[1].coins==2,"enemy starts with two coins")
 await control_click("coin-1")
 expect(state.players[1].coins==3 and "输掉本局" in sim.notification.text,"coin control reaches three with loss toast")
 await shot("coin-danger")
 await control_click("coin-1")
 expect(state.players[1].coins==3 and "已达" in sim.notification.text,"coin control caps at three with capped toast")
 var phase=state.phase
 await player_hold(0)
 if expect(is_instance_valid(sim.preview),"holding own nameplate opens status sheet"):
  expect(sim.preview.get_meta("status_rows")==state.statuses(0).size(),"status sheet has one row per own status")
  expect(state.phase==phase,"player inspection preserves phase")
  await shot("status-sheet")
  await click_at(Vector2(1800,840))
  expect(not is_instance_valid(sim.preview),"click status sheet mask closes it")
 var point=sim.nodes["player-0"].get_global_rect().get_center()
 var down=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;down.position=point;down.global_position=point
 root.push_input(down,true);await process_frame
 var motion=InputEventMouseMotion.new();motion.position=point+Vector2(30,0);motion.relative=Vector2(30,0);motion.button_mask=MOUSE_BUTTON_MASK_LEFT
 root.push_input(motion,true);await create_timer(1.1).timeout
 expect(not is_instance_valid(sim.preview),"nameplate movement cancels long press")
 var up=InputEventMouseButton.new();up.button_index=MOUSE_BUTTON_LEFT;up.position=point+Vector2(30,0)
 root.push_input(up,true);await settle()
 await control_click("untap")
 for p in state.players:
  for card in p.units+p.palette:expect(not card.tapped,"untap clears units and palette "+card.key)
 unit_geometry("untapped")
 expect(state.summary(0).total==14,"all fourteen palette cards available after untap")
 await shot("untapped")

func model_checks():
 var model=load("res://experiments/android_layout_sim/sim_state.gd").new()
 var card=model.players[0].hand[1]
 model.use_card(card.key);model.toggle_target("player-1");model.confirm_targets();model.activate();model.start_resolving();model.resolve_last()
 expect(model.players[1].life==18,"damage resolution reduces player life by two")
 model.reset();card=model.players[0].hand[1]
 var victim=model.players[1].units[1]
 model.use_card(card.key);model.toggle_target(victim.key);model.confirm_targets();model.activate();model.start_resolving();model.resolve_last()
 expect(model.find_card(victim.key).zone=="grave" and model.players[1].grave.size()==4,"lethal damage moves unit to grave")
 model.reset();model.use_card(model.players[0].hand[2].key)
 var victims=model.players[1].palette.slice(0,3)
 for target in victims:model.toggle_target(target.key)
 model.confirm_targets();model.activate();model.start_resolving();model.resolve_last()
 expect(model.players[1].palette.size()==4 and model.players[1].grave.size()==6,"palette spell removes three selected cards")
 for id in ["13","58"]:
  model.reset()
  for hand_card in model.players[0].hand:
   if hand_card.id==id:model.use_card(hand_card.key);break
  expect(model.phase=="PAY","no-target unit goes directly to PAY "+id)
  model.activate();model.start_resolving();model.resolve_last()
  expect(model.players[0].units.size()==6,"unit resolution joins battlefield "+id)
 model.reset();model.opponent_play();model.start_resolving();model.resolve_last()
 expect(model.players[0].units[0].tapped,"uncountered Perfect Freeze taps its target")
 model.reset()
 var yellow_ids=[]
 for key in model.recommend(["黄","黄"]):yellow_ids.append(model.find_card(key).id)
 expect(yellow_ids==["2","22"],"equal-score allocation compares ID strings including prefix IDs")
 model.reset()
 var twin=load("res://experiments/android_layout_sim/sim_state.gd").new();var original_ids=[]
 for p in model.players:
  for unit in p.units:original_ids.append(unit.id)
 model.flood_units();twin.flood_units()
 expect(model.snapshot()==twin.snapshot(),"unit flood is deterministic")
 var added=[]
 for i in range(24):
  var seat=1-i%2;var unit=model.players[seat].units[(6 if seat==1 else 5)+i/2]
  expect(unit.id not in original_ids and model.data(unit.id).get("类别","")=="单位" and ResourceLoader.exists(model.data(unit.id).get("图片","")),"flood selects unused unit with real art "+unit.id)
  expect(unit.tapped==(i%3==2),"every third flooded unit is tapped")
  added.append(unit.id)
 var sorted=added.duplicate();sorted.sort()
 expect(added==sorted,"unit flood follows ID string order across alternating seats")
 var previous_ids=original_ids+added
 model.flood_units();twin.flood_units()
 expect(model.players[0].units.size()==29 and model.players[1].units.size()==30 and model.snapshot()==twin.snapshot(),"repeated flood adds another twelve per side deterministically")
 for seat in range(2):
  for unit in model.players[seat].units.slice(17 if seat==0 else 18):expect(unit.id not in previous_ids,"repeated flood excludes current unit IDs")
 var players_before=JSON.stringify(model.players)
 model.flood_stack();twin.flood_stack()
 expect(model.snapshot()==twin.snapshot() and model.phase=="RESPOND" and model.stack.size()==10,"stack flood is deterministic and enters RESPOND")
 expect(JSON.stringify(model.players)==players_before,"stack flood preserves all player state")
 for i in range(10):
  var obj=model.stack[i];var seat=i%2;var list=model.players[seat].units
  expect(obj.id==("156" if seat==0 else "96") and obj.seat==1-seat and obj.card.zone=="stack" and obj.targets==[list[(i*(3 if seat==0 else 5))%list.size()].key],"stack flood actor and target formula "+str(i))
 model.reset();twin.reset();model.flood_graves();twin.flood_graves()
 expect(model.snapshot()==twin.snapshot() and model.players[0].grave.size()==17 and model.players[1].grave.size()==15,"grave flood deterministic per side")
 var ids=[]
 for file in DirAccess.get_files_at("res://cards/"):
  if not file.ends_with(".json"):continue
  var id=file.trim_suffix(".json")
  if id not in model.ZONE_PLAY and id not in model.ZONE_ABILITY and ResourceLoader.exists(str(model.data(id).get("图片",""))):ids.append(id)
 ids.sort()
 for seat in range(2):
  var list=model.players[seat].grave.slice(5 if seat==0 else 3)
  for i in range(12):expect(list[i].id==ids[(i*7+seat*3)%ids.size()] and list[i].seat==seat and list[i].zone=="grave","grave flood exact sorted selection and ownership")
 model.reset()
 var controlled=model.players[1].units.pop_back();controlled.hp=1;controlled.free=true;controlled.via="temporary";controlled.tapped=true
 model.players[0].units.append(controlled)
 for i in range(2):
  var damage=model.instance("96",0,"stack")
  model.stack.append({"key":"damage-%d" % i,"id":"96","seat":0,"card":damage,"targets":[controlled.key]})
 model.phase="RESOLVING";model.resolve_last();model.resolve_last()
 expect(controlled in model.players[1].grave and controlled not in model.players[0].grave and controlled not in model.players[0].units,"controlled unit returns to owner rather than controller")
 expect(model.players[1].grave.count(controlled)==1 and controlled.hp==-1 and not controlled.tapped and not controlled.has("free") and not controlled.has("via"),"later damage ignores departed unit and grave clears transient permission")
 model.reset();model.opponent_play();var countered=model.stack.back().card;countered.seat=0
 model.use_card(model.players[0].hand[0].key);model.toggle_target(model.stack[0].key);model.confirm_targets();model.activate();model.start_resolving();model.resolve_last()
 expect(countered in model.players[0].grave and countered not in model.players[1].grave,"countered spell enters owner grave rather than actor grave")

func inspection_checks():
 var point=sim.nodes[hand("100")].get_global_rect().get_center()
 var down=InputEventMouseButton.new();down.position=point;down.global_position=point;down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true
 root.push_input(down,true)
 await create_timer(1.1).timeout
 expect(is_instance_valid(sim.preview),"holding an unavailable card for one second opens inspection")
 expect(sim.state.phase=="MAIN","inspection does not use the card")
 var up=InputEventMouseButton.new();up.position=point;up.global_position=point;up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false
 root.push_input(up,true);await process_frame
 await click_at(Vector2(1800,840))
 expect(not is_instance_valid(sim.preview),"clicking inspection mask closes it")
 point=sim.nodes[hand("96")].get_global_rect().get_center()
 down=InputEventMouseButton.new();down.position=point;down.global_position=point;down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true
 root.push_input(down,true);await process_frame
 var motion=InputEventMouseMotion.new();motion.position=point+Vector2(30,0);motion.relative=Vector2(30,0);motion.button_mask=MOUSE_BUTTON_MASK_LEFT
 root.push_input(motion,true);await create_timer(1.1).timeout
 expect(not is_instance_valid(sim.preview),"moving more than twelve pixels cancels inspection")
 up=InputEventMouseButton.new();up.position=point+Vector2(30,0);up.button_index=MOUSE_BUTTON_LEFT
 root.push_input(up,true);await settle()
 expect(sim.state.phase=="MAIN","cancelled press does not use card")

func scrolling_checks():
 sim.state.reset()
 for i in range(6):
  sim.state.phase="MAIN";sim.state.opponent_play()
 sim.refresh();await settle()
 expect(sim.placement("pager-stack").props.pages==3,"six objects use three stack pages")
 expect(sim.state.stack.back().key in current_keys("stack"),"side stack latest page contains newest object")
 var unit=sim.state.players[0].units[0].key
 var instance_id=sim.nodes[unit].get_instance_id()
 sim.refresh();await settle();sim.refresh();await settle()
 expect(sim.nodes[unit].get_instance_id()==instance_id,"refresh reuses keyed card node")
 await click(hand("100"))
 expect(sim.state.targets(sim.state.pending).size()==6,"overflow counter retains six legal stack targets")
 var target=""
 for key in current_keys("stack"):
  if key in sim.state.targets(sim.state.pending):target=key;break
 await click(target)
 expect(sim.state.selected==[target],"first visible legal stack object receives mouse input")
 await click("secondary-0")
 sim.state.reset();sim.refresh();await settle()
 sim.state.use_card(hand("96"));sim.state.toggle_target("player-0");sim.state.confirm_targets();sim.refresh();await settle()
 await click("cost-0")
 expect(sim.state.candidates(0).size()==8,"seven palette red candidates plus candle remain available")
 var last=sim.state.candidates(0).back()
 await click("candidate-"+last.key)
 expect(sim.state.allocation[0]==last.key and sim.state.valid_allocation(),"last candidate can replace red assignment")
 sim.state.reset();sim.refresh();await settle()

func current_keys(row: String) -> Array:
 var info=sim.placement("pager-"+row).props
 return info.keys_by_page[info.page]

func first_page(row: String):
 while sim.placement("pager-"+row).props.page>0:await click("page-"+row+"-prev")

func page_geometry(row: String):
 var info=sim.placement("pager-"+row).props;var seen=[]
 var left=268;var right=268+sim.Shared.unit_metrics(sim.state,int(row.right(1))).area
 for i in range(info.pages):
  var anchors=sim.anchors.duplicate();anchors[row]=info.keys_by_page[i][0]
  var items=sim.layout.layout(sim.state,Vector2(1300,600),anchors);var rects=[];var keys=[]
  for item in items:
   if sim.item_row(item)!=row:continue
   keys.append(item.key)
   expect(item.rect.position.x>=left+78 and item.rect.end.x<=right-78,"paged units stay in inner bounds "+item.key)
   for rect in rects:expect(not item.rect.intersects(rect),"paged units never overlap "+item.key)
   rects.append(item.rect)
  expect(keys==info.keys_by_page[i],"greedy page preserves card order "+row+" / "+str(i))
  seen.append_array(keys)
 var expected=[]
 for card in sim.state.players[int(row.right(1))].units:expected.append(card.key)
 expect(seen==expected,"pages partition entire row exactly once "+row)
 for dir in ["prev","next"]:
  var item=sim.placement("page-"+row+"-"+dir)
  expect(item.rect.size.x>=70 and item.rect.size.y>=70 and Rect2(48,0,1204,600).encloses(item.rect),"pager safe touch bounds "+row+dir)
  expect(sim.nodes[item.key].z_index==22,"pager layer 22 "+row+dir)

func has_hidden_arrow() -> bool:
 for segment in sim.arrows.segments:
  for item in sim.placements:
   if item.kind=="pager" and segment[1].is_equal_approx(item.rect) and segment.size()==3 and segment[2]==Color("#ffd84a",0.55):return true
 return false

func paging_motion(row: String):
 var before=sim.state.snapshot();var old_keys=current_keys(row).duplicate();var old_node=sim.nodes[old_keys[0]]
 sim.dispatch("page","page-"+row+"-prev")
 for key in current_keys(row):
  var node=sim.nodes[key];var rect=sim.placement(key).rect
  expect(node.position.is_equal_approx(rect.position-Vector2(24,0)) and is_zero_approx(node.modulate.a),"new page starts offset and transparent "+key)
 expect(not sim.nodes.has(old_keys[0]) and is_instance_valid(old_node),"departing page remains alive only for fade")
 var motions=get_processed_tweens()
 for tween in motions:
  if tween.is_valid():tween.pause();tween.custom_step(0.09)
 expect(is_instance_valid(old_node) and old_node.modulate.a>0 and old_node.modulate.a<1,"departing page fades during 180ms transition")
 for tween in motions:
  if tween.is_valid():tween.play()
 await settle()
 for key in current_keys(row):expect(sim.nodes[key].position.is_equal_approx(sim.placement(key).rect.position),"new page settles at target "+key)
 sim.dispatch("page","page-"+row+"-next")
 for key in current_keys(row):expect(sim.nodes[key].position.is_equal_approx(sim.placement(key).rect.position+Vector2(24,0)),"next page enters from right "+key)
 await settle()
 expect(sim.state.snapshot()==before,"page animation changes no game state")

func side_stack_geometry():
 var keys=["page-stack-prev","page-stack-next","secondary-0","secondary-1","primary"]
 var panel=sim.placement("stack-panel").rect
 expect(panel==Rect2(1042,72,210,328),"side stack panel exact v3 bounds")
 for i in range(keys.size()):
  var rect=sim.placement(keys[i]).rect
  expect(Rect2(48,0,1204,592).encloses(rect),"side control stays above 592 "+keys[i])
  for j in range(i):expect(not rect.intersects(sim.placement(keys[j]).rect),"side controls never overlap "+keys[i]+" / "+keys[j])
  if i<2:expect(panel.encloses(rect),"stack background contains its own pager "+keys[i])
  else:expect(not panel.intersects(rect),"stack panel avoids action buttons "+keys[i])

func stack_pager_limits():
 for pending in [false,true]:
  var limit=2
  for count in [limit-1,limit,limit+1]:
   var model=load("res://experiments/android_layout_sim/sim_state.gd").new()
   model.flood_stack(count)
   if pending:model.use_card(model.players[0].hand[1].key)
   var items=sim.layout.layout(model,Vector2(1300,600));var buttons=0
   for item in items:
    if item.key in ["page-stack-prev","page-stack-next"]:buttons+=1
    if item.key=="pager-stack":
     expect(item.props.pages==(1 if count<=limit else 2),"stack pager threshold counts only paged objects")
     for page in item.props.keys_by_page:expect("pending" not in page,"pending excluded from every stack page")
   expect(buttons==(0 if count<=limit else 2),"stack pager buttons appear only above capacity")

func pending_page_geometry(rect: Rect2,instance_id: int):
 if not expect(sim.nodes.has("pending"),"pending exists on stack page "+str(sim.placement("pager-stack").props.page)):return
 var item=sim.placement("pending");var node=sim.nodes.pending
 expect(item.kind=="object" and item.props.pending,"pending retains object kind and key")
 expect(item.rect==rect and node.position.is_equal_approx(rect.position) and node.get_instance_id()==instance_id and is_equal_approx(node.modulate.a,1.0),"pending stays fixed and visible across page changes")
 expect(Rect2(0,0,1300,600).encloses(item.rect),"pending entirely inside canvas")
 expect(sim.placement("stack-panel").rect.encloses(item.rect),"pending entirely inside its stack container")
 expect(not item.interactive and not item.legal and not item.props.clickable and node.mouse_filter==Control.MOUSE_FILTER_IGNORE,"pending is passive")
 var info=sim.placement("pager-stack").props;var visible=[]
 for page in info.keys_by_page:expect("pending" not in page,"pending never participates in stack pagination")
 for obj in sim.placements:
  if obj.kind!="object" or obj.key=="pending":continue
  visible.append(obj.key)
  expect(not obj.rect.intersects(rect),"paged object avoids fixed pending "+obj.key)
  expect(obj.rect==Rect2(1050,114+(visible.size()-1)*104,194,100),"side paged objects keep original positions")
 expect(visible==current_keys("stack"),"visible stack objects match page metadata without pending")
 expect(visible.size()<=2,"pending leaves required page capacity")
 expect(rect==Rect2(1050,76,194,36),"side pending uses exact 36px title strip")
 expect(node.get_child_count()==0,"pending strip has no embedded thumbnail")
 expect(sim.placement("stack-panel").props.pending,"pending replaces side panel title")

func pending_stack_pages():
 if not expect(sim.nodes.has("pending"),"flooded counter TARGET has pending node"):return
 var rect=sim.placement("pending").rect;var instance_id=sim.nodes.pending.get_instance_id()
 var before=sim.state.snapshot();var start=sim.placement("pager-stack").props.page
 var seen=[]
 pending_page_geometry(rect,instance_id)
 for dir in [-1,1,-1]:
  var info=sim.placement("pager-stack").props
  while info.page>0 if dir<0 else info.page<info.pages-1:
   await click("page-stack-prev" if dir<0 else "page-stack-next")
   pending_page_geometry(rect,instance_id)
   info=sim.placement("pager-stack").props
   if dir>0:seen.append(info.page)
 expect(seen.size()==sim.placement("pager-stack").props.pages-1,"pending checked on every stack page in both directions")
 while sim.placement("pager-stack").props.page<start:
  await click("page-stack-next");pending_page_geometry(rect,instance_id)
 expect(sim.state.snapshot()==before,"paging fixed pending preserves game state")
 await click("pending")
 var point=sim.nodes.pending.get_global_rect().get_center()
 var down=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;down.position=point;down.global_position=point
 root.push_input(down,true);await create_timer(1.1).timeout
 expect(not sim.nodes.pending.held and not is_instance_valid(sim.preview),"pending strip ignores long press")
 var up=InputEventMouseButton.new();up.button_index=MOUSE_BUTTON_LEFT;up.position=point;up.global_position=point
 root.push_input(up,true);await settle()
 expect(sim.state.snapshot()==before,"pending strip click and hold change no game state")

func paging_checks():
 stack_pager_limits()
 await control_click("reset");sim.refresh();await settle()
 var state=sim.state;var counts=[state.players[0].units.size(),state.players[1].units.size()]
 await control_click("flood-units")
 for seat in range(2):expect(state.players[seat].units.size()==counts[seat]+12,"flood control adds twelve units per side")
 expect(state.players[0].units.back().key in current_keys("units-0"),"new own unit automatically becomes visible")
 for row in ["units-0","units-1"]:
  expect(sim.placement("pager-"+row).props.pages>=2,"many units need paging "+row)
  await first_page(row);page_geometry(row)
  var prev=sim.placement("page-"+row+"-prev")
  expect(not prev.interactive and not prev.props.clickable and is_equal_approx(sim.nodes[prev.key].modulate.a,0.3),"first page prev is dim and disabled "+row)
  expect(sim.nodes["pager-"+row].visible==false,"pager metadata is invisible "+row)
 await shot("many-units")
 var old=current_keys("units-1").duplicate()
 await click("page-units-1-next")
 var info=sim.placement("pager-units-1").props
 expect(info.page==1 and info.hidden_before==old.size(),"next page reports all preceding cards")
 for key in old:expect(not sim.nodes.has(key),"previous page card leaves keyed nodes "+key)
 await shot("many-units-p2")
 await paging_motion("units-1")
 var first=[current_keys("units-0")[0],current_keys("units-1")[0]];var before=state.snapshot();var anchors=sim.anchors.duplicate()
 sim.refresh();await settle();sim.refresh();await settle()
 expect([current_keys("units-0")[0],current_keys("units-1")[0]]==first and sim.anchors==anchors,"refresh preserves both first cards and anchors")
 expect(state.snapshot()==before,"paged refresh preserves snapshot")
 await opponent_click()
 for row in ["units-0","units-1"]:
  await first_page(row);await click("page-"+row+"-next")
 var pages=[sim.placement("pager-units-0").props.page,sim.placement("pager-units-1").props.page]
 anchors=sim.anchors.duplicate()
 await click(hand("96"))
 expect(state.phase=="TARGET","many-unit damage enters TARGET")
 expect([sim.placement("pager-units-0").props.page,sim.placement("pager-units-1").props.page]==pages and sim.anchors["units-0"]==anchors["units-0"] and sim.anchors["units-1"]==anchors["units-1"],"TARGET retains current unit pages when they contain legal targets")
 for row in ["units-0","units-1"]:
  var node=sim.nodes["page-"+row+"-prev"]
  expect(node.props.legal_hidden and node.pager_border()==Color("#5aa8ff"),"hidden legal targets paint blue pager "+row)
 var selected=current_keys("units-1")[0]
 await click(selected);await click("page-units-1-prev")
 expect(sim.nodes["page-units-1-next"].props.selected_hidden,"selected target is marked after paging away")
 expect(state.selected==[selected],"manual paging preserves selected target")
 anchors=sim.anchors.duplicate();sim.refresh();await settle()
 expect(sim.anchors==anchors,"refresh without an event preserves manual pages")
 await click("secondary-0")
 await control_click("reset");await control_click("flood-stack")
 info=sim.placement("pager-stack").props
 expect(info.pages==5,"ten-object stack page count")
 expect(info.page==0 and not sim.placement(state.stack.back().key).is_empty(),"stack defaults to latest page")
 side_stack_geometry()
 await shot("long-stack")
 await click("page-stack-next")
 var stack_anchor=sim.anchors.stack
 await click(hand("100"))
 expect(sim.anchors.stack==stack_anchor and stack_anchor in current_keys("stack"),"pending appearance retains manual stack anchor with legal targets")
 var legal_visible=false
 for key in current_keys("stack"):legal_visible=legal_visible or key in state.targets(state.pending)
 expect(state.phase=="TARGET" and legal_visible,"counter TARGET current stack page has legal object")
 await pending_stack_pages()
 if not has_hidden_arrow():
  await click("secondary-0");await control_click("flood-units");await control_click("flood-stack");await click(hand("100"))
 expect(has_hidden_arrow(),"off-page targets use gold translucent arrow to pager")
 var counter_target=""
 for key in current_keys("stack"):
  if key in state.targets(state.pending):counter_target=key;break
 expect(not counter_target.is_empty(),"long-stack-target screenshot contains legal target beside pending")
 if not counter_target.is_empty():await click(counter_target)
 var pending_arrow=false
 for segment in sim.arrows.segments:
  if segment[0].is_equal_approx(sim.placement("pending").rect) and segment[1].is_equal_approx(sim.placement(counter_target).rect):pending_arrow=true
 expect(pending_arrow,"fixed pending still emits target arrow")
 await shot("long-stack-target")
 await click("secondary-0");await first_page("stack")
 var size=state.stack.size()
 await opponent_click()
 info=sim.placement("pager-stack").props
 expect(state.stack.size()==size+1 and info.page==0,"opponent addition returns stack to latest page")
 expect(state.stack.back().key in current_keys("stack"),"new opponent object is placed")
 sim.anchors.stack="missing-object";sim.refresh()
 expect(state.stack.back().key in current_keys("stack"),"missing stack anchor falls back to latest page")
 sim.anchors["units-1"]="missing-unit";sim.refresh()
 expect(sim.placement("pager-units-1").props.page==0,"missing unit anchor falls back to page zero")
 await first_page("stack")
 state.start_resolving();state.resolving_key=state.stack.back().key;sim.refresh()
 expect(state.resolving_key in current_keys("stack"),"resolving off-page object automatically becomes visible")
 sim.dispatch("reset","");await settle()
 state.players[0].units.clear();sim.refresh();await control_click("flood-units")
 expect(state.players[0].units.back().key in current_keys("units-0"),"units entering an empty battlefield also jump to their page")
 await control_click("reset")
 expect(sim.anchors["units-0"]=="" and sim.anchors["units-1"]=="" and sim.anchors.stack=="","reset clears view anchors")

func zone_key(id: String,seat: int,zone: String) -> String:
 for card in (sim.state.exile if zone=="exile" else sim.state.players[seat][zone]):
  if card.id==id:return card.key
 return "missing-"+id

func strip_key(id: String) -> String:
 for item in sim.placements:
  if item.props.get("strip",false) and item.props.card.id==id:return item.key
 for card in sim.state.zone_playables():
  if card.id==id:return "hand-sheet-"+card.key
 return "missing-strip-"+id

func show_strip():
 if not sim.show_zone_strip and not sim.placement("zone-strip-toggle").is_empty():sim.dispatch("zone-strip","zone-strip-toggle");await settle()

func strip_ids() -> Array:
 var ids=[]
 for item in sim.placements:
  if item.props.get("strip",false):ids.append(item.props.card.id)
 return ids

func wait_main():
 for i in range(70):
  if sim.state.phase=="MAIN":break
  await create_timer(0.1).timeout
 await settle()
 expect(sim.state.phase=="MAIN" and sim.state.stack.is_empty(),"resolution loop finishes in MAIN")

func pay_zone_disabled():
 for key in ["zone-0-grave","zone-1-grave","zone-exile"]:
  expect(not sim.placement(key).interactive and is_equal_approx(sim.nodes[key].modulate.a,0.45),"PAY dims and disables "+key)

func zone_geometry():
 var rects=[];var panel=sim.placement("zone-sheet").rect
 for item in sim.placements:
  if not item.props.get("zone_cell",false):continue
  expect(item.rect.size==Vector2(78,109) and panel.encloses(item.rect),"zone cell upright and inside sheet "+item.key)
  expect(sim.nodes[item.key].z_index==72 and not sim.nodes[item.key].landscape,"zone cell layer and orientation "+item.key)
  for rect in rects:expect(not rect.intersects(item.rect),"zone cells never overlap "+item.key)
  rects.append(item.rect)

func zone_checks():
 await control_click("reset")
 var state=sim.state
 for seat in range(2):
  var item=sim.placement("zone-%d-grave" % seat)
  expect(item.rect==Rect2(48,248 if seat==0 else 172,101,70),"grave entrance exact rectangle")
  expect(item.props.count==(5 if seat==0 else 3),"grave entrance initial count")
  expect(item.props.playable==(1 if seat==0 else 0),"grave entrance initial playable count")
  expect(sim.placement("zone-%d-exile" % seat).is_empty(),"no per-player exile entrance")
 var exile_entry=sim.placement("zone-exile")
 expect(exile_entry.rect==Rect2(157,172,101,146) and exile_entry.props.seat==-1 and exile_entry.props.public,"one public exile entrance spans both rows")
 expect(exile_entry.props.count==1 and exile_entry.props.playable==1,"public exile initial count and usable badge")
 for card in state.exile:expect(card.seat==-1 and card.zone=="exile","exile cards have no owner")
 expect(not exile_entry.rect.intersects(sim.placement("zone-0-grave").rect) and not exile_entry.rect.intersects(sim.placement("zone-1-grave").rect) and not exile_entry.rect.intersects(sim.placement("player-0").rect) and not exile_entry.rect.intersects(sim.placement("enemy-palette-entry").rect),"public exile entrance clears neighbours")
 expect(sim.placement("summary-0-").props.playable==1 and sim.placement("palette-label").props.text=="颜色盘 可用 11/14","palette source badge and total")
 expect(not sim.show_zone_strip and strip_ids().is_empty() and sim.placement("zone-more").is_empty() and sim.placement("hand-more").is_empty(),"zone strip hidden by default and full initial hand fits")
 for card in state.players[0].hand:expect(not sim.placement(card.key).is_empty() and sim.placement(card.key).rect.end.x<=946,"default hidden strip shows every initial hand card "+card.id)
 expect(sim.placement("zone-strip-toggle").props.text=="区域\n+3","default hidden toggle shows usable zone count")
 await show_strip()
 expect(strip_ids()==["spell-fdf-012","spell-ucs-050"] and sim.placement("zone-more").props.count==1,"MAIN strip preserves source order with palette in overflow tile")
 expect(not sim.placement("strip-divider").is_empty(),"strip divider exists")
 var tags=[];var xs=[]
 for item in sim.placements:
  if not item.props.get("strip",false):continue
  tags.append(item.props.source_tag);xs.append(item.rect.position.x)
  expect(item.interactive and item.props.legal and not item.props.dim and item.rect.size==Vector2(100,130),"strip card usable and touch size")
  expect(item.rect.position.x>=278 and item.rect.end.x<=946 and Rect2(48,0,1204,600).encloses(item.rect),"strip card inside specified safe band")
  expect(sim.nodes[item.key].z_index==12,"strip card layer precedes palette layer")
 expect(tags==["墓地","除外"] and xs[1]-xs[0]==70,"strip source tags and minimum 70px gap")
 var hand_x=[]
 for card in state.players[0].hand:
  if not sim.placement(card.key).is_empty():hand_x.append(sim.placement(card.key).rect.position.x)
  expect(state.usable(card)==(card.id!="100"),"initial hand usability "+card.id)
 for i in range(1,hand_x.size()):expect(hand_x[i]-hand_x[i-1]==70,"overflow hand shares 70px strip gap")
 expect(hand_x.size()+sim.placement("hand-more").props.count==state.players[0].hand.size(),"visible hand and overflow cover all initial cards")
 await click("zone-1-grave")
 expect(state.zone_view=={"seat":1,"zone":"grave"},"enemy entrance opens enemy grave")
 var ids=[]
 for key in current_keys("zone"):
  ids.append(state.find_card(key).id);expect(not sim.placement(key).legal and not sim.placement(key).interactive,"enemy grave read only")
 expect(ids==["spell-fdf-022","96","8"],"enemy grave newest first")
 zone_geometry();await shot("zone-enemy-grave")
 await click("zone-1-grave");expect(state.zone_view.is_empty(),"same entrance closes zone")
 await click("zone-1-grave");await click("zone-tab-exile")
 expect(state.zone_view=={"seat":-1,"zone":"exile","grave_seat":1} and sim.placement("zone-empty").is_empty() and current_keys("zone").size()==1,"exile tab shows the public pile")
 expect(sim.placement("zone-sheet").props.owner=="公共" and sim.placement("zone-tab-grave").props.text=="墓地 3","public exile sheet has no owner and grave tab remembers enemy grave")
 await shot("zone-exile-public")
 await click("zone-tab-grave");expect(state.zone_view=={"seat":1,"zone":"grave"},"grave tab returns to the grave it came from")
 await click("zone-close");await click("zone-exile")
 expect(state.zone_view=={"seat":-1,"zone":"exile"} and sim.placement("zone-tab-grave").props.text=="墓地 5","exile entrance opens public pile; grave tab defaults to own grave")
 await click("zone-exile");expect(state.zone_view.is_empty(),"exile entrance toggles closed")
 await click("zone-1-grave")
 await click("zone-close");expect(state.zone_view.is_empty(),"zone close button closes sheet")
 await click("summary-0-蓝");await click("zone-0-grave")
 expect(not state.drawer and not state.zone_view.is_empty(),"opening zone closes drawer")
 await click("summary-0-蓝")
 expect(state.drawer and state.zone_view.is_empty(),"opening drawer closes zone")
 await click("summary-0-蓝");await click("zone-0-grave")
 var cat=zone_key("spell-fdf-012",0,"grave");var sword=zone_key("spell-fdf-059",0,"grave")
 expect(sim.placement("zone-caption-"+cat).props.text=="可使用","Cat's Walk usable caption")
 expect(sim.placement("zone-caption-"+sword).props.text=="能力·条件不足" and not sim.placement(sword).interactive,"sword ability unavailable caption")
 await click(sword);expect(state.phase=="MAIN","unavailable sword click has no effect")
 await shot("zone-own-grave")
 await click(cat)
 if not expect(state.phase=="PAY" and state.costs==["红","蓝"] and state.zone_view.is_empty(),"grave Cat's Walk enters PAY and closes sheet"):return
 pay_zone_disabled();await shot("pay-from-grave")
 await click("primary")
 expect(state.stack.back().get("from","")=="墓地" and state.stack.back().card.zone=="stack","grave cast records source and removes instance")
 await wait_main()
 expect(state.exile.size()==2 and state.players[0].grave.size()==4 and state.find_card(cat).zone=="exile" and state.find_card(cat).seat==-1,"grave Cat's Walk resolves into the public exile without an owner")
 await control_click("reset");await show_strip()
 var rain=zone_key("spell-ucs-050",0,"exile")
 await click(strip_key("spell-ucs-050"))
 if not expect(state.phase=="OPP_THINK" and state.costs.is_empty() and sim.placement("payment").is_empty(),"free exile cast bypasses PAY"):return
 sim.set_process(false)
 expect(state.stack.back().get("from","")=="除外" and state.exile.is_empty() and state.stack.back().card.seat==0,"free exile cast removes original instance and caster controls it")
 await click("zone-1-grave");await click("zone-tab-exile")
 expect(state.phase=="OPP_THINK" and state.zone_view.zone=="exile","busy zone entrance and tabs remain usable")
 await click("zone-close");expect(state.zone_view.is_empty(),"busy close remains usable")
 sim.set_process(true);await wait_main()
 expect(state.find_card(rain).zone=="grave" and not state.find_card(rain).has("free") and not state.find_card(rain).has("via"),"free exile spell enters owner's grave and clears permission")
 await control_click("reset");await opponent_click();await show_strip()
 expect(strip_ids()==["spell-fdf-012","spell-ucs-050"],"RESPOND strip only includes fast grave and exile cards")
 await shot("strip-respond")
 await control_click("reset");await show_strip()
 var before=state.summary(0);var flower=zone_key("spell-fdf-031",0,"palette")
 await click(strip_key("spell-fdf-031"))
 if not expect(state.phase=="TARGET" and state.targets(state.pending).size()==13,"palette Flower Land targets units and players"):return
 await shot("target-palette-card")
 var victim=state.players[1].units[1];var hp=victim.hp
 await click(victim.key);await click("primary")
 expect(state.phase=="OPP_THINK" and sim.placement("payment").is_empty() and state.stack.back().get("from","")=="颜色盘","free palette card confirms directly onto stack")
 expect(state.players[0].palette.size()==13,"palette source removed once")
 for color in ["total"]+state.COLORS:expect(state.summary(0)[color]==before[color],"tapped palette source preserves summary "+color)
 await wait_main()
 expect(state.find_card(flower).zone=="grave" and state.find_card(victim.key).hp==hp-4 and state.find_card(victim.key).zone=="grave","Flower Land deals four damage and resolves to grave")
 await control_click("reset")
 var memory=hand("157")
 await click(memory)
 if not expect(state.phase=="TARGET" and state.zone_view=={"seat":1,"zone":"grave"},"157 automatically opens enemy grave"):return
 var legal=state.targets(state.pending);ids=[]
 for key in legal:ids.append(state.find_card(key).id)
 expect(ids==["96","spell-fdf-022"] and sim.placement(zone_key("8",1,"grave")).props.dim,"157 targets exactly the two enemy spells and dims unit")
 expect(sim.placement("region-墓地").props.count==2 and sim.placement("zone-1-grave").props.targets==2,"grave region and entrance target counts")
 await click("zone-close");await click("region-墓地")
 expect(state.zone_view=={"seat":1,"zone":"grave"},"grave region reopens first legal target's zone")
 var chosen=zone_key("96",1,"grave")
 await click(chosen)
 var arrow=false
 for segment in sim.arrows.segments:
  if segment[0].is_equal_approx(sim.placement("pending").rect) and segment[1].is_equal_approx(sim.placement(chosen).rect):arrow=true
 expect(arrow,"pending arrow reaches selected grave card")
 await shot("target-grave")
 await click("primary")
 expect(state.phase=="PAY" and state.zone_view.is_empty(),"157 confirms into PAY and closes sheet")
 pay_zone_disabled();await click("primary")
 arrow=false
 for segment in sim.arrows.segments:
  if segment[1].is_equal_approx(sim.placement("zone-1-grave").rect) and segment.size()==3 and segment[2]==Color("#ffd84a",0.55):arrow=true
 expect(arrow,"stack grave target arrow falls back to entrance")
 # Observe the intermediate resolution so returning to the owner's grave cannot hide a missing move.
 for i in range(30):
  if state.find_card(chosen).is_empty():break
  await create_timer(0.1).timeout
 expect(state.players[1].grave.size()==2 and state.stack.size()==1 and state.stack.back().card.key==chosen and state.stack.back().card.seat==1 and state.stack.back().seat==0 and state.stack.back().get("from","")=="对方墓地","157 casts removed enemy instance while retaining owner")
 await wait_main()
 expect(state.players[1].grave.size()==3 and state.find_card(chosen).zone=="grave" and state.find_card(chosen).seat==1 and state.find_card(memory).zone=="grave","enemy spell returns to owner and 157 enters own grave")
 await control_click("reset");await control_click("flood-graves");await click("zone-0-grave")
 expect(sim.placement("pager-zone").props.pages==2 and current_keys("zone").size()==16,"grave flood produces sixteen plus one pages")
 expect(sim.placement("page-zone-next").interactive and sim.placement("zone-page-number").props.text=="1/2","grave first page next enabled and number")
 zone_geometry();await shot("zone-paged")
 await click("page-zone-next")
 expect(current_keys("zone").size()==1 and sim.placement("zone-page-number").props.text=="2/2","grave next click shows last card and second number")
 zone_geometry()
 await click("zone-tab-exile")
 expect(sim.anchors.zone=="" and sim.placement("pager-zone").props.page==0,"zone tab change clears zone anchor")
 await click("zone-close");await control_click("reset")
 # Bury the only two legal spells behind the first sixteen cards, then enter TARGET by click.
 for i in range(16):state.players[1].grave.append(state.instance("8",1,"grave"))
 sim.refresh();await settle()
 await click(hand("157"))
 expect(sim.placement("pager-zone").props.page>0,"TARGET automatically jumps zone to page with legal spell")
 await click("secondary-0")
 expect(state.zone_view.is_empty(),"cancel TARGET closes zone view")
 await control_click("reset")

func left_rail_checks():
 var rail=[];var bounds=Rect2(48,0,210,592)
 var exact={"player-1":Rect2(48,8,210,70),"status-1":Rect2(58,66,190,24),"enemy-palette-entry":Rect2(48,96,210,70),"player-0":Rect2(48,334,210,70),"status-0":Rect2(58,322,190,24),"palette-label":Rect2(48,408,225,18)}
 for key in exact:expect(sim.placement(key).rect==exact[key],"left rail exact rectangle "+key)
 for item in sim.placements:
  if item.kind not in ["nameplate","statuses","palette_entry","zone_button","summary"] and item.key!="palette-label":continue
  expect(not item.key.begins_with("summary-1-"),"enemy mini summaries replaced")
  var rect: Rect2=item.rect
  if item.key=="palette-label":
   var node=sim.nodes[item.key];rect.size.x=node.get_theme_default_font().get_string_size(item.props.text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
   expect(rect.size.x<=210,"225px label's visible text fits 210px rail")
  expect(bounds.encloses(rect),"left rail contains visible item "+item.key)
  for other in rail:
   var attached=(item.key=="status-0" and other.key=="player-0") or (item.key=="status-1" and other.key=="player-1")
   expect(attached or not rect.intersects(other.rect),"left rail items never overlap "+item.key+" / "+other.key)
  rail.append({"key":item.key,"rect":rect})
 expect(sim.placement("summary-0-").rect==Rect2(48,428,70,78) and sim.placement("summary-0-黑").rect.end.y==584,"own summary grid exact start and bottom")

func entry_text_checks():
 var node=sim.nodes["enemy-palette-entry"];var spans=node.palette_entry_texts();var last=10.0
 for span in spans:
  var end=span.x+node.get_theme_default_font().get_string_size(span.text,HORIZONTAL_ALIGNMENT_LEFT,-1,span.fs).x
  expect(span.x>=last and end<=200.01,"enemy palette first-line text fits without overlap "+span.text)
  last=end
 expect(is_equal_approx(last,200),"enemy total right aligned at 200")
 expect(node.get_child_count()==5,"five enemy palette color cells")
 for i in range(5):
  var cell=node.get_child(i);var value=str(cell.props.value)
  expect(cell.position==Vector2(4+i*41,32) and cell.size==Vector2(38,32),"enemy color cell exact rectangle")
  expect(21+cell.get_theme_default_font().get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x<=35,"enemy color number fits cell "+value)
  expect(is_equal_approx(cell.modulate.a,0.45 if cell.props.value==0 else 1.0),"zero enemy color dimmed")
 if node.props.targets>0:
  expect(88+node.get_theme_default_font().get_string_size("目标 %d" % node.props.targets,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x<=132,"target badge text fits")
  expect(spans[0].x+node.get_theme_default_font().get_string_size(spans[0].text,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x<=84 and spans[1].x>=132,"target badge avoids title and total")

func enemy_sheet_geometry() -> Array:
 var seen=[];var rects=[];var sheet=sim.placement("enemy-palette-sheet")
 expect(sheet.kind=="enemy_palette_sheet" and sheet.rect==Rect2(268,72,764,356) and sheet.props.overlay,"enemy sheet exact overlay rectangle")
 for item in sim.placements:
  if not item.props.get("enemy_palette_cell",false):continue
  seen.append(item.key)
  expect(sheet.rect.encloses(item.rect) and item.rect.position.x>=284 and item.rect.end.x<=1016,"enemy sheet card inside content and sheet")
  expect(not item.interactive and not item.legal and not item.props.clickable and item.props.hide_stats,"enemy sheet card read only")
  expect(item.props.rotate_tapped and item.rect.size==(Vector2(109,78) if item.props.card.tapped else Vector2(78,109)),"enemy sheet card orientation and exact size")
  expect(sim.nodes[item.key].landscape==item.props.card.tapped and is_equal_approx(sim.nodes[item.key].art.rotation,PI/2 if item.props.card.tapped else 0.0),"enemy sheet art rotation")
  for rect in rects:expect(not rect.intersects(item.rect),"enemy sheet cards never overlap")
  for key in ["enemy-palette-close","page-enemy-palette-prev","page-enemy-palette-next"]:
   if not sim.placement(key).is_empty():expect(not sim.placement(key).rect.intersects(item.rect),"enemy header hit area avoids card "+key)
  rects.append(item.rect)
 expect(seen==current_keys("enemy-palette"),"enemy sheet matches pager metadata")
 return seen

func shortcut(code: int):
 var event=InputEventKey.new();event.keycode=code;event.pressed=true
 root.push_input(event,true);await settle()

func enemy_palette_checks():
 sim.dispatch("reset","");await settle();left_rail_checks();entry_text_checks()
 var state=sim.state;var before=state.snapshot();var entry=sim.placement("enemy-palette-entry")
 expect(entry.rect.size.x>=70 and entry.rect.size.y>=70 and entry.interactive,"idle enemy palette entrance touchable")
 await click(entry.key)
 expect(sim.enemy_palette_open and not state.drawer and state.zone_view.is_empty(),"enemy entrance opens mutually exclusive sheet")
 expect(state.snapshot()==before and sim.nodes[entry.key].palette_entry_border()==Color("#e9c175"),"enemy open preserves snapshot and paints active border")
 var seen=enemy_sheet_geometry()
 expect(seen.size()==state.players[1].palette.size(),"initial sheet contains all enemy palette cards")
 await shot("enemy-palette")
 var point=sim.nodes[seen[0]].get_global_rect().get_center()
 await click(seen[0]);expect(state.snapshot()==before,"readonly palette click does not change game")
 var down=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;down.position=point;down.global_position=point
 root.push_input(down,true);await create_timer(1.1).timeout
 expect(is_instance_valid(sim.preview),"readonly enemy palette long press opens inspection")
 var up=InputEventMouseButton.new();up.button_index=MOUSE_BUTTON_LEFT;up.position=point;up.global_position=point
 root.push_input(up,true);await process_frame;await click_at(Vector2(1800,840))
 expect(not is_instance_valid(sim.preview) and state.snapshot()==before,"enemy inspection closes without changing snapshot")
 await click(entry.key);expect(not sim.enemy_palette_open and sim.placement("enemy-palette-sheet").is_empty(),"second entrance click closes sheet")
 await click("zone-1-grave");await click(entry.key)
 expect(sim.enemy_palette_open and state.zone_view.is_empty() and state.snapshot()==before,"enemy entrance clears zone view without changing snapshot")
 await click("summary-0-蓝")
 expect(state.drawer and not sim.enemy_palette_open,"drawer closes enemy sheet")
 await click(entry.key);expect(not state.drawer and sim.enemy_palette_open,"enemy entrance closes drawer")
 await click("zone-0-grave");expect(not sim.enemy_palette_open and not state.zone_view.is_empty(),"zone closes enemy sheet")
 await shortcut(KEY_E);expect(sim.enemy_palette_open and state.zone_view.is_empty(),"E opens enemy palette")
 await shortcut(KEY_E);expect(not sim.enemy_palette_open,"E closes enemy palette")
 await click(entry.key);await click("enemy-palette-close");expect(not sim.enemy_palette_open,"enemy close button works")
 state.flood_enemy_palette();sim.refresh();await settle();await click(entry.key)
 var twin=load("res://experiments/android_layout_sim/sim_state.gd").new();twin.flood_enemy_palette()
 expect(state.snapshot()==twin.snapshot(),"enemy palette flood deterministic")
 var added=state.players[1].palette.slice(7);var ids=[];var old_ids=["41","42","45","8","15","17","22"]
 for i in range(added.size()):
  var card=added[i];ids.append(card.id)
  expect(card.id not in old_ids and not state.data(card.id).get("颜色",[]).is_empty() and ResourceLoader.exists(state.data(card.id).get("图片","")) and card.tapped==(i%3==2),"enemy flood unused colored art and tapped cadence")
 var sorted=ids.duplicate();sorted.sort();expect(added.size()==12 and ids==sorted,"enemy flood twelve cards in ID order")
 expect(sim.placement("pager-enemy-palette").props.pages>1,"enemy flood produces pages")
 entry_text_checks();before=state.snapshot();seen=[]
 while true:
  seen.append_array(enemy_sheet_geometry())
  var info=sim.placement("pager-enemy-palette").props
  expect(sim.placement("enemy-palette-page-number").props.text=="%d/%d" % [info.page+1,info.pages],"enemy page number")
  if info.page==info.pages-1:break
  await click("page-enemy-palette-next")
 var unique={}
 for key in seen:unique[key]=true
 expect(seen.size()==state.players[1].palette.size() and seen.size()==unique.size(),"all enemy pages partition palette exactly once")
 expect(state.snapshot()==before,"enemy paging preserves snapshot")
 await shot("enemy-palette-paged")
 sim.dispatch("reset","");await settle();await click(entry.key)
 var old_sheet=sim.nodes["enemy-palette-sheet"];sim.dispatch("hand",hand("spell-fdf-007"))
 expect(not old_sheet.visible,"TARGET hides departing enemy overlay immediately during transition")
 await settle()
 expect(state.phase=="TARGET" and not sim.enemy_palette_open,"TARGET automatically closes enemy sheet")
 entry=sim.placement(entry.key)
 expect(entry.interactive and entry.props.targets==7 and sim.nodes[entry.key].palette_entry_border()==Color("#5aa8ff"),"palette TARGET entrance has seven targets and blue border")
 entry_text_checks();state.palette_expanded=false;sim.refresh();await settle();await click(entry.key)
 expect(state.palette_expanded,"palette TARGET entrance expands legal cards")
 for i in range(3):await click(state.players[1].palette[i].key)
 await click("primary")
 expect(state.phase=="PAY" and not sim.placement(entry.key).interactive and is_equal_approx(sim.nodes[entry.key].modulate.a,0.45),"PAY disables and dims enemy palette")
 await shortcut(KEY_E);expect(not sim.enemy_palette_open,"E cannot open enemy sheet in PAY")
 sim.dispatch("reset","");await settle();await click(entry.key)
 var old_cells=[]
 for item in sim.placements:
  if item.props.get("enemy_palette_cell",false):old_cells.append(sim.nodes[item.key])
 sim.dispatch("hand",hand("96"))
 for node in old_cells:expect(not node.visible,"TARGET hides departing readonly cards immediately so legal units stay visible")
 await settle()
 expect(not sim.placement(entry.key).interactive,"TARGET without palette targets disables entrance")
 sim.dispatch("reset","");await settle();await opponent_click();await click(entry.key)
 expect(sim.enemy_palette_open,"RESPOND allows enemy palette")
 state.phase="OPP_THINK";sim.set_process(false);sim.refresh();await settle();await click(entry.key);await click(entry.key)
 expect(sim.enemy_palette_open,"OPP_THINK allows enemy palette")
 state.phase="RESOLVING";sim.refresh();await settle();await click(entry.key);await click(entry.key)
 expect(sim.enemy_palette_open,"RESOLVING allows enemy palette")
 state.phase="MAIN";state.use_card(hand("13"));sim.refresh();await settle()
 expect(state.phase=="PAY" and not sim.enemy_palette_open,"PAY automatically closes enemy sheet")
 sim.set_process(true);sim.dispatch("reset","");await settle()

func turn_checks():
 var turn=sim.placement("turn")
 if sim.state.phase in ["TARGET","PAY"]:expect(turn.is_empty(),"TARGET and PAY omit turn label");return
 expect(not turn.is_empty() and turn.kind=="phase" and turn.rect==Rect2(362,39,220,24) and turn.props.center,"turn label exact centered rectangle")
 expect(sim.placement("mat").rect.encloses(turn.rect) and not turn.rect.intersects(sim.placement("perm-zone--1-melody").rect),"turn fully inside mat and clear of melody")
 for item in sim.placements:
  if item.kind=="card" and item.props.card.zone=="units":expect(not turn.rect.intersects(item.rect),"turn avoids every unit")

func zone_strip_checks():
 sim.dispatch("reset","");await settle();turn_checks()
 var state=sim.state;var toggle=sim.placement("zone-strip-toggle");var before=state.snapshot()
 expect(toggle.rect==Rect2(954,500,70,70) and toggle.interactive and toggle.props.text=="区域\n+3" and toggle.props.zone_hidden and not sim.show_zone_strip,"zone strip initially hidden with exact toggle")
 await click(toggle.key);toggle=sim.placement("zone-strip-toggle")
 expect(sim.show_zone_strip and "收起" in toggle.props.text and state.snapshot()==before,"toggle shows strip without changing snapshot")
 var old=sim.nodes[strip_key("spell-fdf-012")];var hand_node=sim.nodes[hand("96")];var old_position=hand_node.position;var node_id=hand_node.get_instance_id()
 sim.dispatch("zone-strip",toggle.key)
 expect(not sim.show_zone_strip and strip_ids().is_empty() and sim.placement("strip-divider").is_empty(),"hide removes all strip placements")
 var motions=get_processed_tweens()
 for tween in motions:
  if tween.is_valid():tween.pause();tween.custom_step(0.09)
 expect(is_instance_valid(old) and old.modulate.a>0 and old.modulate.a<1,"zone strip fades out during 180ms")
 expect(hand_node.position!=old_position and not hand_node.position.is_equal_approx(sim.placement(hand("96")).rect.position),"hand moves through intermediate position during 180ms")
 for tween in motions:
  if tween.is_valid():tween.play()
 await settle()
 expect(state.snapshot()==before and hand_node.get_instance_id()==node_id,"strip hide preserves snapshot and hand nodes")
 for card in state.players[0].hand:
  var rect=sim.placement(card.key).rect
  expect(rect.position.x>=278 and rect.end.x<=946 and sim.nodes[card.key].position.is_equal_approx(rect.position),"hidden strip hand settles within narrowed band")
 expect(sim.placement(toggle.key).props.text=="区域\n+%d" % state.zone_playables().size() and state.zone_playables().size()==3,"hidden toggle shows actual plus three")
 expect(sim.placement("zone-0-grave").props.playable==1 and sim.placement("zone-exile").props.playable==1 and sim.placement("summary-0-").props.playable==1,"hidden strip retains source badges")
 await shot("zone-strip-hidden")
 await click("zone-0-grave");await click(zone_key("spell-fdf-012",0,"grave"))
 expect(state.phase=="PAY" and not sim.show_zone_strip and sim.placement(toggle.key).is_empty(),"hidden zone card usable from sheet and PAY omits toggle")
 turn_checks();sim.dispatch("reset","");await settle()
 before=state.snapshot();sim.dispatch("zone-strip",toggle.key)
 var fresh=sim.nodes[strip_key("spell-fdf-012")]
 expect(is_zero_approx(fresh.modulate.a),"restored strip starts transparent")
 await settle();expect(sim.show_zone_strip and strip_ids().size()+sim.placement("zone-more").props.count==3 and state.snapshot()==before,"toggle restores complete strip plus overflow without changing snapshot")
 await shortcut(KEY_H);expect(not sim.show_zone_strip,"H hides strip")
 await shortcut(KEY_H);expect(sim.show_zone_strip,"H restores strip")
 await opponent_click();turn_checks()
 expect(not sim.placement(toggle.key).is_empty() and sim.placement(toggle.key).props.count==state.zone_playables().size() and state.zone_playables().size()==2,"RESPOND toggle counts only fast zone cards")
 await click(toggle.key);expect("+2" in sim.placement(toggle.key).props.text,"RESPOND hidden toggle plus two")
 await click(hand("96"));expect(sim.placement(toggle.key).is_empty(),"TARGET omits zone strip toggle");turn_checks()
 sim.dispatch("reset","");await settle()
 expect(not sim.show_zone_strip and not sim.enemy_palette_open,"reset restores both view defaults")
 state.players[0].grave.clear();state.exile.clear()
 for card in state.players[0].palette:card.erase("free")
 sim.refresh();await settle()
 expect(sim.placement(toggle.key).is_empty(),"no zone playables omits toggle")
 var list=state.players[0].hand
 expect(sim.placement(list[0].key).rect.position.x==330+(640-(86*(list.size()-1)+100))/2.0,"absent toggle preserves original hand width and centering")
 sim.dispatch("reset","");await settle()

func hand_row_geometry(items: Array,title: String):
 var toggle=false
 for item in items:toggle=toggle or item.key=="zone-strip-toggle"
 var band=Rect2(278,470,668 if toggle else 744,130);var row=[]
 for item in items:
  var card=item.kind=="card" and not item.props.get("hand_sheet_cell",false) and (item.props.card.zone=="hand" or item.props.get("strip",false))
  if not card and item.kind not in ["more_tile","strip_divider"]:continue
  expect(band.encloses(item.rect),title+" entire hand row inside band "+item.key)
  if card:
   expect(item.props.get("hit_w",0)>=70 and item.props.hit_w<=100 and item.props.hide_stats,title+" exposed hit width and hidden stats "+item.key)
   row.append(item)
  if item.kind=="more_tile":expect(item.rect.size==Vector2(70,130) and item.props.action=="hand-sheet",title+" more tile touch geometry")
  for other in items:
   if other.key in ["zone-strip-toggle","primary","secondary-0","secondary-1"]:expect(not item.rect.intersects(other.rect),title+" row avoids controls "+item.key+" / "+other.key)
 for i in range(row.size()):
  var hit=Rect2(row[i].rect.position,Vector2(row[i].props.hit_w,130))
  for j in range(i):expect(not hit.intersects(Rect2(row[j].rect.position,Vector2(row[j].props.hit_w,130))),title+" exposed hit areas do not overlap")
 for item in items:
  if item.kind=="card" and item.props.card.zone=="units":expect(not item.props.get("hide_stats",false),title+" battlefield keeps unit stats")

func capacity_matrix():
 var model=sim.State.new()
 for h in [0,1,2,4,6,9,20,40]:
  for z in [0,1,2,3,15,40]:
   model.reset();model.players[0].hand=[];model.players[0].grave=[];model.exile=[]
   for card in model.players[0].palette:card.erase("free")
   for i in range(h):model.players[0].hand.append(model.instance("96",0,"hand"))
   for i in range(z):
    var card=model.instance("spell-ucs-050",-1,"exile");card.user=0;card.free=true;model.exile.append(card)
   for show_strip in [false,true]:
    var items=sim.layout.layout(model,Vector2(1300,600),{},{"show_zone_strip":show_strip})
    hand_row_geometry(items,"capacity %d/%d/%s" % [h,z,show_strip])
    var actual_z=z if show_strip else 0;var w=668 if z>0 else 744
    var base=(100 if h>0 else 0)+(100 if actual_z>0 else 0)+(16 if h>0 and actual_z>0 else 0)
    var gaps=maxi(0,h-1)+maxi(0,actual_z-1)
    if base+gaps*70>w:continue
    var step=minf(86,floorf(float(w-base)/gaps)) if gaps>0 else 86.0
    var start=278+(w-base-gaps*step)/2;var hand_index=0;var zone_index=0
    for item in items:
     expect(item.kind!="more_tile","fitting row has no overflow tiles")
     if item.kind!="card":continue
     if item.props.card.zone=="hand":
      expect(item.rect==Rect2(start+hand_index*step,470,100,130),"fitting hand equals original centered formula");hand_index+=1
     elif item.props.get("strip",false):
      var zone_start=start+(100+(h-1)*step+16 if h>0 else 0)
      expect(item.rect==Rect2(zone_start+zone_index*step,470,100,130),"fitting zone equals original centered formula");zone_index+=1
 model.reset();model.flood_hand()
 for i in range(model.players[0].hand.size()):model.players[0].hand[i].id="100"
 model.players[0].hand.back().id="96"
 var before=model.snapshot();var shown=[]
 for item in sim.layout.layout(model,Vector2(1300,600)):
  if item.kind=="card" and item.props.card.zone=="hand":shown.append(item.props.card)
 expect(shown.back().key==model.players[0].hand.back().key and model.snapshot()==before,"first hidden usable replaces last display slot without reordering state")
 for card in shown.slice(0,-1):expect(card.id=="100","promotion retains original order in earlier slots")

func sheet_geometry() -> Array:
 var sheet=sim.placement("hand-sheet");var seen=[];var rects=[];var i=0
 expect(sheet.rect==Rect2(268,72,764,356) and sheet.kind=="hand_sheet" and sheet.props.overlay,"hand sheet exact overlay")
 for item in sim.placements:
  if not item.props.get("hand_sheet_cell",false):continue
  var card=item.props.card;seen.append(card.key)
  expect(item.rect==Rect2(303+i%8*88,150+floori(i/8.0)*139,78,109) and sheet.rect.encloses(item.rect),"hand sheet exact grid card")
  expect(item.props.hide_stats and item.legal==sim.state.usable(card) and item.interactive==item.legal and item.props.dim==not item.legal,"hand sheet legality and dim follow usable")
  for rect in rects:expect(not rect.intersects(item.rect),"hand sheet cells do not overlap")
  for key in ["hand-sheet-close","hand-sheet-tab-hand","hand-sheet-tab-zone","page-hand-sheet-prev","page-hand-sheet-next"]:
   if not sim.placement(key).is_empty():expect(not item.rect.intersects(sim.placement(key).rect),"hand sheet header avoids cards")
  rects.append(item.rect);i+=1
 expect(seen==current_keys("hand-sheet"),"hand sheet visible cards match pager")
 return seen

func hand_capacity_checks():
 capacity_matrix();sim.dispatch("reset","");await settle()
 var state=sim.state
 expect(sim.placement("hand-more").is_empty() and sim.placement("zone-more").is_empty(),"default hidden strip avoids initial hand overflow")
 await show_strip();var old_step=floorf(452.0/(state.players[0].hand.size()+state.zone_playables().size()-2))
 expect(old_step==56 and not sim.placement("hand-more").is_empty() and not sim.placement("zone-more").is_empty(),"seven-card 56px stride necessarily becomes minimum-hit overflow")
 var twin=sim.State.new();state.flood_hand();twin.flood_hand()
 expect(state.snapshot()==twin.snapshot() and state.players[0].hand.size()==27,"hand flood deterministic twenty additional cards")
 var ids={};var kinds={"单位":[],"符卡":[]}
 for i in range(state.players[0].hand.size()):
  var card=state.players[0].hand[i]
  expect(not ids.has(card.id),"hand flood excludes existing hand IDs");ids[card.id]=true
  if i<7:continue
  var data=state.data(card.id);kinds[data["类别"]].append(card.id)
  expect(data["类别"]==("单位" if (i-7)%2==0 else "符卡") and ResourceLoader.exists(data["图片"]),"hand flood alternates unit and spell with real art")
 for kind in kinds:
  var sorted=kinds[kind].duplicate();sorted.sort();expect(sorted==kinds[kind],"hand flood category ID string order")
 state.flood_hand();twin.flood_hand();expect(state.snapshot()==twin.snapshot() and state.players[0].hand.size()==47,"hand flood repeatable and excludes current IDs")
 sim.dispatch("reset","");await shortcut(KEY_K)
 expect(state.players[0].hand.size()==27,"K floods twenty hand cards")
 await shot("hand-many")
 var visible=0
 for item in sim.placements:
  if item.kind=="card" and item.props.card.zone=="hand":visible+=1
 expect(sim.placement("hand-more").props.text=="+%d" % (state.players[0].hand.size()-visible),"hand-more exact hidden count text")
 var before=state.snapshot();await click("hand-more")
 expect(sim.hand_sheet=="hand" and not sim.placement("hand-sheet").is_empty() and state.zone_view.is_empty() and not sim.enemy_palette_open and not state.drawer,"hand tile opens exclusive hand sheet")
 expect(state.snapshot()==before and sim.placement("page-hand-sheet-next").interactive,"hand sheet is view-only and second page enabled")
 var seen=sheet_geometry();await click("page-hand-sheet-next");seen.append_array(sheet_geometry())
 expect(seen.size()==state.players[0].hand.size() and seen.size()==27,"all hand sheet pages cover entire hand")
 await click("page-hand-sheet-prev");var old_sheet=sim.nodes["hand-sheet"]
 await click("hand-sheet-"+hand("96"))
 expect(state.phase in ["TARGET","PAY","OPP_THINK"] and sim.hand_sheet.is_empty() and sim.placement("hand-sheet").is_empty(),"usable sheet card enters normal use flow and closes sheet")
 expect(not is_instance_valid(old_sheet) or not old_sheet.visible,"departing hand sheet cannot cover legal targets")
 sim.dispatch("reset","");await shortcut(KEY_K);await shortcut(KEY_Z)
 twin=sim.State.new();twin.flood_hand();twin.flood_zone_playables()
 expect(state.snapshot()==twin.snapshot() and state.zone_playables().size()==18,"Z floods fifteen usable zone instances deterministically")
 var added=[]
 for zone in ["grave","exile","palette"]:
  var initial={"grave":5,"exile":1,"palette":14}[zone]
  for card in (state.exile if zone=="exile" else state.players[0][zone]).slice(initial):
   expect(state.usable(card) and card.zone==zone and (card.seat==-1 and card.user==0 if zone=="exile" else card.seat==0),"every flooded zone card usable in original mechanism");added.append(card.key)
 expect(added.size()==15,"zone flood adds exact count across three zones")
 await show_strip();await shot("hand-zone-many")
 expect(strip_ids().size()<=2 and sim.placement("zone-more").props.count==state.zone_playables().size()-strip_ids().size(),"zone overflow at most two cards with correct hidden count")
 await click("hand-more");await shot("hand-sheet");await click("hand-sheet-tab-zone")
 expect(sim.hand_sheet=="zone","zone tab switches sheet")
 seen=sheet_geometry();await shot("hand-sheet-zone");await click("page-hand-sheet-next");seen.append_array(sheet_geometry())
 expect(seen.size()==state.zone_playables().size(),"zone sheet pages cover every usable zone instance")
 await click("hand-sheet-close");await click("zone-more")
 expect(sim.hand_sheet=="zone","zone-more opens zone tab directly")
 await click("zone-strip-toggle")
 expect(strip_ids().is_empty() and sim.placement("zone-more").is_empty() and sim.placement("hand-sheet-tab-zone").interactive,"hidden strip leaves zone tab enabled")
 expect(state.snapshot()==twin.snapshot(),"sheet tabs and strip switch never enter snapshot")
 await click("hand-sheet-close");await click("hand-more");await click("zone-0-grave")
 expect(sim.hand_sheet.is_empty() and not state.zone_view.is_empty(),"zone sheet closes hand sheet")
 await click("hand-more");expect(state.zone_view.is_empty(),"hand sheet closes zone sheet")
 await click("enemy-palette-entry");expect(sim.hand_sheet.is_empty() and sim.enemy_palette_open,"enemy palette closes hand sheet")
 await click("hand-more");expect(not sim.enemy_palette_open,"hand sheet closes enemy palette")
 await click("summary-0-蓝");expect(sim.hand_sheet.is_empty() and state.drawer,"drawer closes hand sheet")
 await click("hand-more");expect(not state.drawer,"hand sheet closes drawer")
 await click("hand-sheet-close");await opponent_click();await click("hand-more")
 expect(sim.hand_sheet=="hand","RESPOND permits hand sheet")
 for item in sim.placements:
  if item.props.get("hand_sheet_cell",false):expect(item.legal==(state.usable(item.props.card) and state.data(item.props.card.id).get("高速",false)),"RESPOND only fast usable hand cards legal")
 await click("hand-sheet-tab-zone")
 for item in sim.placements:
  if item.props.get("hand_sheet_cell",false):expect(state.data(item.props.card.id).get("高速",false) and item.legal,"RESPOND zone sheet only fast usable cards")
 state.start_resolving();sim.refresh();expect(sim.hand_sheet.is_empty(),"leaving MAIN/RESPOND closes hand sheet")
 sim.dispatch("reset","");await settle()
 expect(sim.hand_sheet.is_empty() and sim.anchors["hand-sheet"]=="","reset clears hand sheet and anchor")
 state.players[0].grave.clear();state.exile.clear()
 for card in state.players[0].palette:card.erase("free")
 state.flood_hand();sim.refresh();await settle();await click("hand-more")
 expect(not sim.placement("hand-sheet-tab-zone").interactive and sim.nodes["hand-sheet-tab-zone"].button.disabled,"empty zone tab disabled")
 sim.dispatch("reset","");await settle()

func hold_card(key: String):
 var node=sim.nodes[key];var point=node.get_global_transform()*Vector2(node.props.get("hit_w",node.size.x)/2,node.size.y/2)
 var down=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;down.position=point;down.global_position=point
 root.push_input(down,true);await create_timer(1.1).timeout
 var up=InputEventMouseButton.new();up.button_index=MOUSE_BUTTON_LEFT;up.position=point;up.global_position=point
 root.push_input(up,true);await settle()

func component_inspection_checks():
 sim.dispatch("reset","");await settle()
 var before=sim.state.snapshot();await hold_card(hand("13"))
 if expect(is_instance_valid(sim.preview),"hand unit long press 1.1s opens component inspection"):
  var art=sim.preview.find_child("CardInspectionArt",true,false);var rules=sim.preview.find_child("CardInspectionRules",true,false)
  expect(art is TextureRect and art.texture!=null,"component artwork texture is real")
  expect(rules is RichTextLabel,"component rules use keyword RichTextLabel")
  expect(sim.preview.get_parent().name=="SimInspectionLayer" and sim.preview.get_parent().layer==100 and sim.preview.size==Vector2(1950,900),"component preview uses unscaled layer 100")
  var panel=sim.preview.find_child("InspectionPanel",true,false);var close=sim.preview.find_child("InspectionClose",true,false)
  expect(panel.get_global_rect()==Rect2(375,60,1200,780) and Rect2(0,0,1950,900).encloses(panel.get_global_rect()),"details exact panel fully visible in logical canvas")
  expect(close.size.y>=105 and panel.get_global_rect().encloses(close.get_global_rect()),"details close button 105px and inside panel")
  expect(sim.shim.theme==sim.theme and sim.shim.ui_metrics.safe==Rect2(72,0,1806,900),"shim shares font theme and fixed Android metrics")
  expect("手牌" in sim.preview.find_child("InspectionInstanceStatus",true,false).text and sim.state.snapshot()==before,"instance details preserve state snapshot")
  await shot("inspect-unit")
  await click_at(Vector2(1800,840));expect(not is_instance_valid(sim.preview),"details mask closes component preview")
 await show_strip();await click("hand-more");await hold_card("hand-sheet-"+hand("13"))
 expect(is_instance_valid(sim.preview) and sim.preview.find_child("CardInspectionRules",true,false) is RichTextLabel,"hand sheet card shares component long press entry")
 await click_at(Vector2(1800,840));await click("hand-sheet-close")
 var chosen={};var found=[]
 for card in sim.state.players[0].hand+sim.state.zone_playables()+sim.state.players[0].units+sim.state.players[1].units:
  found=KeywordGlossary.matches(sim.shim.Store.CARDS[card.id].rules_text)
  if not found.is_empty():chosen=card;break
 if not expect(not chosen.is_empty(),"find keyword card in hand, zones or battlefield"):
  print("FAIL keyword search: no matching current card");return
 before=sim.state.snapshot();await hold_card(chosen.key)
 if not expect(is_instance_valid(sim.preview),"keyword card long press opens details"):return
 var art=sim.preview.find_child("CardInspectionArt",true,false);var info=sim.shim.Store.CARDS[chosen.id]
 expect((art.texture.get_width()>art.texture.get_height())==info.get("landscape",info.get("kind","") in ["符卡","结界"]),"inspection preview follows main landscape metadata and rotation")
 var rules=sim.preview.find_child("CardInspectionRules",true,false);var id=found[0].id
 rules.meta_clicked.emit("kw:"+id);await settle()
 if expect(is_instance_valid(KeywordGlossary.current),"keyword meta link opens existing definition popup"):
  expect(KeywordGlossary.current.term.text==KeywordGlossary.entry(id).term and KeywordGlossary.current.layer>sim.inspection_layer.layer,"definition term and layer above inspection")
  await shot("inspect-keyword")
  KeywordGlossary.current.close();await settle()
  expect(not is_instance_valid(KeywordGlossary.current) and is_instance_valid(sim.preview),"closing definition returns to details")
  rules.meta_clicked.emit("kw:"+id);await settle();await shortcut(KEY_ESCAPE)
  expect(not is_instance_valid(KeywordGlossary.current) and is_instance_valid(sim.preview),"ui_cancel closes definition before details")
  await shortcut(KEY_ESCAPE);expect(not is_instance_valid(sim.preview),"second ui_cancel closes details")
 await hold_card(chosen.key);rules=sim.preview.find_child("CardInspectionRules",true,false);rules.meta_clicked.emit("kw:"+id);await settle()
 sim.close_inspection();await settle()
 expect(not is_instance_valid(sim.preview) and not is_instance_valid(KeywordGlossary.current),"closing details also clears keyword popup")
 await hold_card(chosen.key);await click_at(Vector2(1800,840))
 expect(not is_instance_valid(sim.preview) and sim.state.snapshot()==before,"mask closes details with no snapshot changes")

func perm_cells() -> Array:
 var result=[]
 for item in sim.placements:
  if item.props.get("perm_cell",false):result.append(item)
 return result

func perm_geometry():
 var info=sim.placement("pager-perm-sheet").props;var keys=[];var i=0
 expect(sim.placement("perm-sheet").rect==Rect2(268,72,764,356) and sim.nodes["perm-sheet"].z_index==70,"permanent sheet exact rectangle and layer")
 for item in perm_cells():
  keys.append(item.props.card.key)
  expect(item.key=="perm-sheet-"+item.props.card.key and item.rect==Rect2(303+i*88,150,78,109),"permanent cells use ordered single row and real instance")
  expect(item.props.hide_stats and not item.props.rotate_tapped and sim.nodes[item.key].z_index==72,"permanent card upright with hidden stats at layer 72")
  expect(sim.nodes["perm-sheet-close"].z_index==73,"permanent controls layer 73")
  expect(sim.placement("perm-caption-"+item.props.card.key).rect==Rect2(303+i*88,261,78,18),"caption exact rectangle")
  i+=1
 expect(keys==info.keys_by_page[info.page] and keys.size()<=8,"permanent page shows exactly its eight or fewer keys")
 for item in sim.placements:
  if item.key.begins_with("perm-ability-") and item.kind=="button":
   var node=sim.nodes[item.key];var lines=node.get_meta("ability_lines")
   expect(lines.size()<=2 and node.button.size==item.rect.size,"ability label is at most two lines and actual button stays inside rectangle")
   for line in lines:expect(node.button.get_theme_font("font").get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x<=item.rect.size.x-24,"actual ability button text fits interior")

func finish_ability():
 sim.dispatch("pass","");sim.state.resolve_last();sim.refresh();await settle()
 expect(sim.state.phase=="MAIN","ability pass returns to MAIN")

func ability_model_checks():
 var s=sim.State.new();var g=s.players[0].items[3];var laser=s.players[0].times[0]
 expect(s.ability_state(s.players[1].items[0],0).reason=="对手的牌","enemy ability reason wins over mana")
 s.phase="PAY"
 expect(s.ability_state(s.players[0].items[0],0).reason=="支付费用时使用","mana reason wins over phase")
 expect(s.ability_state(g,0).reason=="当前阶段不可启动","phase reason wins over tapped")
 s.phase="MAIN"
 expect(s.ability_state(g,0).reason=="已横置" and s.ability_state(g,1).ok,"gourd initial availability")
 g.tapped=false;expect(s.ability_state(g,1).reason=="未横置","untap requires tapped source")
 laser.time=0;expect(s.ability_state(laser,0).reason=="计时不足","time availability reason")
 laser.time=4;s.players[0].units.clear();expect(s.ability_state(g,0).reason=="没有合法目标","target availability reason")
 g.tapped=true
 for card in s.players[0].palette+s.players[0].items:card.tapped=true
 expect(s.ability_state(g,1).reason=="颜色不足","payment availability reason")
 s.reset();g=s.players[0].items[3];s.phase="RESPOND"
 expect(s.ability_state(g,1).ok and not s.usable(s.players[0].hand.back()),"abilities can respond without high speed; melody cannot")
 s.source_phase=s.phase
 var before=s.snapshot();s.use_ability(g.key,1);s.cancel();expect(s.snapshot()==before,"cancel ability PAY restores exact gameplay state")
 before=s.snapshot();s.use_ability(s.players[0].times[0].key,1);s.cancel();expect(s.snapshot()==before,"cancel ability TARGET spends no time or mana")
 expect(s.ability_list(s.players[0].barriers[1]).is_empty(),"unlisted card has no abilities")
 var item=s.players[0].items[0];s.pending={"source":item.key}
 expect(item not in s.payment_sources() and s.players[1].items[0] not in s.payment_sources(),"payment excludes source and enemy items")
 s.reset();g=s.players[0].items[3];s.use_ability(g.key,1);s.activate();s.enter_zone(g,"grave");s.resolve_last()
 expect(g.zone=="grave" and not g.tapped,"untap ability ignores departed source")
 s.reset();laser=s.players[0].times[0];s.use_ability(laser.key,1);var victim=s.players[1].items[0]
 s.toggle_target(victim.key);s.confirm_targets();s.activate();s.enter_zone(victim,"grave");s.resolve_last()
 expect(s.players[1].grave.count(victim)==1,"destroy ignores departed target without duplicate grave entry")
 s.reset();var stone=s.players[0].barriers[0];var unit=s.players[1].units[0]
 s.use_ability(stone.key,0);s.toggle_target(unit.key);s.confirm_targets();s.resolve_last()
 expect(unit.ward==1 and stone.zone=="grave","ward ability supports unit target and immediate sacrifice")
 s.reset();var sources=s.payment_sources();var expected=[]
 for card in s.players[0].palette:
  if not card.tapped:expected.append(card.key)
 expected.append(s.players[0].items[0].key)
 var actual=[]
 for card in sources:actual.append(card.key)
 expect(actual==expected and s.summary(0).total==11 and s.summary(0)["红"]==7,"payment traverses palette then mana items while summary stays palette-only")
 s.reset();var melody=s.melody;s.enter_zone(melody,"grave");var song=s.players[0].hand.back()
 s.use_card(song.key);s.activate();s.resolve_last();expect(s.melody.id==song.id and s.last_event.begins_with("乐章进场"),"empty shared melody slot accepts new song")

func permanent_checks():
 sim.dispatch("reset","");sim.set_process(false);await settle()
 var state=sim.state
 ability_model_checks()
 var tiles=[]
 for item in sim.placements:
  if item.kind!="perm_zone":continue
  tiles.append(item)
  var seat=item.props.seat;var zone=item.props.zone;var index=state.PERM_ZONES.find(zone)
  var rect=Rect2(280,16,70,70) if seat==-1 else Rect2(794+index*78,16 if seat==1 else 398,70,70)
  expect(item.rect==rect and item.interactive and sim.nodes[item.key].z_index==20,"zone tile exact rectangle, touch and layer")
  if seat==1:expect(not rect.intersects(Rect2(600,0,184,96)),"top tiles avoid simulation controls")
  for other in sim.placements:
   if other.kind=="perm_zone" and other.key!=item.key:expect(not rect.intersects(other.rect),"zone tiles never overlap")
   if other.key=="turn" or other.kind in ["nameplate","summary","zone_button","palette_entry"] or (other.kind=="card" and other.props.card.zone in ["units","hand"]):expect(not rect.intersects(other.rect),"zone tile avoids units, turn, hand and rails")
 expect(tiles.size()==7 and state.players[0].hand.size()==7,"seven region entrances and seven initial hand cards")
 for seat in range(2):
  expect(sim.Shared.unit_metrics(state,seat).area==764,"unit area always 764")
  for card in state.players[seat].units:
   var rect=sim.placement(card.key).rect
   expect(rect.position.y==(267 if seat==0 else 111) if card.tapped else rect.position.y==(246 if seat==0 else 90),"units fixed to new row with centered tapped cards")
   if seat==0:expect(rect.end.y<=392 and rect.end.y<398,"own units clear permanent zones and hand row")
 var props=sim.placement("perm-zone-0-items").props
 expect(props.count==4 and props.mana==1 and props.usable==2,"own item count, untapped mana, available ability count")
 expect(sim.placement("perm-zone-0-barriers").props.usable==1,"keystone ready in barrier zone")
 props=sim.placement("perm-zone-0-times").props
 expect(props.usable==2 and props.time_min==2,"time zone usable abilities and minimum time")
 expect(sim.placement("perm-zone--1-melody").props.owner_name=="人机","shared song initial owner")
 for p in state.players:
  for zone in state.PERM_ZONES:
   for card in p[zone]:expect(card.has("time")== (zone=="times") and state.find_card(card.key)==card,"only time spells carry time; permanent lookup")
 await shot("perm-zones")
 var before=state.snapshot();await click("perm-zone-0-items");perm_geometry()
 expect(state.snapshot()==before and sim.perm_view=={"seat":0,"zone":"items"},"open permanent sheet preserves snapshot")
 await shot("perm-items-own")
 await click("perm-zone-0-items");expect(sim.perm_view.is_empty(),"same entrance toggles closed")
 await click("perm-zone-0-items");await click("perm-tab-times")
 expect(sim.perm_view.zone=="times" and sim.perm_selected.is_empty() and sim.anchors["perm-sheet"].is_empty(),"tab switch resets selection and anchor")
 var laser=state.players[0].times[0];await hold_card("perm-sheet-"+laser.key)
 if expect(is_instance_valid(sim.preview),"time spell 1.1 second hold opens inspection"):
  var status=sim.preview.find_child("InspectionInstanceStatus",true,false)
  expect(status!=null and "场上·时符" in status.text and "计时 4" in status.text and "能力：①支付1黄" in status.text,"inspection includes zone time and abilities")
  expect(state.snapshot()==before,"inspection preserves snapshot")
 sim.close_inspection();await settle();await click("perm-sheet-close")
 await click("perm-zone-0-items")
 var removed=sim.nodes["perm-sheet"];state.use_ability(laser.key,1);sim.refresh()
 expect(not removed.visible and removed.is_queued_for_deletion() and sim.perm_view.is_empty(),"enter TARGET hides and queues sheet in same frame")
 await settle();await click("perm-zone-1-items");await click("secondary-0")
 expect(sim.perm_view.is_empty() and state.phase=="MAIN","cancel TARGET closes its target sheet without reopening")
 # All five alternative views close the permanent sheet, and opening it closes each alternative.
 state.flood_hand();sim.refresh();await settle()
 for entry in ["zone-0-grave","enemy-palette-entry","hand-more","summary-0-蓝","summary-0-"]:
  await click("perm-zone-0-items");await click(entry)
  expect(sim.perm_view.is_empty(),"other panel closes permanent sheet: "+entry)
  await click("perm-zone-0-items")
  expect(state.zone_view.is_empty() and not state.drawer and not sim.enemy_palette_open and sim.hand_sheet.is_empty() and not sim.palette_classic,"permanent sheet closes all five alternatives")
  await click("perm-sheet-close")
 for phase in ["RESPOND","OPP_THINK","RESOLVING"]:
  state.phase=phase;sim.refresh();await settle();await click("perm-zone-0-items")
  expect(not sim.perm_view.is_empty(),"permanent entrance enabled during "+phase)
  await click("perm-sheet-close")
 sim.dispatch("reset","");await settle();state=sim.state
 await click("perm-zone-0-items")
 var gourd=state.players[0].items[3];var candle=state.players[0].items[0]
 await click("perm-sheet-"+gourd.key);perm_geometry()
 expect(sim.nodes["perm-ability-0"].button.disabled and sim.placement("perm-ability-0").props.reason=="已横置" and sim.placement("perm-ability-1").interactive,"gourd has disabled tap and enabled reset buttons")
 await shot("perm-ability-gourd")
 var old=[sim.nodes["perm-sheet"],sim.nodes["perm-sheet-"+gourd.key],sim.nodes["perm-ability-1"]]
 await click("perm-ability-1")
 expect(state.phase=="PAY" and state.costs==["红","绿"] and sim.perm_view.is_empty(),"gourd reset enters PAY with one red one green")
 for node in old:expect(not is_instance_valid(node) or (not node.visible and node.is_queued_for_deletion()),"PAY removes permanent sheet immediately")
 for tile in tiles:expect(not sim.placement(tile.key).interactive,"PAY disables all permanent entrances")
 var red=state.costs.find("红");await click("cost-%d" % red)
 expect(candle in state.candidates(red) and sim.placement("candidate-"+candle.key).props.combo=="道具·红","red payment candidates include candle as mana item")
 await click("candidate-"+candle.key);allocation_ok("item mana swap")
 await shot("perm-pay-mana")
 await click("primary")
 expect(candle.tapped and gourd.tapped and state.phase=="OPP_THINK" and state.stack.back().has("ability_name"),"mana item taps at activation and gourd waits for resolution")
 expect(state.stack.back().card.zone=="stack" and gourd.zone=="items","stack ability uses display copy and keeps source instance")
 var count=state.stack.size();await shortcut(KEY_O);expect(state.stack.size()==count,"O cannot add opponent object during ability thinking")
 await finish_ability();expect(not gourd.tapped,"gourd reset resolves untapped")
 await click("perm-zone-0-items");await click("perm-sheet-"+gourd.key);await click("perm-ability-0")
 var own=[]
 for unit in state.players[0].units:own.append(unit.key)
 expect(state.phase=="TARGET" and state.targets(state.pending)==own and sim.perm_view.is_empty(),"gourd tap targets own units only and closes sheet")
 var guide=sim.placement("guide");expect(guide.rect==Rect2(300,472,700,120),"target guide exact new rectangle")
 var regions=0
 for item in sim.placements:
  if item.kind=="region":expect(guide.rect.encloses(item.rect) and item.rect.size==Vector2(100,70),"six target region buttons contained and touch sized");regions+=1
 expect(regions==6,"six target regions")
 await global_checks("ability own-unit targets")
 var unit=state.players[0].units[0];var stats=sim.Card.stats_text(unit,state.data(unit.id))
 await click(unit.key);await click("primary")
 expect(state.phase=="OPP_THINK" and gourd.tapped and state.costs.is_empty(),"no mana ability commits tap only after confirming target")
 await finish_ability()
 expect(unit.counters.get("醉熏熏",0)==1 and unit.bonus==1 and sim.Card.stats_text(unit,state.data(unit.id))!=stats,"drunk counter increments all displayed stats")
 var d=state.data(unit.id)
 expect(sim.Card.stats_text(unit,d)=="%d/%d·%d" % [int(d.get("攻击力",0))+1,unit.hp+1,int(d.get("灵力",0))+1],"drunk stat string exact plus one")
 await click("perm-zone-0-items");var eel=state.players[0].items[2];var life=state.players[0].life
 await click("perm-sheet-"+eel.key);await click("perm-ability-0")
 expect(state.phase=="OPP_THINK" and eel.zone=="grave" and eel not in state.players[0].items,"eel sacrifices immediately without TARGET or PAY")
 await finish_ability();expect(state.players[0].life==life+1,"eel resolves one life")
 await click("perm-zone-0-barriers");var stone=state.players[0].barriers[0]
 await click("perm-sheet-"+stone.key);await click("perm-ability-0")
 expect(state.targets(state.pending).size()==13 and "player-0" in state.targets(state.pending) and "player-1" in state.targets(state.pending),"keystone targets all units and both players")
 await global_checks("keystone targets");await click("player-0");await click("primary")
 expect(stone.zone=="grave","keystone pays sacrifice before resolution")
 await finish_ability();expect(state.players[0].wards==3,"keystone increases player ward two to three")
 var ward=false
 for chip in sim.nodes["status-0"].status_chips:ward=ward or chip.status.short=="防避 3"
 expect(ward,"ward three visible in status capsule");await shot("perm-keystone-ward")
 sim.toast("old event");sim.dispatch("reset","");await settle();state=sim.state;laser=state.players[0].times[0]
 expect(sim.notification.text.is_empty() and sim.toast_time==0,"reset clears transient event toast")
 await click("perm-zone-0-times");await click("perm-sheet-"+laser.key);await click("perm-ability-1")
 var legal=state.ability_targets("barrier_or_item")
 expect(state.targets(state.pending)==legal and state.region_counts()["永久物区"]==9,"laser destroy legal targets and hidden region count")
 await click("region-永久物区")
 var victim=state.players[1].items[0]
 expect(sim.perm_view=={"seat":1,"zone":"items"} and sim.placement("perm-sheet-"+victim.key).legal,"permanent target region opens enemy items first with blue legal card")
 perm_geometry();await shot("perm-target-zone")
 await click("perm-sheet-"+victim.key)
 var endpoint=sim.draft_rect(sim.nodes["perm-sheet-"+victim.key]);expect(sim.arrows.segments.back()[1]==endpoint,"arrow uses live visible permanent card rectangle")
 await click("perm-sheet-close")
 expect(sim.arrows.segments.back()[1]==sim.draft_rect(sim.nodes["perm-zone-1-items"]),"hidden permanent arrow redirects to zone entrance")
 await click("primary");expect(state.phase=="PAY" and state.costs==["黄"],"laser destroy pays one yellow")
 await click("primary");expect(laser.time==3,"laser pays time only at activation")
 await finish_ability();expect(victim.zone=="grave" and victim in state.players[1].grave and sim.placement("perm-zone-1-items").props.count==1,"laser destroys enemy item into owner grave and updates zone count")
 for i in range(3):
  state.use_ability(laser.key,0);state.toggle_target("player-0");state.confirm_targets();state.activate();sim.refresh();await settle()
  if i==2:expect(laser.zone=="grave" and "计时归零" in sim.notification.text,"zero time sacrifices laser and shows one-shot toast")
  await finish_ability()
 expect(state.players[0].wards==14 and state.last_event.is_empty(),"three ward abilities resolve even after source leaves; event consumed")
 sim.dispatch("reset","");await settle();state=sim.state
 await click("perm-zone--1-melody");perm_geometry()
 expect(sim.placement("perm-rules").props.wrap and not perm_cells()[0].interactive,"shared melody sheet shows wrapped rules read only")
 await shot("perm-melody");await click("perm-sheet-close")
 var previous=state.melody;await click(hand("spell-ucs-033"))
 expect(state.phase=="PAY" and state.costs==["红","红","绿","绿"],"melody hand card pays two red two green without targets")
 await click("primary");await finish_ability()
 expect(state.melody.id=="spell-ucs-033" and state.melody.seat==0 and previous in state.players[1].grave and sim.placement("perm-zone--1-melody").props.owner_name=="你","new melody replaces shared slot and returns old song to owner grave")
 expect("乐章替换" in sim.notification.text,"melody replacement toast")
 await shot("perm-melody-replaced")
 sim.dispatch("reset","");await settle();state=sim.state
 var counts=[]
 for seat in range(2):
  for zone in state.PERM_ZONES:counts.append(state.players[seat][zone].size())
 var twin=sim.State.new();twin.flood_perms(4);await shortcut(KEY_P)
 expect(state.snapshot()==twin.snapshot(),"P permanent flood deterministic")
 var n=0
 for seat in range(2):
  for zone in state.PERM_ZONES:
   var cards=state.players[seat][zone];var ids=[]
   expect(cards.size()==counts[n]+4,"P adds four per seat per zone")
   for card in cards:
    expect(card.id not in ids and state.support_kind(card)==state.PERM_LABEL[zone] and ResourceLoader.exists(state.data(card.id).get("图片","")),"permanent flood unique category cards with actual art");ids.append(card.id)
   for i in range(4):expect(cards[counts[n]+i].tapped==(zone=="items" and i%3==2),"flood every third new item tapped; other types untapped")
   n+=1
 await click("perm-zone-0-items");perm_geometry()
 expect(perm_cells().size()==8 and sim.placement("pager-perm-sheet").props.pages==1,"eight items fit one page")
 await click("perm-sheet-close");await shortcut(KEY_P);await click("perm-zone-0-items")
 expect(sim.placement("pager-perm-sheet").props.pages==2,"more than eight items create two pages")
 perm_geometry();await click("page-perm-sheet-next");perm_geometry()
 expect(sim.placement("perm-sheet-page-number").props.text=="2/2","permanent pager follows second page anchor")
 await shot("perm-flood-paged");await click("page-perm-sheet-prev");perm_geometry()
 await click("perm-sheet-"+state.players[0].items[0].key)
 expect(sim.nodes["perm-ability-0"].button.disabled and sim.placement("perm-ability-0").props.reason=="支付费用时使用","mana ability is listed disabled with PAY reason")
 await click("perm-tab-barriers");await click("perm-sheet-"+state.players[0].barriers[1].key)
 expect(not sim.placement("perm-ability-none").is_empty(),"selecting card with no abilities shows explanation")
 await click("perm-sheet-close");await click("perm-zone-1-items");perm_geometry()
 for cell in perm_cells():expect(not cell.interactive and not cell.legal,"enemy permanent cards read only")
 expect(sim.placement("perm-ability-title").is_empty(),"enemy sheet has no ability bar")
 await click("perm-sheet-close");state.use_ability(state.players[0].times[0].key,1);sim.refresh();await settle();await click("perm-zone-1-items")
 state.players[1].items.clear();sim.refresh()
 expect(sim.perm_view.is_empty(),"TARGET closes sheet when its last legal target leaves")
 state.cancel();sim.refresh();await settle();state.players[1].barriers.clear();sim.refresh();await settle();await click("perm-zone-1-barriers")
 expect(not sim.placement("perm-empty").is_empty(),"empty permanent area still opens with empty label")
 state.untap_all()
 for p in state.players:
  for zone in state.PERM_ZONES:
   for card in p[zone]:expect(not card.tapped,"untap includes all permanent zones")
 sim.set_process(true);sim.dispatch("reset","");await settle()

func text_ink_bounds(font: Font,value: String,fs: int,baseline: float) -> Vector2:
 # Measure nontransparent glyph pixels; font ascent includes unused line leading.
 var server=TextServerManager.get_primary_interface();var rid=font.get_rids()[0];var bounds=Vector2(INF,-INF)
 for ch in value:
  var glyph=server.font_get_glyph_index(rid,fs,ch.unicode_at(0),0)
  var offset=server.font_get_glyph_offset(rid,Vector2i(fs,0),glyph)
  var index=server.font_get_glyph_texture_idx(rid,Vector2i(fs,0),glyph)
  if index<0:continue
  var image=server.font_get_texture_image(rid,Vector2i(fs,0),index)
  var uv=server.font_get_glyph_uv_rect(rid,Vector2i(fs,0),glyph)
  var ink=image.get_region(Rect2i(uv)).get_used_rect()
  if not ink.has_area():continue
  bounds.x=minf(bounds.x,baseline+offset.y+ink.position.y)
  bounds.y=maxf(bounds.y,baseline+offset.y+ink.end.y)
 return bounds

func rank_checks():
 sim.dispatch("reset","");await settle()
 var state=sim.state
 expect(sim.placement("player-0").props.rank=={"tier":2,"level":3,"stars":2} and sim.placement("player-1").props.rank=={"tier":3,"level":2,"stars":1},"initial ranks passed read only to nameplates")
 for seat in range(2):
  var node=sim.nodes["player-%d" % seat];var spans=node.nameplate_texts();var font=node.get_theme_default_font()
  expect(spans.size()==3 and [spans[0].y,spans[1].y,spans[2].y]==([25,42,58] if seat==0 else [22,38,52]),"rank text three exact baselines")
  expect(font.get_string_size(spans[1].text,HORIZONTAL_ALIGNMENT_LEFT,-1,spans[1].fs).x<=100,"rank caption actual width at most 100")
  var ink=[]
  for span in spans:ink.append(text_ink_bounds(font,span.text,span.fs,span.y))
  for i in range(2):expect(ink[i].y<=ink[i+1].x,"rank text ink lines do not overlap")
  if seat==1:expect(ink[2].y<58,"enemy text bottom above status capsule")
  else:expect(ink[0].x>=12,"own name top below status capsule")
 await player_hold(0)
 var sheet=sim.preview.find_children("*","Control",true,false)
 var found=false
 for node in sheet:
  if node.get("kind")=="status_sheet":found=node.props.rank==state.players[0].rank and node.status_rank_text().begins_with("段位 · ")
 expect(found,"status sheet receives rank for first inserted rank row")
 await click_at(Vector2(1800,840))
 var tiers=[]
 for i in range(6):
  await shortcut(KEY_B);tiers.append(state.players[0].rank.get("tier",-1))
  if i==1:
   expect(state.players[0].rank=={"tier":4,"position":128},"sage uses own position 128")
   await shot("rank-sage")
  if i==2:
   expect(state.players[0].rank.is_empty(),"rank supports offline empty dictionary")
   var spans=sim.nodes["player-0"].nameplate_texts()
   expect(spans.size()==2 and spans[0].y==25 and spans[0].fs==15 and spans[1].y==44,"unranked nameplate keeps original text geometry")
   await shot("rank-none")
 expect(tiers==[3,4,-1,0,1,2] and state.players[1].rank.tier==3,"six B presses return both initial tiers")
 expect(state.players[0].rank=={"tier":2,"level":2,"stars":1} and state.players[1].rank=={"tier":3,"level":1,"stars":2},"rank cycle uses specified normalized level/stars")
 sim.dispatch("reset","");await settle()

func classic_checks():
 sim.dispatch("reset","");await settle()
 var state=sim.state;var before=state.snapshot();var label=sim.placement("palette-label");var total=sim.placement("summary-0-")
 expect(label.interactive and total.interactive and label.props.action==total.props.action and label.rect.position.x==total.rect.position.x and label.rect.end.y+2==total.rect.position.y,"label exemption shares adjacent summary hit column")
 await click("summary-0-")
 var item=sim.placement("palette-classic")
 expect(sim.palette_classic and item.rect==Rect2(268,244,764,150) and item.kind=="drawer" and not item.props.vertical and item.props.classic,"total opens existing horizontal drawer")
 expect(item.props.groups.size()==state.grouped(0).size() and sim.nodes[item.key].z_index==70 and sim.placement("summary-0-").props.active,"classic groups and active total border")
 var scroll=sim.nodes[item.key].get_child(0)
 expect(scroll is ScrollContainer and scroll.get_child(0).size.x>scroll.size.x and scroll.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED,"classic content overflows horizontally without pagination")
 expect(item.props.summary_text=="可用 11/14" and not item.rect.intersects(Rect2(0,470,1300,130)),"classic summary correct and avoids hand row")
 expect(state.snapshot()==before,"classic opening preserves snapshot")
 await shot("palette-classic")
 await click("summary-0-");expect(not sim.palette_classic,"same total closes classic")
 await click("palette-label");expect(sim.palette_classic,"label opens same classic drawer")
 await click_at(sim.nodes["palette-classic"].get_global_transform()*Vector2(382,16));expect(not sim.palette_classic,"classic handle closes drawer")
 await shortcut(KEY_Y);await click("summary-0-蓝")
 expect(not sim.palette_classic and state.drawer and state.drawer_filter=="蓝","color entry switches to vertical drawer")
 await shortcut(KEY_Y);expect(sim.palette_classic and not state.drawer,"Y opens classic and closes vertical drawer")
 for key in ["zone-0-grave","enemy-palette-entry"]:
  await click(key);expect(not sim.palette_classic,"opening other sheet closes classic")
  await shortcut(KEY_Y);expect(state.zone_view.is_empty() and not sim.enemy_palette_open,"classic closes zone and enemy palette")
 state.flood_hand();state.flood_perms();sim.refresh();await settle()
 await click("hand-more");expect(not sim.palette_classic,"hand sheet closes classic")
 await shortcut(KEY_Y);expect(sim.hand_sheet.is_empty(),"classic closes hand sheet")
 sim.dispatch("perm-zone","perm-zone-1-times");expect(not sim.palette_classic,"permanent zone sheet closes classic")
 await shortcut(KEY_Y);expect(sim.perm_view.is_empty(),"classic closes permanent zone sheet")
 sim.dispatch("reset","");await settle();await shortcut(KEY_O);await shortcut(KEY_Y)
 expect(state.phase=="RESPOND" and sim.palette_classic,"RESPOND permits classic entry")
 await shot("palette-classic-respond")
 sim.set_process(false)
 for phase in ["OPP_THINK","RESOLVING"]:
  state.phase=phase;sim.palette_classic=false;sim.refresh();await settle();await shortcut(KEY_Y)
  expect(sim.palette_classic,"classic allowed during "+phase)
 state.phase="MAIN";sim.refresh();await settle()
 var old=sim.nodes["palette-classic"]
 state.use_card(hand("96"));sim.refresh()
 expect(not sim.palette_classic and not old.visible and old.is_queued_for_deletion(),"TARGET removes classic same frame without fade")
 expect(not sim.placement("summary-0-").interactive and not sim.placement("palette-label").interactive,"TARGET disables both classic entries")
 await shortcut(KEY_Y);expect(not sim.palette_classic,"TARGET refuses Y")
 state.cancel();sim.refresh();await settle();await shortcut(KEY_Y);old=sim.nodes["palette-classic"]
 state.use_card(hand("13"));sim.refresh()
 expect(state.phase=="PAY" and not sim.palette_classic and not old.visible and old.is_queued_for_deletion(),"PAY removes classic same frame")
 expect(not sim.placement("summary-0-").interactive and not sim.placement("palette-label").interactive and sim.placement("palette-label").props.text=="颜色盘 · 付前→付后","PAY preserves label and disables classic")
 await shortcut(KEY_Y);expect(not sim.palette_classic,"PAY refuses Y")
 sim.set_process(true);sim.dispatch("reset","");await settle()
 expect(not sim.palette_classic and sim.perm_view.is_empty(),"reset clears new view states")

func run():
 root.gui_embed_subwindows=true
 sim=load("res://experiments/android_layout_sim/sim_main.tscn").instantiate();root.add_child(sim)
 await settle()
 model_checks()
 await inspection_checks()
 await scrolling_checks()
 await run_layout()
 await paging_checks()
 await zone_checks()
 await enemy_palette_checks()
 await zone_strip_checks()
 await hand_capacity_checks()
 await component_inspection_checks()
 await permanent_checks()
 await rank_checks()
 await classic_checks()
 sim.queue_free();await process_frame
 print("checks=%d failures=%d" % [checks,failures])
 quit(1 if failures>0 else 0)
