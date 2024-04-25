class_name Player

var steam_name: String
var steam_id: String
var is_ready: bool = false
var hand: Array = []
var is_final_turn: bool = false
var profile_picture: ImageTexture
var large_profile_picture: ImageTexture



func _init(options: Dictionary) -> void:
	steam_name = str(options.steam_name)
	steam_id = str(options.steam_id)


func getData() -> Dictionary:
	return {
		'steam_name': steam_name,
		'steam_id': steam_id,
		'is_ready': is_ready,
		'hand': hand,
		'is_final_turn': is_final_turn,
		'profile_picture': profile_picture
	}


func setTexture(texture: ImageTexture) -> void:
	profile_picture = texture


func setLargeTexture(texture: ImageTexture) -> void:
	large_profile_picture = texture
