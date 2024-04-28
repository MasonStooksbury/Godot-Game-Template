extends Control

@onready var option_button = $Label/OptionButton
var num_cpu_players


# Called when the node enters the scene tree for the first time.
func _ready():
	option_button.select(0)
	num_cpu_players = option_button.get_item_text(0)


# TODO: Remove this or modify it
func _on_button_pressed():
	Global.SignalManager.open_screen.emit('Title')



func _on_start_game_button_pressed():
	Global.GameManager.startGame('Singleplayer', getGameData())


func _on_option_button_item_selected(index) -> void:
	num_cpu_players = option_button.get_item_text(index)


func getGameData() -> Dictionary:
	return {'num_cpu_players': num_cpu_players}
