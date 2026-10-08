extends AudioStreamPlayer
## A short two-note chime, generated locally so it also works in exported builds.
const DEFAULT_VOLUME=0.6
const SAMPLE_RATE=22050

static func normalize_volume(value: Variant) -> float:
 if not (value is float or value is int):return DEFAULT_VOLUME
 var volume=float(value)
 return clampf(volume,0.0,1.0) if is_finite(volume) else DEFAULT_VOLUME

func _ready():
 name="RoomJoinSound"
 var wav=AudioStreamWAV.new()
 wav.format=AudioStreamWAV.FORMAT_16_BITS
 wav.mix_rate=SAMPLE_RATE
 var samples=PackedByteArray()
 samples.resize(int(SAMPLE_RATE*0.62)*2)
 for i in range(samples.size()/2):
  var time=float(i)/SAMPLE_RATE
  var local_time=time if time<0.22 else time-0.22
  var frequency=659.25 if time<0.22 else 880.0
  var duration=0.22 if time<0.22 else 0.4
  var envelope=minf(local_time/0.012,1.0)*exp(-local_time*9.0)*clampf((duration-local_time)/0.03,0.0,1.0)
  var wave=sin(TAU*frequency*local_time)+0.18*sin(TAU*frequency*2.0*local_time)
  samples.encode_s16(i*2,int(wave*envelope*18000.0))
 wav.data=samples
 stream=wav

func set_notification_volume(value: float):
 var volume=normalize_volume(value)
 volume_db=linear_to_db(volume) if volume>0.0 else -80.0
 if volume<=0.0:stop()

func play_notification(value: float):
 set_notification_volume(value)
 if value>0.0:play()
