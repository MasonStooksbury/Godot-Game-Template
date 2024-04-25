extends Node

# MANAGERS
@onready var SoundManager = $SoundManager
@onready var SignalManager = $SignalManager
@onready var SteamManager = $SteamManager


# MAIN
var SCREEN_DIMENSIONS
var SCREEN_CENTER

# STEAM
var OWNED: bool = false
var ONLINE: bool = false
var STEAM_ID: String = ''
var STEAM_NAME: String = ''

# LOBBY
var DATA
var LOBBY_ID: int = 0
var LOBBY_MEMBERS: Array = []
var LOBBY_INVITE_ARG: bool = false
var LOBBY_MAX_MEMBERS: int = 10
var IS_HOST: bool = false
var PLAYERHOST_STEAM_ID: String

# SCENES
#const TITLE_SCREEN_SCENE = preload('res://Shared/TitleScreen/MainMenu.tscn')


# CLASSES
const PLAYER_CLASS = preload('res://Shared/Steam/Player.gd')


# SOUNDS
var sound_node = load("res://Shared/Global/Sound.tscn")

#var hover_01: AudioStream = load("res://Assets/Sounds/UI/hover-01.wav")
#var select_click_01: AudioStream = load("res://Assets/Sounds/UI/select-click-01.wav")


#var hover_sounds = [hover_01]

var default_sfx_volume = 0.0


func _ready() -> void:
	# Seed the randomizer
	randomize()

	SCREEN_DIMENSIONS = get_viewport().get_visible_rect().size
	SCREEN_CENTER = Vector2(SCREEN_DIMENSIONS.x/2, SCREEN_DIMENSIONS.y/2)

	get_tree().get_root().connect('size_changed', handleScreenResize)

	# This solves any weirdness from happening where certain things aren't ready in other Singletons
	#		by the time we get to their _ready() function
	for child in get_children():
		if child.has_method('_setup'):
			child._setup()


func _process(_delta) -> void:
	Steam.run_callbacks()

func handleScreenResize() -> void:
	SCREEN_DIMENSIONS = get_viewport().get_visible_rect().size
	SCREEN_CENTER = Vector2(SCREEN_DIMENSIONS.x/2, SCREEN_DIMENSIONS.y/2)


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
