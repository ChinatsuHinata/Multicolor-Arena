extends SceneTree
## Runs against the actual PCK, including when packaging uses -SkipExport.
var failures=[]
var policy

func _initialize():
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--policy="):policy=load(argument.trim_prefix("--policy="))
 if policy==null:
  push_error("Release policy could not be loaded.")
  quit(1)
  return
 inspect_directory("res://")
 var path="res://data/bundled_decks.json"
 if not FileAccess.file_exists(path):
  failures.append("Missing bundled decks")
 else:
  var bundle=JSON.parse_string(FileAccess.get_file_as_string(path))
  if not bundle is Dictionary or bundle.get("release_policy",0)!=policy.VERSION or not bundle.get("decks") is Array:
   failures.append("PCK has no current release policy; export again without -SkipExport")
  else:
   if bundle.get("upgrade_deck_ids",[])!=[policy.REMILIA_ID]:
    failures.append("Approved AI deck must also be delivered to existing installations")
   var approved=0
   var ids={}
   for deck in bundle.decks:
    if not deck is Dictionary:
     failures.append("Invalid bundled deck")
     continue
    var id=str(deck.get("id",""))
    if id.is_empty() or ids.has(id):failures.append("Missing/duplicate bundled deck ID: "+id)
    ids[id]=true
    if policy.is_test_deck(deck):failures.append("Test deck bundled: "+str(deck.get("name","")))
    if id==policy.REMILIA_ID:
     approved+=1
     if deck.get("name","")!=policy.REMILIA_NAME or deck.get("leader","")!="74":failures.append("Approved AI deck has wrong name/leader")
    elif policy.is_ai_deck(deck):failures.append("Unapproved AI deck: "+str(deck.get("name","")))
   if approved!=1:failures.append("Release must contain exactly one approved Remilia AI deck")
   if approved==1:
    var store=load("res://scripts/deck_store.gd")
    var engine_script=load("res://scripts/rules/duel_engine.gd")
    if store==null or engine_script==null:
     failures.append("Release runtime/AI scripts could not be loaded")
    else:
     var remilia=bundle.decks.filter(func(deck):return deck.get("id","")==policy.REMILIA_ID)[0]
     var error=store.validate(remilia,true,str(remilia.get("rule_set","official")))
     if not error.is_empty():failures.append("Illegal approved AI deck: "+error)
     else:
      var engine=engine_script.new()
      engine.start(remilia,remilia,0,42)
      if engine.ai_profiles!=[engine.RemiliaAI.PROFILE,engine.RemiliaAI.PROFILE]:failures.append("Approved deck did not select Remilia AI")
      engine.ai_step(1)
      if not engine.players[1].mulligan_done:failures.append("Packed Remilia AI did not act")
 for failure in failures:push_error(failure)
 if failures.is_empty():print("RELEASE_PACKAGE: PASS (no tests/experimental models; approved AI deck present)")
 quit(0 if failures.is_empty() else 1)

func inspect_directory(path: String):
 var directory=DirAccess.open(path)
 if directory==null:
  failures.append("Cannot inspect packed directory: "+path)
  return
 for filename in directory.get_files():
  var file=path.path_join(filename)
  if policy.excluded_path(file):failures.append("Excluded file bundled: "+file)
 for child in directory.get_directories():
  inspect_directory(path.path_join(child))
