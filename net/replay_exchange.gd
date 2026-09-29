extends Node
## Only completed matches disclose replay frames; live seat/observer packets stay private.
var session
var completed={}
var pending=[]
var offset=0
var requested_at=0
var attempts=0
func remember(archive):
 completed[archive.metadata.room.match_id]=archive
 while completed.size()>2:completed.erase(completed.keys()[0])
func request(archive):
 pending.append({"archive":archive,"room_id":session.room_id,"match_id":archive.metadata.room.get("match_id","")})
 if pending.size()==1:offset=0;attempts=0;send_request()
func send_request():
 if pending.is_empty():return
 var item=pending[0];var archive=item.archive;var keys=[]
 for i in range(offset,mini(offset+16,archive.frames.size())):keys.append(archive.frame_key(i))
 requested_at=Time.get_ticks_msec();attempts+=1
 session.transport.send_to(1,{"type":"replay_request","room_id":item.room_id,"match_id":item.match_id,"offset":offset,"keys":keys})
func serve(id: int,message: Dictionary,transport):
 if not session.is_host or message.get("room_id","")!=session.room_id:return
 var archive=completed.get(message.get("match_id",""))
 if archive==null or not archive.finished or archive.metadata.room.get("status","")!="complete":return
 if not message.get("offset") is int or message.offset<0 or message.offset>=50000:return
 if not message.get("keys") is Array or message.keys.is_empty() or message.keys.size()>16:return
 var data=archive.disclosed_frames(message.keys,message.offset==0)
 transport.send_to(id,{"type":"replay_frames","room_id":session.room_id,"match_id":message.match_id,"offset":message.offset,"entries":data.entries,"definitions":data.definitions})
func receive(message: Dictionary):
 if pending.is_empty():return
 var item=pending[0];var archive=item.archive
 if message.get("room_id")!=item.room_id or message.get("match_id")!=item.match_id or message.get("offset")!=offset:return
 if not message.get("entries") is Array or not message.get("definitions") is Dictionary:return
 var entries=message.entries
 if entries.is_empty() or entries.size()>16 or offset+entries.size()>archive.frames.size():finish("完整手牌回放数据无效");return
 var known=archive.definitions.duplicate();known.merge(message.definitions,true)
 for i in range(entries.size()):
  if not entries[i] is Dictionary or not archive.replace_frame(offset+i,entries[i],known):finish("完整手牌回放校验失败");return
 offset+=entries.size();attempts=0
 if offset<archive.frames.size():send_request();return
 var complete=true
 for i in range(archive.frames.size()):
  if not archive.frame(i).projection.get("all_hands",false):complete=false;break
 if complete:archive.metadata.hands="both"
 # A rematch may already be capturing into the same path.
 if archive==session.recording:archive.refresh_capture()
 finish("部分旧片段没有完整手牌记录" if not complete else "")
func finish(warning: String=""):
 var archive=pending.pop_front().archive
 if not warning.is_empty():session.error_raised.emit(warning+"，将保存已录制的信息")
 session.replay_finished.emit(archive)
 offset=0;attempts=0
 if not pending.is_empty():send_request()
func _process(_delta):
 if pending.is_empty() or Time.get_ticks_msec()-requested_at<10000:return
 if attempts<3 and session.connected:send_request()
 else:finish("未能获取完整手牌回放")
