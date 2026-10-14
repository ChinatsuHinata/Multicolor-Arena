extends RefCounted
## The Android card-inspection delay is shared by battle, deck and tutorial views.
const DEFAULT_SECONDS=1.0
const MIN_SECONDS=0.2
const MAX_SECONDS=3.0
const STEP_SECONDS=0.05
static var seconds=DEFAULT_SECONDS

static func normalize(value) -> float:
 if not (value is int or value is float):return DEFAULT_SECONDS
 var number=float(value)
 if not is_finite(number):return DEFAULT_SECONDS
 return snappedf(clampf(number,MIN_SECONDS,MAX_SECONDS),STEP_SECONDS)

static func caption() -> String:
 return "%.2f 秒" % seconds
