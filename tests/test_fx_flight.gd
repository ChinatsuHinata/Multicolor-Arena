extends SceneTree
## 飞行契约专项验收：内存探针与真实入场模块，不启动对战或读取存档。

const Manifest=preload("res://fx/fx_manifest.gd")
const Registry=preload("res://fx/fx_registry.gd")
const Bridge=preload("res://fx/fx_bridge.gd")
const Entrance=preload("res://fx/categories/fx_entrance_module.gd")
const Fixture=preload("res://tests/support/fx_registry_fixture.gd")
const CARD_SIZE=Vector2(1.95,2.72)

var checks=0
var failures: Array[String]=[]

func expect(ok: bool,message: String) -> void:
 checks+=1
 if not ok:
  failures.append(message)
  push_error("FX FLIGHT FAIL: "+message)

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 check_manifest()
 check_transforms()
 await check_proxy()
 await check_reimu()
 finish()

func check_manifest() -> void:
 var base={"id":"probe","category":"entrance","script":"res://fx/modules/reimu_yinyang_gather/effect.gd","timing":"before","flight":"proxy"}
 var path="res://fx/definitions/probe.json"
 expect(Manifest.validate(base,path).is_empty(),"before proxy manifest is valid")
 var spell=base.duplicate();spell.category="spell"
 expect(Manifest.validate(spell,path)=="flight only applies to entrance effects","spell rejects flight")
 var after=base.duplicate();after.erase("timing")
 expect(Manifest.validate(after,path)=="flight requires timing before","default after rejects proxy")
 var invalid=base.duplicate();invalid.flight="fly"
 expect(Manifest.validate(invalid,path)=="flight must be one of none, track, proxy","unknown flight mode is rejected")
 invalid.flight=1
 expect(Manifest.validate(invalid,path)=="flight must be one of none, track, proxy","non-string flight is rejected")
 var track=base.duplicate();track.flight="track"
 expect(Manifest.validate(track,path).is_empty(),"before track is valid")
 track.timing="after"
 expect(Manifest.validate(track,path)=="flight requires timing before","after track is rejected")
 after.flight="none"
 expect(Manifest.validate(after,path).is_empty() and Registry.flight({})=="none","none allows after and is the default")

 var duration=base.duplicate();duration.flight_ms=750
 expect(Manifest.validate(duration,path).is_empty(),"proxy accepts flight_ms 750")
 expect(is_equal_approx(Registry.flight_ms(duration),750.0) and Registry.flight_ms(base)==0.0,"registry returns flight_ms or zero")
 duration.flight_ms=150
 expect(Manifest.validate(duration,path)=="flight_ms must be between 200 and 2000","flight_ms 150 is rejected")
 duration.flight_ms=750;duration.flight="track"
 expect(Manifest.validate(duration,path)=="flight_ms requires flight proxy","track rejects flight_ms")
 for value in [200,2000]:
  duration.flight="proxy";duration.flight_ms=value
  expect(Manifest.validate(duration,path).is_empty(),"proxy accepts flight_ms boundary %d" % value)
 for value in [2001,"750",true]:
  duration.flight_ms=value
  expect(Manifest.validate(duration,path)=="flight_ms must be between 200 and 2000","out-of-range and nonnumeric flight_ms are rejected")
 duration.erase("flight")
 expect(Manifest.validate(duration,path)=="flight_ms requires flight proxy","missing flight rejects flight_ms")
 var easing=base.duplicate();easing.flight_ease="sine_in_out"
 expect(Manifest.validate(easing,path).is_empty(),"proxy accepts sine_in_out")
 easing.flight_ease="bounce"
 expect(Manifest.validate(easing,path)=="flight_ease must be one of cubic_in_out, sine_in_out, linear","unknown flight_ease is rejected")
 easing.flight_ease="sine_in_out";easing.flight="track"
 expect(Manifest.validate(easing,path)=="flight_ease requires flight proxy","track rejects flight_ease")

