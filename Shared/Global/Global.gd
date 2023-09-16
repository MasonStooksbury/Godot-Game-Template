extends Node

# SCENES
const TITLESCREEN_SCENE = preload('res://Shared/TitleScreen/TitleScreen.tscn')



# SOUNDS
var sound_node = load("res://Shared/Global/Sound.tscn")

var hover_01: AudioStream = load("res://Assets/Sounds/UI/hover-01.wav")
var hover_02: AudioStream = load("res://Assets/Sounds/UI/hover-02.wav")
var hover_03: AudioStream = load("res://Assets/Sounds/UI/hover-03.wav")
var select_click_01: AudioStream = load("res://Assets/Sounds/UI/select-click-01.wav")


var hover_sounds = [hover_01, hover_02, hover_03]

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
			audio = hover_sounds[randi() % hover_sounds.size()]
			volume = -10
		'select-button':
			audio = select_click_01
			volume = -20
	var sound_obj = sound_node.instantiate()
	$SoundManager.add_child(sound_obj)
	sound_obj.play_sound(audio, volume)


func clear_all_audio():
	for child in $SoundManager.get_children():
		child.queue_free()
