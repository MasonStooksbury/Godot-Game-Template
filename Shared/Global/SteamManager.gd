extends Node


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

var external_invite: bool = false

var players


# Called when the node enters the scene tree for the first time.
func _setup():
	connectSteamSignals("lobby_created", "_on_Lobby_Created")
	connectSteamSignals("lobby_joined", "_on_Lobby_Joined")
	connectSteamSignals("join_requested", "_on_Lobby_Join_Requested")
	connectSteamSignals("lobby_chat_update", "_on_Lobby_Chat_Update")
	connectSteamSignals("lobby_message", "_on_Lobby_Message")
	connectSteamSignals("lobby_data_update", "_on_Lobby_Data_Update")
	connectSteamSignals("p2p_session_request", "_on_P2P_Session_Request")
	connectSteamSignals("p2p_session_connect_fail", "_on_P2P_Session_Connect_Fail")
	connectSteamSignals("avatar_loaded", "_loaded_avatar")
	Global.SignalManager.kick_button_pressed.connect(kickButtonPressed) # Arguments passed: player_steam_id
	Global.SignalManager.create_lobby.connect(createLobby)
	Global.SignalManager.start_game_button_pressed.connect(startGameButtonPressed)
	Global.SignalManager.ready_button_pressed.connect(readyButtonPressed)
	Global.SignalManager.leave_lobby_button_pressed.connect(leaveLobby)



	# Seed the randomizer
	randomize()

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

	if LOBBY_ID == 0:
		createLobby()



func _process(_delta) -> void:
	Steam.run_callbacks()
	if LOBBY_ID > 0:
		readP2PPacket()



#####################################
###### USER DEFINED FUNCTIONS #######
#####################################

func displayMessage(message) -> void:
	Global.SignalManager.display_message.emit(message)


func createLobby() -> void:
	if LOBBY_ID == 0:
		Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, Global.LOBBY_MAX_MEMBERS)


func getLobbyMembers() -> void:
	LOBBY_MEMBERS.clear()

	# Get number of members in lobby
	var member_count = Steam.getNumLobbyMembers(LOBBY_ID)

	# Get member data
	for member in range(0, member_count):
		var member_steam_id = Steam.getLobbyMemberByIndex(LOBBY_ID, member)

		var member_steam_name = Steam.getFriendPersonaName(member_steam_id)

		Steam.getPlayerAvatar(Steam.AVATAR_LARGE, member_steam_id)

		var player_object = {
			'steam_id': member_steam_id,
			'steam_name': member_steam_name,
		}

		addPlayerList(player_object)
	Global.SignalManager.check_max_lobby_members_reached.emit()
	Global.SignalManager.reorganize_and_render.emit()


func addPlayerList(player_object) -> void:
	LOBBY_MEMBERS.append(Global.PLAYER_CLASS.new(player_object))

	if IS_HOST:
		LOBBY_MEMBERS[getPlayerIndexBySteamID(STEAM_ID)].is_ready = true


func leaveLobby() -> void:
	if LOBBY_ID != 0:
		Steam.leaveLobby(LOBBY_ID)

		LOBBY_ID = 0

		for members in LOBBY_MEMBERS:
			if members['steam_id'] != STEAM_ID:
				Steam.closeP2PSessionWithUser(int(members['steam_id']))

		LOBBY_MEMBERS.clear()



func kickButtonPressed(player_steam_id) -> void:
	if IS_HOST:
		toSpecificPlayer(player_steam_id, 'kick')


func kickedFromLobby() -> void:
	leaveLobby()
	Global.SignalManager.kicked_from_lobby.emit()


func readyButtonPressed(ready_status: bool) -> void:
	print('did this work')
	print(ready_status)
	toPlayerHost('ready' if ready_status else 'unready')


func startGameButtonPressed() -> void:
	if IS_HOST:
		toEveryone('startGame')

func startGame() -> void:
	Global.SignalManager.start_game.emit()


func getPlayerIndexBySteamID(player_steam_id: String) -> int:
	var count = 0
	for player in LOBBY_MEMBERS:
		if player.steam_id == player_steam_id:
			break
		count += 1
	return count





#####################################
######## STEAM CALLBACKS ############
#####################################

#func _on_Lobby_Created(connect_id, lobby_id) -> void:
#	if connect_id == 1:
#		LOBBY_ID = lobby_id
#		IS_HOST = true
#		PLAYERHOST_STEAM_ID = str(Steam.getSteamID())
#
#		# Set Lobby name
#		Steam.setLobbyData(lobby_id, "name", "%s's Lobby" % STEAM_NAME)
#		# Set the ID for the PlayerHost
#		Steam.setLobbyData(lobby_id, 'playerhost_steam_id', PLAYERHOST_STEAM_ID)
#		chat_panel_label.text = Steam.getLobbyData(lobby_id, "name")
#
#		# Allow P2P connections to fallback to being relayed through Steam if needed
#		var is_relay: bool = Steam.allowP2PPacketRelay(true)
#		displayMessage('[STEAM] Allowing Steam to be relay backup: %s' % str(is_relay))