func check_transforms() -> void:
 var from=Transform3D(Basis.from_euler(Vector3(0.3,0.2,-0.1)).scaled(Vector3.ONE*0.7),Vector3(-3.0,2.0,2.0))
 var to=Transform3D(Basis.from_euler(Vector3(-0.2,0.4,0.1)).scaled(Vector3.ONE*1.4),Vector3(1.0,0.0,-2.0))
 var module=Entrance.new()
 module.configure({"timing":"before"},{"landing":to,"travel":0.8,"flight":{"from":from,"to":to,"seconds":0.3}})
 expect(is_equal_approx(module.flight_seconds(),0.3),"flight seconds override travel")
 expect(module.flight_global(0.0).is_equal_approx(from),"flight starts at the complete from transform")
 expect(module.flight_global(0.3).is_equal_approx(to),"flight ends at the complete to transform")
 expect(module.flight_global(0.15).origin.distance_to(from.origin.lerp(to.origin,0.5))<0.001,"cubic midpoint is the origin midpoint")
 var quarter=module.flight_global(0.075).origin
 expect(quarter.distance_to(from.origin.lerp(to.origin,0.0625))<0.001,"cubic quarter progresses by 0.0625")
 expect(module.flight_global(0.15).basis.get_scale().distance_to(from.basis.get_scale().lerp(to.basis.get_scale(),0.5))<0.001,"flight interpolates scale")
 expect(module.in_flight(0.15) and not module.in_flight(0.3),"flight interval excludes its endpoint")
 module.ctx.flight.ease="linear"
 expect(module.flight_global(0.075).origin.distance_to(from.origin.lerp(to.origin,0.25))<0.001,"linear easing progresses linearly")
 module.ctx.flight.ease="sine_in_out"
 var seconds=module.flight_seconds()
 expect(module.flight_global(0.5*seconds).origin.distance_to(from.origin.lerp(to.origin,0.5))<0.001,"sine midpoint is the origin midpoint")
 var sine_quarter=(1.0-cos(PI*0.25))/2.0
 var sine_progress=(module.flight_global(0.25*seconds).origin-from.origin).length()/from.origin.distance_to(to.origin)
 expect(absf(sine_progress-sine_quarter)<0.001,"sine quarter progresses by approximately 0.1464")
 module.ctx.flight.erase("to")
 expect(module.flight_global(0.3).is_equal_approx(to),"missing to falls back to landing")
 module.ctx.flight.seconds=-0.2
 expect(module.flight_seconds()==0.0 and module.flight_global(0.0).is_equal_approx(to),"nonpositive duration lands immediately")
 module.ctx.erase("flight")
 expect(is_equal_approx(module.flight_seconds(),0.8),"missing flight uses travel")
 module.timing="after"
 expect(module.flight_seconds()==0.0,"after effects have no flight time")
 var host=Node3D.new();root.add_child(host)
 host.position=Vector3(2.0,1.0,3.0)
 var card=Node3D.new();host.add_child(card)
 card.transform=from
 module.configure({"timing":"before"},{"node":card,"landing":to})
 expect(module.flight_global(0.0).is_equal_approx(card.global_transform),"no flight dictionary tracks the live node globally")
 card.position+=Vector3(1.0,2.0,3.0)
 expect(module.flight_global(0.15).is_equal_approx(card.global_transform),"live tracking observes later movement")
 module.ctx.erase("node")
 expect(module.flight_global(0.0).is_equal_approx(to),"missing node falls back to landing")
 expect(module.flight_local()==Transform3D.IDENTITY,"missing holder has identity local transform")
 module.free();host.free()

