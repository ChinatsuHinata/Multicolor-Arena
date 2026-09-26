extends Panel
## Godot's default tooltip snapshots the text when the popup opens.
## Keep visible card calculations in sync while the pointer stays still.
class LiveLabel extends Label:
 var source: WeakRef
 func _process(_delta: float):
  var control=source.get_ref()
  if is_instance_valid(control) and text!=control.tooltip_text:text=control.tooltip_text

func _make_custom_tooltip(for_text: String) -> Object:
 var label=LiveLabel.new()
 label.name="LiveCardTooltip";label.theme_type_variation="TooltipLabel"
 label.text=for_text;label.source=weakref(self)
 return label
