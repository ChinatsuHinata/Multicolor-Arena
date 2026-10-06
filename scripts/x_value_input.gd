extends LineEdit
## Only decimal integer values from the precomputed legal set can be submitted.
var values: Array=[]
var accepted=""
var accepted_caret=0
var max_digits=1
func configure(legal: Array,initial: int):
 values=legal.duplicate();values.sort()
 virtual_keyboard_type=LineEdit.KEYBOARD_TYPE_NUMBER
 max_digits=str(values.back()).length()
 alignment=HORIZONTAL_ALIGNMENT_CENTER
 text=str(initial);accepted=text;accepted_caret=text.length()
 text_changed.connect(validate_edit)
func is_legal() -> bool:
 if text.is_empty() or text.length()>max_digits:return false
 for index in range(text.length()):
  if text.unicode_at(index)<48 or text.unicode_at(index)>57:return false
 return text.to_int() in values
func validate_edit(value: String):
 var digits=value.length()<=max_digits
 for index in range(value.length()):
  if value.unicode_at(index)<48 or value.unicode_at(index)>57:digits=false;break
 # An unfinished prefix is allowed while typing a multi-digit legal value.
 var valid=digits and (value.is_empty() or values.any(func(n):return str(n).begins_with(value)))
 if not valid:
  set_text(accepted);caret_column=accepted_caret
 else:
  accepted=value;accepted_caret=caret_column