func _on_Lobby_Created(connect_id, lobby_id) -> void:
	if connect_id == 1:
		print('lobby created?')
		LOBBY_ID = lobby_id
		IS_HOST = true
		PLAYERHOST_STEAM_ID = str(Steam.getSteamID())

		# Set Lobby name
		Steam.setLobbyData(lobby_id, "name", "%s's Lobby" % STEAM_NAME)
		# Set the ID for the PlayerHost
		Steam.setLobbyData(lobby_id, 'playerhost_steam_id', PLAYERHOST_STEAM_ID)

		# Allow P2P connections to fallback to being relayed through Steam if needed
		Steam.allowP2PPacketRelay(true)

		# Allow P2P connections to fallback to being relayed through Steam if needed
		var is_relay: bool = Steam.allowP2PPacketRelay(true)
		displayMessage('[STEAM] Allowing Steam to be relay backup: %s' % str(is_relay))

		Global.SignalManager.created_lobby.emit()


func _on_Lobby_Join_Requested(lobby_id, friend_id) -> void:
	external_invite = true
	# Get lobby owners name
	var owner_name = Steam.getFriendPersonaName(friend_id)
	displayMessage("Joining %s lobby..." % str(owner_name))

	# Join lobby
	joinLobby(lobby_id)


func joinLobby(lobby_id) -> void:
	print('in join lobby')
	if Steam.getNumLobbyMembers(lobby_id) >= Global.LOBBY_MAX_MEMBERS:
		return
	displayMessage("Joining %s lobby..." % Steam.getLobbyData(lobby_id, "name"))

	# Clear previous lobby members list
	LOBBY_MEMBERS.clear()

	# Steam join request
	Steam.joinLobby(lobby_id)


func _on_Lobby_Joined(lobby_id, _permissions, _locked, _response) -> void:
	print('lobby joined')
	# Set our lobby id to match what lobby we're in
	LOBBY_ID = lobby_id

	# This prevents a fun bug where if someone creates a game and then joins another game, there are now 2 playerhosts
	var playerhost_steam_id = Steam.getLobbyData(lobby_id, 'playerhost_steam_id')
	if playerhost_steam_id == null or playerhost_steam_id != PLAYERHOST_STEAM_ID:
		IS_HOST = false
		PLAYERHOST_STEAM_ID = playerhost_steam_id

	if external_invite:
		Global.SignalManager.open_screen.emit('Multiplayer')

	Global.SignalManager.player_joined_lobby.emit()
	print('joined lobby?')

	# Get lobby members
	getLobbyMembers()

	# This makes it so that the PlayerHost is automatically ready
	if IS_HOST:
		Global.SignalManager.handle_ready_up.emit(STEAM_ID)

	makeP2PHandshake()

	# Apparently lobby data variables can only be strings, so we have this gross check
	if external_invite and Steam.getLobbyData(LOBBY_ID, 'has_game_started') == 'true':
		startGame()


func _on_Lobby_Data_Update(lobby_id, member_id, key) -> void:
	print("Success, Lobby ID: %s, Member ID: %s, Key: %s" % [lobby_id, member_id, key])


func _on_Lobby_Chat_Update(_lobby_id, _changed_id, player_steam_id, chat_state) -> void:
	# User who made lobby change
	var changer = Steam.getFriendPersonaName(player_steam_id)

	match chat_state:
		1:
			displayMessage('%s has joined the lobby! :D' % str(changer))
			Global.SignalManager.player_joined_lobby.emit()
		2:
			displayMessage('%s has left the lobby :(' % str(changer))
			Global.SignalManager.player_disconnected.emit(str(player_steam_id))
		4:
			displayMessage('%s has been disconnected' % str(changer))
			Global.SignalManager.player_disconnected.emit(str(player_steam_id))
		8:
			displayMessage('%s has been kicked from the lobby' % str(changer))
		16:
			displayMessage('%s has been banned from the lobby' % str(changer))
		_:
			displayMessage('%s did something...' % str(changer))

	getLobbyMembers()


func _on_Lobby_Message(_result, user, message, _type) -> void:
	var sender = Steam.getFriendPersonaName(user)
	displayMessage('%s : %s' % [str(sender), str(message)])


func _loaded_avatar(player_steam_id: int, image_size: int, buffer: PackedByteArray) -> void:
	# Create the image and texture for loading
	var avatar_image: Image = Image.create_from_data(image_size, image_size, false, Image.FORMAT_RGBA8, buffer)

	# Set a larger version of the avatar to be used elsewhere
	avatar_image.resize(128, 128, Image.INTERPOLATE_LANCZOS)
	var large_avatar_texture: ImageTexture = ImageTexture.create_from_image(avatar_image)
	LOBBY_MEMBERS[getPlayerIndexBySteamID(str(player_steam_id))].setLargeTexture(large_avatar_texture)

	# Resize the image if it is too large
	if image_size > 128:
		avatar_image.resize(128, 128, Image.INTERPOLATE_LANCZOS)

	# Apply the image to a texture
	var avatar_image_texture: ImageTexture = ImageTexture.create_from_image(avatar_image)

	# Save this texture to the correct player's profile_picture attribute
	LOBBY_MEMBERS[getPlayerIndexBySteamID(str(player_steam_id))].setTexture(avatar_image_texture)
	# TODO: Undo this?
	Global.SignalManager.reorganize_and_render.emit()
