extends Node




# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func setupGame(type: String):
	if type == 'Singleplayer':
		print('weeee')
	elif type == 'Multiplayer':
		print('woooo')

	Global.SignalManager.open_screen.emit('Game')
