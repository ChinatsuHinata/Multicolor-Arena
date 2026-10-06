extends RefCounted
## Shared card artwork and rules used by plaza details and teaching scenes.
const Store=preload("res://scripts/deck_store.gd")
const Art=preload("res://scripts/card_art.gd")

static func expand(control: Control,vertical: bool=false):
 control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 if vertical:control.size_flags_vertical=Control.SIZE_EXPAND_FILL

static func text(_app,parent: Node,value: String,font: int,color: Color) -> Label:
 var label=Label.new();label.text=value;parent.add_child(label);expand(label)
 label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label.add_theme_font_size_override("font_size",font);label.add_theme_color_override("font_color",color)
 return label

static func artwork(app,parent: Node,id: String,deck: Dictionary) -> TextureRect:
 var picture=TextureRect.new();picture.name="CardInspectionArt";parent.add_child(picture);expand(picture,true)
 picture.texture=app.preview_texture(id,Art.selected(deck,id,Store.CARDS))
 picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
 return picture

static func rules(app,parent: Node,id: String,width: float) -> ScrollContainer:
 var scroll=ScrollContainer.new();scroll.name="CardInspectionText";parent.add_child(scroll);expand(scroll,true)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var column=VBoxContainer.new();scroll.add_child(column);expand(column)
 column.add_theme_constant_override("separation",int(app.ui_metrics.gap))
 var info=Store.CARDS[id]
 text(app,column,str(info.name),app.ui_metrics.title,app.GOLD)
 var costs=app.HexCost.new();column.add_child(costs)
 costs.configure(info.cost,false,width,app.ui_metrics.body*1.5,info.get("variable_cost",""))
 text(app,column,app.card_description(id),app.ui_metrics.body,Color("#e8edf0")).name="CardInspectionRules"
 return scroll