#	renderPlayers()







#####################################
######### P2P NETWORKING ############
#####################################

func makeP2PHandshake() -> void:
	displayMessage("[STEAM] Sending P2P handshake to the lobby...\n")
	toEveryone('handshake', {'from': STEAM_NAME})


# When receiving a P2P request from another user
func _on_P2P_Session_Request(remote_id: int) -> void:
	# Get the requester's name
	var requester: String = Steam.getFriendPersonaName(remote_id)
	# Print the debug message to output
	displayMessage('[STEAM] P2P session request from %s' % str(requester))
	# Accept the P2P session; can apply logic to deny this request if needed
	var session_accepted: bool = Steam.acceptP2PSessionWithUser(remote_id)
	displayMessage('[STEAM] P2P session was connected: %s' % str(session_accepted))
	# Make the initial handshake
	makeP2PHandshake()


# P2P connection failure
func _on_P2P_Session_Connect_Fail(lobby_id: int, session_error: int) -> void:
	# Note the session errors are: 0 - none, 1 - target user not running the same game, 2 - local user doesn't own app, 3 - target user isn't connected to Steam, 4 - connection timed out, 5 - unused
	# If no error was given
	if session_error == 0:
		print("[WARNING] Session failure with %s [no error given]" % str(lobby_id))
	# Else if target user was not running the same game
	elif session_error == 1:
		print("[WARNING] Session failure with %s [target user not running the same game]" % str(lobby_id))
	# Else if local user doesn't own app / game
	elif session_error == 2:
		print("[WARNING] Session failure with %s [local user doesn't own app / game]" % str(lobby_id))
	# Else if target user isn't connected to Steam
	elif session_error == 3:
		print("[WARNING] Session failure with %s [target user isn't connected to Steam]" % str(lobby_id))
	# Else if connection timed out
	elif session_error == 4:
		print("[WARNING] Session failure with %s [connection timed out]" % str(lobby_id))
	# Else if unused
	elif session_error == 5:
		print('[WARNING] Session failure with %s [unused]' % str(lobby_id))
	# Else no known error
	else:
		print('[WARNING] Session failure with %s [unknown error %s]' % [str(lobby_id), str(session_error)])



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
		# Print the packet to output
		displayMessage('[STEAM] Packet from %s: %s' % [str(player_steam_id), str(readable)])

		# Append logic here to deal with packet data
		print(readable)

		if Global.SteamManager.IS_HOST:
			match readable['type']:
				'handshake': Global.SignalManager.check_lobby_ready_status.emit()
		else:
			match readable['type']:
				'start': displayMessage('[STEAM] Starting P2P game...')
				'startGame': startGame()
				'ready': Global.SignalManager.handle_ready_up.emit(player_steam_id)
				'unready': Global.SignalManager.handle_unready.emit(player_steam_id)
				'kick': kickedFromLobby()


func sendP2PPacket(target: int, packet_data_dictionary: Dictionary) -> void:
	# Set the send_type and channel
	var send_type: int = Steam.P2P_SEND_RELIABLE
	var channel: int = 0
	# Create a data array to send the data through
	var packet_data: PackedByteArray = []
	packet_data.append_array(var_to_bytes(packet_data_dictionary))

	# If sending a packet to everyone
	var send_response: bool
	if target == 0:
		# If there is more than one user, send packets
		if LOBBY_MEMBERS.size() > 1:
			# Loop through all members that aren't you
			for member in LOBBY_MEMBERS:
				if member['steam_id'] != STEAM_ID:
					send_response = Steam.sendP2PPacket(int(member['steam_id']), packet_data, send_type, channel)
	# Else send the packet to a particular user
	else:
		# Send this packet
		send_response = Steam.sendP2PPacket(target, packet_data, send_type, channel)
	# The packets send response is...?
	displayMessage('[STEAM] P2P packet sent successfully? %s' % str(send_response))


func toEveryone(type, data=''):
	sendP2PPacket(0, {'type': type, 'data': data})

func toPlayerHost(type, data=''):
	sendP2PPacket(int(PLAYERHOST_STEAM_ID), {'type': type, 'data': data})

func toSpecificPlayer(player_steam_id, type, data=''):
	sendP2PPacket(int(player_steam_id), {'type': type, 'data': data})



#####################################
######## OTHER GOOD GOOD ############
#####################################

# Connect a Steam signal and show the success code
func connectSteamSignals(this_signal: String, this_function: String) -> void:
	var SIGNAL_CONNECT: int = Steam.connect(this_signal, Callable(self, this_function))
	if SIGNAL_CONNECT > OK:
		print("[STEAM] Connecting "+str(this_signal)+" to "+str(this_function)+" failed: "+str(SIGNAL_CONNECT))
