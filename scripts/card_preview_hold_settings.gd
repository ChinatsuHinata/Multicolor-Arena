extends RefCounted
## The Android card-inspection delay is shared by battle, deck and tutorial views.
const DEFAULT_SECONDS=0.5
## Settings saved before the default changed always stored the old 1 second.
const LEGACY_DEFAULT_SECONDS=1.0
const MIN_SECONDS=0.2
const MAX_SECONDS=3.0
const STEP_SECONDS=0.05
static var seconds=DEFAULT_SECONDS

static func normalize(value) -> float:
 if not (value is int or value is float):return DEFAULT_SECONDS
 var number=float(value)
 if not is_finite(number):return DEFAULT_SECONDS
 return snappedf(clampf(number,MIN_SECONDS,MAX_SECONDS),STEP_SECONDS)

## Reads the saved delay, moving untouched old defaults to the current default.
static func load_saved(saved: Dictionary) -> float:
 var value=normalize(saved.get("android_card_preview_seconds",DEFAULT_SECONDS))
 if not saved.has("android_card_preview_default") and is_equal_approx(value,LEGACY_DEFAULT_SECONDS):return DEFAULT_SECONDS
 return value

static func caption() -> String:
 return "%.2f 秒" % seconds
