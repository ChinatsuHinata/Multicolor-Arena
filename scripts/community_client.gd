extends "res://scripts/deck_plaza_client.gd"

func _init():
 protocol_prefix="MCE1";service_name="社区服务"
 content_limit_message="教程内容过大，请缩小配图后重试"
 frame_limit=8*1024*1024;response_limit=8*1024*1024;allow_anonymous=true
