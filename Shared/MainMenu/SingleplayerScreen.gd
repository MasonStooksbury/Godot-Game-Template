extends Control


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


# TODO: Remove this
func _on_button_pressed():
	Global.SignalManager.open_screen.emit('Title')



func _on_start_game_button_pressed():
	Global.GameManager.setupGame('Singleplayer')
