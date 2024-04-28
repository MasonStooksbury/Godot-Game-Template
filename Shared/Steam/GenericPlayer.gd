extends Node


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.




func drawCard():
	Global.GameManager.drawCard()






################################################################
####################### BUTTONS ################################
################################################################


func _on_button_pressed():
	Global.SignalManager.open_screen.emit('Title')


func _on_button_2_pressed():
	#Global.SteamManager.toSpecificPlayer('itdo')
	pass
