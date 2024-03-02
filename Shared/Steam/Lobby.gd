extends Control


@onready var create_lobby_button = $CreateLobbyButton
@onready var create_lobby_line_edit = $CreateLobbyButton/CreateLobbyLineEdit
@onready var create_lobby_label = $CreateLobbyButton/CreateLobbyLabel
@onready var players_panel_label = $PlayersPanel/PlayersPanelLabel
@onready var players_panel_rich_text_label = $PlayersPanel/PlayersPanelRichTextLabel
@onready var chat_panel_label = $ChatPanel/ChatPanelLabel
@onready var chat_panel_rich_text_label = $ChatPanel/ChatPanelRichTextLabel
@onready var send_message_line_edit = $SendMessageButton/LineEdit
@onready var start_game_button = $StartGameButton
@onready var ready_button = $ReadyButton



func _ready():
	connectSteamSignals("lobby_created", "_on_Lobby_Created")
	connectSteamSignals("lobby_joined", "_on_Lobby_Joined")
	connectSteamSignals("lobby_chat_update", "_on_Lobby_Chat_Update")
	connectSteamSignals("lobby_message", "_on_Lobby_Message")
	connectSteamSignals("lobby_data_update", "_on_Lobby_Data_Update")
	connectSteamSignals("join_requested", "_on_Lobby_Join_Requested")
	connectSteamSignals("p2p_session_request", "_on_P2P_Session_Request")
	connectSteamSignals("p2p_session_connect_fail", "_on_P2P_Session_Connect_Fail")
	connectSteamSignals("avatar_loaded", "_loaded_avatar")


func _process(_delta):
	if Global.LOBBY_ID > 0:
		readP2PPacket()




#####################################
###### USER DEFINED FUNCTIONS #######
#####################################

func displayMessage(message):
	chat_panel_rich_text_label.add_text("\n" + str(message))


func createLobby():
	if Global.LOBBY_ID == 0:
		Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, Global.LOBBY_MAX_MEMBERS)


func joinLobby(lobby_id):
	displayMessage("Joining %s lobby..." % Steam.getLobbyData(lobby_id, "name"))

	# Clear previous lobby members list
	Global.LOBBY_MEMBERS.clear()

	# Steam join request
	Steam.joinLobby(lobby_id)


func getLobbyMembers():
	Global.LOBBY_MEMBERS.clear()

	# Get number of members in lobby
	var member_count = Steam.getNumLobbyMembers(Global.LOBBY_ID)
	# Update player list count
	players_panel_label.set_text("Players (%s)" % str(member_count))

	# Get member data
	for member in range(0, member_count):
		var member_steam_id = Steam.getLobbyMemberByIndex(Global.LOBBY_ID, member)

		var member_steam_name = Steam.getFriendPersonaName(member_steam_id)

		Steam.getPlayerAvatar(Steam.AVATAR_LARGE, member_steam_id)

		var player_object = {
			'steam_id': member_steam_id,
			'steam_name': member_steam_name,
		}

		addPlayerList(player_object)


func addPlayerList(player_object):
	Global.LOBBY_MEMBERS.append(Global.PLAYER_CLASS.new(player_object))

	if Global.IS_HOST:
		Global.LOBBY_MEMBERS[getPlayerIndexBySteamID(Global.STEAM_ID)].is_ready = true

	players_panel_rich_text_label.clear()

	for member in Global.LOBBY_MEMBERS:
		players_panel_rich_text_label.add_text(str(member['steam_name']) + '\n')


func leaveLobby():
	if Global.LOBBY_ID != 0:
		displayMessage('Leaving lobby...')

		Steam.leaveLobby(Global.LOBBY_ID)

		Global.LOBBY_ID = 0

		chat_panel_label.text = 'Lobby Name'
		players_panel_label.text = 'Players (0)'
		players_panel_rich_text_label.clear()
		clearChatPanel()

		for members in Global.LOBBY_MEMBERS:
			if members['steam_id'] != Global.STEAM_ID:
				Steam.closeP2PSessionWithUser(int(members['steam_id']))

		Global.LOBBY_MEMBERS.clear()
		create_lobby_button.set_visible(true)



func clearChatPanel():
	chat_panel_rich_text_label.clear()


func sendChatMessage():
	# Get chat message text
	var message = send_message_line_edit.text
	if message == '':
		return
	# Clear chat message input text
	send_message_line_edit.clear()

	# Give the message to Steam
	var sent = Steam.sendLobbyChatMsg(Global.LOBBY_ID, message)

	if not sent:
		displayMessage('ERROR: Chat message failed to send')