func check_proxy() -> void:
 var host=Node3D.new();root.add_child(host)
 var bridge=Bridge.new()
 var stage=bridge.attach(host)
 stage.auto_step=true;stage.set_process(false)
 var registry=Fixture.create()
 var first=registry.definitions.probe_entrance.duplicate(true)
 first.id="probe_proxy_first";first.timing="before";first.flight="proxy";first.priority=1
 first.budget_ms=1000;first.flight_ms=900;first.flight_ease="linear"
 var second=first.duplicate(true);second.id="probe_proxy_second";second.priority=2
 registry.definitions={second.id:second,first.id:first}
 stage.use_registry(registry)
 var image=Image.create(2,2,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE)
 var texture=ImageTexture.create_from_image(image)
 var landing=Transform3D(Basis.IDENTITY,Vector3(1.0,0.0,2.0))
 var ctx={"uid":41,"card_size":CARD_SIZE,"landing":landing,"travel":0.3,"flight":{"from":Transform3D.IDENTITY,"to":landing,"seconds":0.3,"ease":"cubic_in_out","texture":texture}}
 var started=stage.play("entrance",ctx)
 expect(started.size()==2,"both proxy probes start")
 var owners=started.filter(func(module):return module.owns_flight())
 expect(owners.size()==1,"exactly one module owns the flight")
 expect(owners.size()==1 and owners[0].id==first.id,"the highest priority probe owns the flight")
 var proxies=0
 for module in started:
  for child in module.holder.get_children():
   if str(child.name)=="FlightProxy":proxies+=1
 expect(proxies==1,"holders contain exactly one FlightProxy")
 expect(bridge.owns_flight(started),"bridge detects flight ownership")
 expect(is_equal_approx(bridge.flight_seconds(started),0.9),"bridge returns the owned flight duration")
 expect(is_equal_approx(stage.last_flight_seconds,0.9),"stage records the manifest flight duration")
 expect(is_equal_approx(ctx.travel,0.3) and is_equal_approx(ctx.flight.seconds,0.3) and ctx.flight.ease=="cubic_in_out","stage preserves the caller's flight context")
 if owners.size()==1:
  var owner=owners[0]
  expect(is_equal_approx(owner.flight_seconds(),0.9) and is_equal_approx(owner.ctx.travel,0.9),"proxy uses flight_ms for travel and flight seconds")
  expect(owner.ctx.flight.ease=="linear","proxy uses the manifest flight easing")
  expect(owner.ctx.flight.texture==texture and owner.proxy.material_override.albedo_texture==texture,"deep context copies retain the same texture resource")
  expect(owner.proxy.mesh.size==CARD_SIZE and owner.proxy.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"proxy has card dimensions and no shadow")
  expect(owner.proxy.material_override.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and owner.proxy.material_override.cull_mode==BaseMaterial3D.CULL_DISABLED,"proxy is opaque and double sided")
  stage.advance_all(0.95)
  expect(owner.proxy.visible and (owner.holder.global_transform*owner.proxy.transform).is_equal_approx(landing),"proxy waits visibly at landing after its flight")
  stage.landed(99)
  expect(owner.proxy.visible,"landing a different uid leaves the proxy visible")
  stage.landed(41)
  expect(not owner.proxy.visible and not owner.in_flight(),"landing hides the proxy and ends flight")
  stage.advance_all(0.01)
  expect(not owner.proxy.visible,"updates keep a landed proxy hidden")
 stage.advance_all(1.0)
 await process_frame
 expect(stage.layer("entrance").get_child_count()==0,"completed proxy probes leave no Fx_ holders")
 expect(not bridge.owns_flight(started),"released proxies no longer own the flight")
 expect(bridge.flight_seconds(started)==0.0,"released proxies have no flight duration")
 ctx.flight.erase("texture")
 started=stage.play("entrance",ctx)
 expect(started.size()==2 and not bridge.owns_flight(started),"flight without texture or color creates no proxy")
 expect(bridge.flight_seconds(started)==0.0 and stage.last_flight_seconds==0.0,"no proxy resets the stage duration and bridge returns zero")
 expect(started.all(func(module):return not module.holder.has_node("FlightProxy")),"no proxy node exists without visual data")
 stage.advance_all(1.0)
 await process_frame
 expect(stage.layer("entrance").get_child_count()==0,"nonproxy probes leave no Fx_ holders")
 first.erase("flight_ms");second.erase("flight_ms")
 ctx.flight.color=Color("#8a6d80")
 started=stage.play("entrance",ctx)
 owners=started.filter(func(module):return module.owns_flight())
 expect(owners.size()==1 and owners[0].proxy.material_override.albedo_color==ctx.flight.color,"color-only flight builds a solid-color proxy")
 expect(is_equal_approx(bridge.flight_seconds(started),0.3) and stage.last_flight_seconds==0.0,"proxy without flight_ms keeps its original duration and records zero")
 bridge.unit_landed(41)
 expect(owners.size()==1 and not owners[0].proxy.visible,"bridge forwards landing to the stage")
 stage.advance_all(1.0)
 await process_frame
 host.free()

