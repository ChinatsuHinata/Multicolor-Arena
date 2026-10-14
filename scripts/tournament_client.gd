extends "res://scripts/deck_plaza_client.gd"
## Share the encrypted session envelope and transport with the deck plaza.
func _init():
 protocol_prefix="MCT1"
 service_name="比赛服务"
 content_limit_message="比赛说明过长，请缩短后重试"
