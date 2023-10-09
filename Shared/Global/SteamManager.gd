extends Node

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


# SCENES
#const DUMMY_PLAYER_SCENE = preload('res://DummyPlayer.tscn')

# SCRIPTS
var REGULAR_PLAYER_SCRIPT = load('res://Shared/Steam/RegularPlayer.gd')
var PLAYERHOST_SCRIPT = load('res://Shared/Steam/PlayerHost.gd')

# CLASS SCRIPTS
var PLAYER_CLASS = load('res://Shared/Steam/Player.gd')


# Called when the node enters the scene tree for the first time.
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


func _process(_delta):
	Steam.run_callbacks()
