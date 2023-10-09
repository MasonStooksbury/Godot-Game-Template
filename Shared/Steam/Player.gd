class_name Player

var steam_name: String
var steam_id: String
var is_ready: bool = false
var hand = []
var is_final_turn: bool = false
var profile_picture



func _init(dictionary):
	steam_name = str(dictionary.steam_name)
	steam_id = str(dictionary.steam_id)


func getData():
	return {
		'steam_name': steam_name,
		'steam_id': steam_id,
		'is_ready': is_ready,
		'hand': hand,
		'is_final_turn': is_final_turn
	}
