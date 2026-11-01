extends Panel
## Private payment draft; committing remains in the declaration controls.
const Draft=preload("res://scripts/payment_draft.gd")
const Costs=preload("res://scripts/card_cost_display.gd")
const Hex=preload("res://scripts/cost_hex_display.gd")
var board
var category="all"
var page=0
var resources={}
var source_signature=""
var eligible={}

func refresh(rect: Rect2):
 var view=board.view;var m=view.host.ui_metrics;var g=m.gap;var hit=m.hit
 position=rect.position-board.position;size=rect.size
 add_theme_stylebox_override("panel",view.host.style(Color("#1b1420",0.98),Color("#e9c175")))
 var initial=not view.local.get("android_payment_popup_opened",false)
 if initial:
  view.local.android_payment_popup_opened=true;category="all";page=0
 for child in get_children():remove_child(child);child.queue_free()
 resources={}
 var sources=view.engine.source_resources(view.acting_player()).filter(func(source):return source.uid not in view.payment_excluded())
 var signature=JSON.stringify([sources,view.local_cost_options(),view.payment_excluded(),view.host.auto_pay_keep_colors])
 if signature!=source_signature:
  source_signature=signature;eligible={}
  for source in sources:
   eligible[source.uid]=Draft.solve_selected_costs(view.engine,view.acting_player(),view.local_cost_options(),[{"uid":source.uid}],view.payment_excluded(),view.host.auto_pay_keep_colors).ways>0
 var title=Label.new();title.name="Title";title.mouse_filter=MOUSE_FILTER_IGNORE
 var costs=" / ".join(view.local_cost_options().map(func(cost):return Costs.caption(cost).trim_prefix("费用：")))
 var paid=0
 for entry in view.local.plan:paid+=2 if entry.color=="黄/绿" else 1
 title.text="支付 · "+costs+" · 已付 %d" % paid
 title.tooltip_text=title.text+"\n点已选资源取消；点其他资源更换支付。长按查看卡牌。"
 title.position=Vector2(g,0);title.size=Vector2(size.x-hit*2-g*3,hit)
 title.clip_text=true;title.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 title.add_theme_font_size_override("font_size",m.small);add_child(title)
 control("Hide","隐藏",Rect2(size.x-hit*2-g,0,hit*2,hit),func():view.set_android_camera_focus(-1))
 var categories=["all","unit","item","palette"];var labels=["全部","单位","道具","颜色盘"]
 if sources.any(func(source):return source.kind not in ["unit","item","palette"]):categories.append("other");labels.append("其他")
 var width=(size.x-g*(categories.size()+1))/categories.size()
 for i in range(categories.size()):
  var key=categories[i];var count=sources.filter(func(source):return matches(source,key)).size()
  var button=control("Category-"+key,labels[i]+" %d" % count,Rect2(g+i*(width+g),hit+g,width,hit),func():category=key;page=0;board.sync();view.rebuild_badges(),category==key)
  button.disabled=count==0 and key!="all"
 var list=sources.filter(func(source):return matches(source,category))
 var area=Rect2(g,hit*2+g*2,size.x-g*2,size.y-hit*2-g*3)
 var columns=maxi(1,floori((area.size.x+g)/(hit*1.8+g)))
 var paged=list.size()>columns
 if paged:
  area.position.x+=hit+g;area.size.x-=hit*2+g*2
  columns=maxi(1,floori((area.size.x+g)/(hit*1.8+g)))
 var pages=maxi(1,ceili(float(list.size())/columns));page=clampi(page,0,pages-1)
 if initial:
  for i in range(list.size()):
   if view.local.plan.any(func(entry):return entry.uid==list[i].uid):page=floori(float(i)/columns);break
 if paged:
  for direction in [-1,1]:
   var button=control("PagePrev" if direction<0 else "PageNext","‹" if direction<0 else "›",Rect2(g if direction<0 else size.x-hit-g,area.position.y,hit,area.size.y),func():page+=direction;board.sync();view.rebuild_badges())
   button.disabled=page==0 if direction<0 else page==pages-1
 width=(area.size.x-g*(columns-1))/columns
 for i in range(page*columns,mini(list.size(),(page+1)*columns)):
  resource(list[i],Rect2(area.position.x+(i%columns)*(width+g),area.position.y,width,area.size.y))
 if list.is_empty():
  var empty=Label.new();empty.text="没有可用的支付资源";empty.position=area.position;empty.size=area.size
  empty.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;empty.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;empty.mouse_filter=MOUSE_FILTER_IGNORE;add_child(empty)

