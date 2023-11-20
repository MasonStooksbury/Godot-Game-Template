extends Node

@onready var SteamManager = $SteamManager
@onready var SoundManager = $SoundManager

# SCENES
const TITLE_SCREEN_SCENE = preload('res://Shared/TitleScreen/TitleScreen.tscn')



# SOUNDS
var sound_node = load("res://Shared/Global/Sound.tscn")

#var hover_01: AudioStream = load("res://Assets/Sounds/UI/hover-01.wav")
#var select_click_01: AudioStream = load("res://Assets/Sounds/UI/select-click-01.wav")


#var hover_sounds = [hover_01]

var default_sfx_volume = 0.0


func _ready():
	# Seed the randomizer
	randomize()

func change_sfx_volume(new_volume):
	default_sfx_volume = new_volume

func play(sound):
	var audio: AudioStream
	var volume = default_sfx_volume
	match sound:
		'hover':
			#audio = hover_sounds[randi() % hover_sounds.size()]
			volume = -10
		'select-button':
			#audio = select_click_01
			volume = -20
	var sound_obj = sound_node.instantiate()
	$SoundManager.add_child(sound_obj)
	sound_obj.play_sound(audio, volume)


func clear_all_audio():
	for child in $SoundManager.get_children():
		child.queue_free()





func rotateClockwise(new_vector, d):
	var cosine = cos(deg_to_rad(d))
	var sine = sin(deg_to_rad(d))
	var almost_x = (new_vector.x * cosine) - (new_vector.y * sine)
	var almost_y = (new_vector.y * cosine) + (new_vector.x * sine)
	return Vector2(almost_x, almost_y)


func getCenterPivotOffset(body):
	return Vector2(body.size.x/2, body.size.y/2)


func getTopRightPivotOffset(body):
	return Vector2(body.size.x, 0)
