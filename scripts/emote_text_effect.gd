extends RichTextEffect
## A restrained, per-glyph distortion for Koishi's reply; never moves the bubble.
var bbcode="koishi"

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
 var t=char_fx.elapsed_time
 var phase=float(char_fx.relative_index)*1.73
 var wave=sin(t*4.2+phase)
 var ripple=cos(t*3.6+phase*0.8)
 # Translation stays below 1.2 px per axis, with only a few percent of warp.
 char_fx.offset+=Vector2(wave*0.7+sin(t*43.0+phase)*0.4,ripple*0.65+cos(t*39.0+phase)*0.45)
 var warp=Transform2D(Vector2(1.0+wave*0.018,ripple*0.015),Vector2(wave*0.035,1.0+ripple*0.025),Vector2.ZERO)
 char_fx.transform=char_fx.transform*warp
 return true
