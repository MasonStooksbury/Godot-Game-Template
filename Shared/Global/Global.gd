extends Node

# STEAM
var OWNED = false
var ONLINE = false
var STEAM_ID = 0
var STEAM_NAME = ""
# Lobby stuff
var DATA
var LOBBY_ID = 0
var LOBBY_MEMBERS = []
var LOBBY_INVITE_ARG = false
var LOBBY_MAX_MEMBERS = 15 # TODO: What should this realistically be?



# SCENES
const TITLESCREEN_SCENE = preload('res://Shared/TitleScreen/TitleScreen.tscn')



# SOUNDS
var sound_node = preload("res://Shared/Global/Sound.tscn")

var hover_01: AudioStream = preload("res://Assets/Sounds/UI/hover-01.wav")
var hover_02: AudioStream = preload("res://Assets/Sounds/UI/hover-02.wav")
var hover_03: AudioStream = preload("res://Assets/Sounds/UI/hover-03.wav")
var select_click_01: AudioStream = preload("res://Assets/Sounds/UI/select-click-01.wav")


var hover_sounds = [hover_01, hover_02, hover_03]

var default_sfx_volume = 0.0


func _ready():
	# Seed the randomizer
	randomize()
	print('re')

	var INIT = Steam.steamInit()
	if INIT['status'] != 1:
		print('Failed to initialize Steam. ' + str(INIT['verbal']) + " Shutting down...")
		get_tree().quit()

	ONLINE = Steam.loggedOn()
	STEAM_ID = Steam.getSteamID()
	STEAM_NAME = Steam.getPersonaName()
	OWNED = Steam.isSubscribed()

	if not OWNED:
		print('User does not own this game')
		get_tree().quit()


func _process(_delta):
	Steam.run_callbacks()


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
