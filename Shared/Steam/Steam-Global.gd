extends Node



# MANAGERS
@onready var SoundManager = $SoundManager
@onready var AnimationManager = $AnimationManager



# MAIN
var SCREEN_DIMENSIONS
var SCREEN_CENTER


# STEAM
var OWNED = false
var ONLINE = false
var STEAM_ID = 0
var STEAM_NAME = ""

# LOBBY
var DATA
var LOBBY_ID = 0
var LOBBY_MEMBERS = []
var LOBBY_INVITE_ARG = false
var LOBBY_MAX_MEMBERS = 15 # TODO: What should this realistically be?
var IS_HOST = false
var PLAYERHOST_STEAM_ID


# IMAGES
var ICON_IMAGE = load("res://icon.svg")


# SCENES
const GAME_SCENE = preload('res://Game.tscn')
const DUMMY_PLAYER_SCENE = preload('res://DummyPlayer.tscn')
const CARD_SCENE = preload('res://Card.tscn')
# TODO: Delete this
const RENDER_THING_SCENE = preload('res://RenderThing.tscn')

# SCRIPTS
var REGULAR_PLAYER_SCRIPT = load('res://RegularPlayer.gd')
var PLAYERHOST_SCRIPT = load('res://PlayerHost.gd')

# CLASS SCRIPTS
var CARD_CLASS = load('res://Card.gd')
var PLAYER_CLASS = load('res://Player.gd')

# SOUNDS
var sound_node = preload("res://Shared/Global/Sound.tscn")

var hover_01: AudioStream = load("res://Assets/Sounds/UI/hover-01.wav")
var hover_02: AudioStream = load("res://Assets/Sounds/UI/hover-02.wav")
var hover_03: AudioStream = load("res://Assets/Sounds/UI/hover-03.wav")
var select_click_01: AudioStream = load("res://Assets/Sounds/UI/select-click-01.wav")
var hover_sounds = [hover_01, hover_02, hover_03]
var default_sfx_volume = 0.0




# GAME STUFF
var deck = [
		'B0', 'B1', 'B1', 'B2', 'B2', 'B3', 'B3', 'B4', 'B4', 'B5', 'B5', 'B6', 'B6', 'B7', 'B7', 'B8', 'B8', 'B9', 'B9',
		'G0', 'G1', 'G1', 'G2', 'G2', 'G3', 'G3', 'G4', 'G4', 'G5', 'G5', 'G6', 'G6', 'G7', 'G7', 'G8', 'G8', 'G9', 'G9',
		'R0', 'R1', 'R1', 'R2', 'R2', 'R3', 'R3', 'R4', 'R4', 'R5', 'R5', 'R6', 'R6', 'R7', 'R7', 'R8', 'R8', 'R9', 'R9',
		'Y0', 'Y1', 'Y1', 'Y2', 'Y2', 'Y3', 'Y3', 'Y4', 'Y4', 'Y5', 'Y5', 'Y6', 'Y6', 'Y7', 'Y7', 'Y8', 'Y8', 'Y9', 'Y9',
		'BT', 'BR', 'BS', 'GT', 'GR', 'GS', 'RT', 'RR', 'RS', 'YT', 'YR', 'YS',
		'BT', 'BR', 'BS', 'GT', 'GR', 'GS', 'RT', 'RR', 'RS', 'YT', 'YR', 'YS',
		'ZW', 'ZW', 'ZW', 'ZW', 'ZF', 'ZF', 'ZF', 'ZF', 'ZO', 'ZA', 'ZA', 'ZA'
	]

var WINNING_PLAYER_ID = 0

var COLOR_DICT = {'R': 'Red', 'B': 'Blue', 'G': 'Green', 'Y': 'Yellow', 'Z': 'Wild'}

var COLOR_CODES = {'R': 'C00D03', 'B': '074AA3', 'G': '378C1A', 'Y': 'E7CF04', 'Z': 'FF00FF'}



func _ready():
	# Seed the randomizer
	randomize()

	SCREEN_DIMENSIONS = get_viewport().get_visible_rect().size
	SCREEN_CENTER = Vector2(SCREEN_DIMENSIONS.x/2, SCREEN_DIMENSIONS.y/2)

	var INIT = Steam.steamInit()
	if INIT['status'] != 1:
		print('Failed to initialize Steam. ' + str(INIT['verbal']) + " Shutting down...")
		get_tree().quit()

	ONLINE = Steam.loggedOn()
	STEAM_ID = str(Steam.getSteamID())
	STEAM_NAME = str(Steam.getPersonaName())
	OWNED = Steam.isSubscribed()

	if not OWNED:
		print('User does not own this game')
		get_tree().quit()

#	createCardDeck()


func _process(_delta):
	Steam.run_callbacks()





# MANAGEMENT

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





# GAME MANAGEMENT

#func createCardDeck():
#	var color_codes = {'B': 'BLUE', 'R': 'RED', 'G': 'GREEN', 'Y': 'YELLOW', 'W':'WHITE'}
#	for card in deck:
#		var card_object = {'color': card[0], 'value': card[1], 'is_special': false}
#
#		if card[1] in ['T', 'R', 'S', 'W', 'F', 'O', 'A']:
#			card_object.is_special = true
#
#		cards.append(CARD_CLASS.new(card_object))



func dataToCard(data):
	var card_object = {'color': data[0], 'value': data[1], 'is_special': false, 'data': data}

	if data[1] in ['T', 'R', 'S', 'W', 'F', 'O', 'A']:
		card_object.is_special = true

	return CARD_CLASS.new(card_object)


func cardToData(card):
	return card.data




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