func inviteFriends():
	Steam.activateGameOverlay()


func startGame():
	get_tree().change_scene_to_packed(Global.GAME_SCENE)


func readyUp():
	if Global.LOBBY_MEMBERS[getPlayerIndexBySteamID(Global.STEAM_ID)].is_ready:
		unready()
	else:
		ready_button.text = 'Locked In'
		Global.LOBBY_MEMBERS[getPlayerIndexBySteamID(Global.STEAM_ID)].is_ready = true
		toPlayerHost('ready', '')


func unready():
	ready_button.text = 'Ready Up'
	Global.LOBBY_MEMBERS[getPlayerIndexBySteamID(Global.STEAM_ID)].is_ready = false
	toPlayerHost('unready', '')


func handleReadyUp(steam_id):
	Global.LOBBY_MEMBERS[getPlayerIndexBySteamID(steam_id)].is_ready = true
	checkLobbyReadyStatus()


func handleUnready(steam_id):
	Global.LOBBY_MEMBERS[getPlayerIndexBySteamID(steam_id)].is_ready = false
	checkLobbyReadyStatus()


func checkLobbyReadyStatus():
	var ready_values_array = []
	for member in Global.LOBBY_MEMBERS:
		ready_values_array.append(member.is_ready)
	print(ready_values_array)
	print(not (false not in ready_values_array))
	start_game_button.disabled = not (false not in ready_values_array)


func getPlayerIndexBySteamID(player_steam_id):
	var count = 0
	for player in Global.LOBBY_MEMBERS:
		if player.steam_id == player_steam_id:
			return count
		count += 1



#####################################
######## STEAM CALLBACKS ############
#####################################

func _on_Lobby_Created(connect_id, lobby_id):
	if connect_id == 1:
		Global.LOBBY_ID = lobby_id
		Global.IS_HOST = true
		Global.PLAYERHOST_STEAM_ID = str(Steam.getSteamID())

		displayMessage("Created lobby: %s" % create_lobby_line_edit.text)

		# Set Lobby name
		Steam.setLobbyData(lobby_id, "name", create_lobby_line_edit.text)
		# Set the ID for the PlayerHost
		Steam.setLobbyData(lobby_id, 'playerhost_steam_id', Global.PLAYERHOST_STEAM_ID)
		chat_panel_label.text = Steam.getLobbyData(lobby_id, "name")

		# Allow P2P connections to fallback to being relayed through Steam if needed
		var is_relay: bool = Steam.allowP2PPacketRelay(true)
		displayMessage('[STEAM] Allowing Steam to be relay backup: %s' % str(is_relay))


func _on_Lobby_Joined(lobby_id, _permissions, _locked, _response):
	# Set our lobby id to match what lobby we're in
	Global.LOBBY_ID = lobby_id

	# This prevents a fun bug where if someone creates a game and then joins another game, there are now 2 playerhosts
	var playerhost_steam_id = Steam.getLobbyData(lobby_id, 'playerhost_steam_id')
	if playerhost_steam_id == null or playerhost_steam_id != Global.PLAYERHOST_STEAM_ID:
		Global.IS_HOST = false
		Global.PLAYERHOST_STEAM_ID = playerhost_steam_id

	start_game_button.set_visible(Global.IS_HOST)
	create_lobby_button.set_visible(false)
	# Playerhost will be made ready automatically later so we only need to show this to the other players
	ready_button.set_visible(not Global.IS_HOST)

	# Set panel lobby name
	chat_panel_label.text = Steam.getLobbyData(lobby_id, "name")

	# Get lobby members
	getLobbyMembers()

	# This makes it so that the PlayerHost is automatically ready
	if Global.IS_HOST:
		handleReadyUp(Global.STEAM_ID)

	makeP2PHandshake()


func _on_Lobby_Join_Requested(lobby_id, friend_id):
	# Get lobby owners name
	var owner_name = Steam.getFriendPersonaName(friend_id)
	displayMessage("Joining %s lobby..." % str(owner_name))

	# Join lobby
	joinLobby(lobby_id)


func _on_Lobby_Data_Update(lobby_id, member_id, key):
	print("Success, Lobby ID: %s, Member ID: %s, Key: %s" % [lobby_id, member_id, key])


