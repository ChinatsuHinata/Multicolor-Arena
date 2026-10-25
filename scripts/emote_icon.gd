extends RefCounted
## Font-independent faces, shared by the wheel, entry button and speech bubble.
static var textures: Dictionary={}

static func texture(kind: String="greeting",extent: int=64) -> Texture2D:
 var key=kind+":"+str(extent)
 if textures.has(key):return textures[key]
 var colors={"greeting":"#f1d190","praise":"#b8ddaa","surprise":"#f6c6d7","mistake":"#b7d4ed","threat":"#efa395","surrender":"#dfd0ea"}
 var ink="#44303e"
 var detail=''
 match kind:
  "praise":
   detail='<path d="M19 27l4-4 4 4m10 0 4-4 4 4M22 38q10 11 20 0"/><path d="M48 5l2.5 5 5.5 1-4 4 1 5.5-5-2.5-5 2.5 1-5.5-4-4 5.5-1z" fill="#ffebae"/>'
  "surprise":
   detail='<ellipse cx="23" cy="27" rx="2.4" ry="3.8" fill="'+ink+'"/><ellipse cx="41" cy="27" rx="2.4" ry="3.8" fill="'+ink+'"/><ellipse cx="32" cy="41" rx="5.5" ry="7" fill="'+ink+'"/><path d="M19 18l8-2m10 0 8 2"/>'
  "mistake":
   detail='<path d="M18 28l9 3m10 0 9-3M25 43q7-6 14 0"/><path d="M48 10q-9 12-2 15 8 1 2-15z" fill="#74b8df" stroke="#467caa"/>'
  "threat":
   detail='<path d="M18 22l10 5m8 0 10-5M24 43q8-8 16 0"/><circle cx="24" cy="31" r="2" fill="'+ink+'"/><circle cx="40" cy="31" r="2" fill="'+ink+'"/><path d="M48 8v9m-4-5h9" stroke="#be4547"/>'
  "surrender":
   detail='<path d="M18 28h10m8 0h10M25 42h14"/><path d="M48 5v18m0-17h10l-3 5 3 5H48" fill="#fff8ed"/>'
  _:
   detail='<circle cx="23" cy="27" r="2.5" fill="'+ink+'"/><circle cx="41" cy="27" r="2.5" fill="'+ink+'"/><path d="M21 37q11 12 22 0"/><path d="M8 10l-3-4m9 1-1-5m-7 16-5-1" stroke="#efd292"/>'
 var svg='<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><circle cx="32" cy="33" r="26" fill="#211720" opacity=".24"/><circle cx="32" cy="31" r="25" fill="'+colors.get(kind,colors.greeting)+'" stroke="#fff2d5" stroke-width="1.5"/><path d="M14 24q6-14 19-13" fill="none" stroke="#ffffff" stroke-opacity=".4" stroke-width="3" stroke-linecap="round"/><g fill="none" stroke="'+ink+'" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round">'+detail+'</g></svg>'
 var source=Image.new()
 if source.load_svg_from_string(svg,float(maxi(16,extent))/64.0)!=OK:return null
 var result=ImageTexture.create_from_image(source)
 textures[key]=result
 return result

static func draw_on(canvas: CanvasItem,kind: String,center: Vector2,radius: float,muted: bool=false):
 var icon=texture(kind,maxi(64,int(radius*2)))
 if icon!=null:canvas.draw_texture_rect(icon,Rect2(center-Vector2.ONE*radius,Vector2.ONE*radius*2),false,Color(1,1,1,0.42 if muted else 1.0))