func matches(source: Dictionary,key: String) -> bool:
 return key=="all" or source.kind==key or key=="other" and source.kind not in ["unit","item","palette"]

func control(key: String,caption: String,rect: Rect2,action: Callable,selected: bool=false) -> Button:
 var view=board.view
 var button=view.host.button(self,caption,rect,action,selected);button.name=key
 view.host.ui_metrics.button(button);button.clip_text=true
 button.add_theme_font_size_override("font_size",view.responsive.choice_font_size([caption],rect.size.x))
 button.custom_minimum_size=Vector2(minf(view.host.ui_metrics.hit,rect.size.x),view.host.ui_metrics.hit);button.size=rect.size
 view.android_card_touch.bind_card(button,Callable(),action)
 return button

func resource(source: Dictionary,rect: Rect2):
 var view=board.view;var m=view.host.ui_metrics
 var selected=view.local.plan.filter(func(entry):return entry.uid==source.uid)
 var button=control("Resource-"+str(source.uid),"",rect,func():choose(source.uid),not selected.is_empty())
 resources[source.uid]=button;button.disabled=not eligible.get(source.uid,false)
 var c=view.engine.find_card(source.uid)
 var caption={"unit":"单位","item":"道具","palette":"颜色盘","potato":"红薯","floating":"浮动色"}.get(source.kind,"供费")
 var colors=selected[0].color if not selected.is_empty() else "/".join(source.colors)
 button.tooltip_text=(view.engine.cards[c.card_id].name+"\n" if not c.is_empty() else "")+caption+" · "+colors
 var footer=m.small+8;var image_area=Rect2(6,6,rect.size.x-12,maxf(1,rect.size.y-footer-12))
 if not c.is_empty():
  var art=TextureRect.new();art.texture=view.card_texture(c);art.mouse_filter=MOUSE_FILTER_IGNORE
  art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  art.position=image_area.position;art.size=image_area.size;button.add_child(art)
  view.android_card_touch.bind_card(button,func():board.inspect(c),func():choose(source.uid))
 else:
  var hex=Hex.new();button.add_child(hex);hex.configure({"/".join(source.colors):1},false,image_area.size.x,minf(40,image_area.size.y*0.65))
  hex.position=image_area.get_center()-hex.size/2
 var label=Label.new();label.mouse_filter=MOUSE_FILTER_IGNORE
 label.text=("✓ " if not selected.is_empty() else "")+caption+" · "+colors.replace("黄/绿","黄+绿")
 label.position=Vector2(4,rect.size.y-footer);label.size=Vector2(rect.size.x-8,footer)
 label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.clip_text=true
 label.add_theme_font_size_override("font_size",view.responsive.choice_font_size([label.text],label.size.x));button.add_child(label)

func choose(uid: int):
 var view=board.view
 if view.network_locked() or view.observing or not view.android_payment_panel_available():return
 if view.local.plan.any(func(entry):return entry.uid==uid) or view.payment_sources().any(func(source):return source.uid==uid):
  view.reserve_resource(uid);return
 # Keep as many existing choices as possible when replacing a full proposal.
 var fixed=[{"uid":uid}];var costs=view.local_cost_options();var excluded=view.payment_excluded();var keep=view.host.auto_pay_keep_colors
 # A released Inaba must not silently reappear in the solver's completion.
 # Prefer keeping paired reservations when the new resource can coexist.
 for entry in view.local.plan:
  if entry.color!="黄/绿":continue
  if Draft.solve_selected_costs(view.engine,view.acting_player(),costs,fixed+[entry],excluded,keep).ways>0:fixed.append(entry)
  else:excluded.append(entry.uid)
 var solution=Draft.solve_selected_costs(view.engine,view.acting_player(),costs,fixed,excluded,keep)
 if solution.ways==0:return
 for entry in view.local.plan:
  if entry.uid in excluded or fixed.any(func(p):return p.uid==entry.uid):continue
  var candidate=Draft.solve_selected_costs(view.engine,view.acting_player(),costs,fixed+[entry],excluded,keep)
  if candidate.ways>0:fixed.append(entry);solution=candidate
 # Replacing a paired source releases both slots. Only explicitly retained
 # resources are reserved; the solver's automatic completion stays unselected.
 var selected=fixed.map(func(entry):return entry.uid)
 view.local.plan=solution.plan.filter(func(entry):return entry.uid in selected)
 view.message="";view.render()
