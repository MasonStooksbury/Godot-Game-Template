extends Button

@export var next_scene: PackedScene

func _on_pressed():
	Global.SoundManager.playSound('select-button')
	get_tree().change_scene_to_packed(next_scene)

func _on_mouse_entered():
	Global.SoundManager.playSound('hover')