func _on_Lobby_Chat_Update(_lobby_id, _changed_id, making_change_id, chat_state):
	# User who made lobby change
	var changer = Steam.getFriendPersonaName(making_change_id)

	match chat_state:
		1:
			displayMessage('%s has joined the lobby! :D' % str(changer))
		2:
			displayMessage('%s has left the lobby :(' % str(changer))
		4:
			displayMessage('%s has been disconnected' % str(changer))
		8:
			displayMessage('%s has been kicked from the lobby' % str(changer))
		16:
			displayMessage('%s has been banned from the lobby' % str(changer))
		_:
			displayMessage('%s did something...' % str(changer))

	getLobbyMembers()


func _on_Lobby_Message(_result, user, message, _type):
	var sender = Steam.getFriendPersonaName(user)
	displayMessage('%s : %s' % [str(sender), str(message)])


func _loaded_avatar(player_steam_id: int, size: int, buffer: PackedByteArray):
	# Create the image and texture for loading
	var AVATAR: Image = Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, buffer)

	# Optionally resize the image if it is too large
	if size > 128:
		AVATAR.resize(128, 128, Image.INTERPOLATE_LANCZOS)

	# Apply the image to a texture
	var AVATAR_TEXTURE: ImageTexture = ImageTexture.create_from_image(AVATAR)

	# Save this texture to the correct player's profile_picture attribute
	print('balls')
	print(AVATAR_TEXTURE)
	Global.LOBBY_MEMBERS[getPlayerIndexBySteamID(str(player_steam_id))].setTexture(AVATAR_TEXTURE)







#####################################
######### P2P NETWORKING ############
#####################################

func makeP2PHandshake() -> void:
	displayMessage("[STEAM] Sending P2P handshake to the lobby...\n")
	toEveryone('handshake', {'from': Global.STEAM_NAME})


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
		match readable['type']:
			'start': displayMessage('[STEAM] Starting P2P game...')
			'startGame': startGame()
			'ready': handleReadyUp(player_steam_id)
			'unready': handleUnready(player_steam_id)
		if Global.IS_HOST:
			match readable['type']:
				'handshake': checkLobbyReadyStatus()


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
		if Global.LOBBY_MEMBERS.size() > 1:
			# Loop through all members that aren't you
			for member in Global.LOBBY_MEMBERS:
				if member['steam_id'] != Global.STEAM_ID:
					send_response = Steam.sendP2PPacket(int(member['steam_id']), packet_data, send_type, channel)
	# Else send the packet to a particular user
	else:
		# Send this packet
		send_response = Steam.sendP2PPacket(target, packet_data, send_type, channel)
	# The packets send response is...?
	displayMessage('[STEAM] P2P packet sent successfully? %s' % str(send_response))


func toEveryone(type, data):
	sendP2PPacket(0, {'type': type, 'data': data})

func toPlayerHost(type, data):
	sendP2PPacket(int(Global.PLAYERHOST_STEAM_ID), {'type': type, 'data': data})



#####################################
######## OTHER GOOD GOOD ############
#####################################

# Connect a Steam signal and show the success code
func connectSteamSignals(this_signal: String, this_function: String) -> void:
	var SIGNAL_CONNECT: int = Steam.connect(this_signal, Callable(self, this_function))
	if SIGNAL_CONNECT > OK:
		print("[STEAM] Connecting "+str(this_signal)+" to "+str(this_function)+" failed: "+str(SIGNAL_CONNECT))


func _check_Command_Line():
	var ARGUMENTS = OS.get_cmdline_args()
	# Check if detected arguments
	if ARGUMENTS.size() > 0:
		for argument in ARGUMENTS:
			# Invite argument passed
			if Global.LOBBY_INVITE_ARG:
				joinLobby(int(argument))

			# Steam connection argument
			if argument == "+connect_lobby":
				Global.LOBBY_INVITE_ARG = true







#####################################
######### BUTTON METHODS ############
#####################################

func _input(event):
	if event.is_action_pressed('send_message'):
		sendChatMessage()


func _on_create_lobby_button_pressed():
	if create_lobby_line_edit.text == '':
		return
	createLobby()


func _on_leave_lobby_button_pressed():
	if Global.LOBBY_ID != 0:
		leaveLobby()


func _on_start_game_button_pressed():
	if Global.IS_HOST:
		toEveryone('startGame', '')
	startGame()


func _on_send_message_button_pressed():
	sendChatMessage()


func _on_invite_friends_button_pressed():
	inviteFriends()


func _on_ready_button_pressed():
	readyUp()
