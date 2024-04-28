extends Node


@onready var deck
@onready var players: Array



# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func startGame(type: String, game_data: Dictionary = {}):
	if type == 'Singleplayer':
		# Add the CPU players
		for i in range(int(game_data['num_cpu_players'])):
			var cpu_player = Global.CPU_PLAYER_CLASS.new({})
			players.append(cpu_player)


		# Add the actual player
		players.append(Global.PLAYER_CLASS.new({
			'steam_id': Global.SteamManager.STEAM_ID,
			'steam_name': Steam.getFriendPersonaName(int(Global.SteamManager.STEAM_ID)),
		}))

	elif type == 'Multiplayer':
		# We need to deep copy so that future actions don't ruin the actual members themselves
		players = Global.LOBBY_MEMBERS.duplicate(true)

	Global.SignalManager.open_screen.emit('Game')




