extends SceneTree

var errors: Array[String]=[]
var checks=0

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool,description: String) -> void:
 checks+=1
 if ok:print("PASS: ",description)
 else:errors.append(description);push_error(description)

func run() -> void:
 var app=load("res://main.tscn").instantiate()
 app.is_android=true
 app.tutorial_local_directory="res://work/android-font-checks/tutorials"
 app.lan_storage_directory="res://work/android-font-checks/lan"
 app.settings_path="res://work/android-font-checks/settings.json"
 app.account_session_path="res://work/android-font-checks/account.json"
 root.add_child(app)
 await process_frame
 var font=app.theme.default_font
 check(font is FontVariation and font.base_font is FontFile,"Android uses a bundled regular font instead of SystemFont")
 var weight_tag=TextServerManager.get_primary_interface().name_to_tag("wght")
 check(font is FontVariation and is_equal_approx(float(font.variation_opentype.get(weight_tag,0.0)),400.0),"Android uses normal weight 400 instead of the font's thin default")
 for character in ["：","你","·","→","×","…","★","☆"]:
  check(font.has_char(character.unicode_at(0)),"Android font covers "+character)
 app.account_name="sample_user"
 app.account_elo=1000
 app.account_page()
 await process_frame
 var rating=app.screen.find_child("AccountElo",true,false) as Label
 check(rating!=null and rating.text=="我的 Elo：1000" and rating.get_theme_font("font").has_char(0xff1a),"Android Elo label renders the full-width colon")
 print("Android font coverage: %d checks, %d failures" % [checks,errors.size()])
 quit(0 if errors.is_empty() else 1)