func check_reimu() -> void:
 var host=Node3D.new();root.add_child(host)
 var bridge=Bridge.new()
 var stage=bridge.attach(host)
 stage.auto_step=true;stage.set_process(false)
 var registry=Registry.new();registry.allow_all=true
 var def=registry.get_effect("reimu_yinyang_gather")
 expect(not def.is_empty() and registry.errors.is_empty(),"real Reimu manifest loads")
 if def.is_empty():host.free();return
 stage.use_registry(registry)
 var landing=Transform3D(Basis.IDENTITY,Vector3(1.0,0.0,-1.0))
 var from=Transform3D(Basis.from_euler(Vector3(0.8,0.2,0.1)).scaled(Vector3.ONE*0.8),landing.origin+Vector3(-3.0,2.0,2.0))
 var ctx={"uid":77,"card_size":CARD_SIZE,"landing":landing,"travel":0.3,"flight":{"from":from,"to":landing,"seconds":0.3,"color":Color("#8a6d80")}}
 var positions: Array[Vector3]=[]
 for run_index in range(2):
  var started=stage.play("entrance",ctx)
  var matches=started.filter(func(module):return module.id==def.id)
  expect(matches.size()==1,"Reimu starts once, run %d" % run_index)
  if matches.is_empty():continue
  var module=matches[0]
  var flight_t=float(def.flight_ms)/1000.0
  expect(is_equal_approx(module.flight_seconds(),flight_t) and is_equal_approx(module.ctx.travel,flight_t),"real manifest overrides 0.3 second travel with flight_ms")
  expect(module.ctx.flight.ease=="sine_in_out" and is_equal_approx(stage.last_flight_seconds,flight_t),"real manifest sets sine easing and stage duration")
  var gather=minf(module.flight_seconds()+float(def.params.settle_ms+def.params.charge_ms)/1000.0,module.budget-0.25)
  expect(is_equal_approx(gather,flight_t+0.29) and module.budget-gather>=0.5,"Reimu gathers right after landing and scatters for at least 0.5 seconds")
  module.advance(flight_t*0.5)
  expect(module.owns_flight(),"Reimu owns a flight proxy")
  expect(module.orbs.size()==6 and module.orbs.all(func(orb):return orb.get_parent()==module.holder),"six orbs live directly under the holder")
  expect(module.count_nodes(module.holder)<=64,"Reimu respects node budget including proxy")
  var front=0;var back=0
  var colors: Array[Color]=[]
  for i in range(module.orbs.size()):
   var orb=module.orbs[i]
   var color: Color=orb.material_override.get_shader_parameter("glow")
   expect(color.is_equal_approx(Color(def.params.halos[i])) and module.orb_halo[i].is_equal_approx(color),"orb %d uses its halo color" % i)
   colors.append(color)
   if is_instance_valid(module.proxy):
    var local=module.proxy.transform.affine_inverse()*orb.position
    if local.y>0.0:front+=1
    if local.y<0.0:back+=1
    var radius=float(def.params.orbit_radius)*CARD_SIZE.x*module.proxy.transform.basis.get_scale().x*1.25
    expect(orb.position.distance_to(module.proxy.position)<=radius,"orb %d stays within the flight orbit" % i)
   if run_index==0:positions.append(orb.position)
   else:expect(orb.position.is_equal_approx(positions[i]),"orb %d flight is deterministic for the same uid" % i)
  expect(front>0 and back>0,"orbs surround both sides of the proxy card")
  var unique=true
  for i in range(colors.size()):
   for j in range(i):
    if colors[i].is_equal_approx(colors[j]):unique=false
  expect(unique,"all six halo uniforms are distinct")
  for plane in [module.converge,module.ring,module.inner,module.flash]:
   expect(is_zero_approx(float(plane.material_override.get_shader_parameter("alpha"))),"all rings are hidden during flight")
  module.advance(flight_t+0.15-module.elapsed)
  expect(module.proxy.visible and not module.landed,"proxy remains visible after the flight without a landing notification")
  for orb in module.orbs:
   expect(Vector2(orb.position.x,orb.position.z).length()<=0.8*CARD_SIZE.x,"landed orb stays within 0.8 card widths of the holder origin")
  var holder=weakref(module.holder)
  module.advance(module.budget-module.elapsed)
  expect(module.finished,"Reimu finishes at budget")
  await process_frame
  expect(not is_instance_valid(module.holder) and holder.get_ref()==null,"Reimu frees its holder after budget")
  stage.stop_all()
  await process_frame
 ctx.erase("flight");ctx.travel=0.0
 var fallback=stage.play("entrance",ctx).filter(func(module):return module.id==def.id)
 expect(fallback.size()==1 and not fallback[0].owns_flight(),"zero travel without flight starts the fallback")
 for module in fallback:
  var holder=weakref(module.holder)
  while not module.finished:module.advance(1.0/60.0)
  expect(module.finished,"fallback completes its full playback")
  await process_frame
  expect(holder.get_ref()==null,"fallback releases its holder")
 host.free()

func finish() -> void:
 print("FX FLIGHT: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
