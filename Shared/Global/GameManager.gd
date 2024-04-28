extends Node


@onready var deck
@onready var players: Array



# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _process(_delta):
	if Global.SteamManager.LOBBY_ID != 0:
		readP2PPacket()


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





func readP2PPacket() -> void:
	var packet_size: int = Steam.getAvailableP2PPacketSize(0)
	# There is a packet
	if packet_size > 0:
		print('[STEAM] There is a packet available.')
		# Get the packet
		var packet: Dictionary = Steam.readP2PPacket(packet_size, 0)
		# If it is empty, set a warning
		if packet.is_empty():
			print('[WARNING] Read an empty packet with non-zero size!')
		# Get the remote user's ID
		var player_steam_id: String = str(packet['steam_id_remote'])
		var packet_code: PackedByteArray = packet['data']
		# Make the packet data readable
		var readable: Dictionary = bytes_to_var(packet_code)

		# Append logic here to deal with packet data
		print(readable)
		if Global.SteamManager.IS_HOST:
			match readable['type']:
				'itdo': print('it do')
		else:
			match readable['type']:
				'itdo': print('it dont')
			#'start': displayMessage('[STEAM] Starting P2P game...')
			#'startGame': startGame()
			#'ready': Global.SignalManager.handle_ready_up.emit(player_steam_id)
			#'unready': Global.SignalManager.handle_unready.emit(player_steam_id)
			#'kick': kickedFromLobby()
