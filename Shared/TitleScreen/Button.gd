extends Button

@export var next_scene: PackedScene

func _on_pressed():
	get_tree().change_scene_to_packed(next_scene)

func _on_mouse_entered():
	Global.play('hover')
