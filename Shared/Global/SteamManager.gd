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





extends Control

@onready var midpoint = $Midpoint
@onready var chat_panel_label = $ChatPanel/MarginContainer/VBoxContainer/ChatPanelLabel
@onready var chat_panel_rtl = $ChatPanel/MarginContainer/VBoxContainer/ChatPanelRTL
@onready var chat_panel = $ChatPanel
@onready var send_message_line_edit = $ChatPanel/MarginContainer/VBoxContainer/HBoxContainer/SendMessageLineEdit
@onready var start_game_button = $StartGameButton
@onready var ready_button = $ReadyButton
@onready var invite_friends_button = $InviteFriendsButton
@onready var lobby_member_number_label = $InviteFriendsButton/CurrentLobbyMemberNumberLabel

var external_invite: bool = false

var players

#var players = [
#		{'steam_id': '987987987987987', 'steam_name': 'Daddy', 'large_profile_picture': Global.ICON_IMAGE},
#		{'steam_id': '76561198150278432', 'steam_name': 'Son', 'large_profile_picture': null},
#		{'steam_id': '987987987987987', 'steam_name': 'OtherDaddy', 'large_profile_picture': Global.ICON_IMAGE},
#		{'steam_id': '987987987987987', 'steam_name': 'OtherDaddy', 'large_profile_picture': Global.ICON_IMAGE},
#		{'steam_id': '987987987987987', 'steam_name': 'OtherDaddy', 'large_profile_picture': Global.ICON_IMAGE},
#		{'steam_id': '987987987987987', 'steam_name': 'OtherDaddy', 'large_profile_picture': Global.ICON_IMAGE},
#		{'steam_id': '987987987987987', 'steam_name': 'OtherDaddy', 'large_profile_picture': Global.ICON_IMAGE},
#		{'steam_id': '987987987987987', 'steam_name': 'OtherDaddy', 'large_profile_picture': Global.ICON_IMAGE},
#		{'steam_id': '987987987987987', 'steam_name': 'OtherDaddy', 'large_profile_picture': Global.ICON_IMAGE},
#		{'steam_id': '987987987987987', 'steam_name': 'OtherDaddy', 'large_profile_picture': Global.ICON_IMAGE},
#	]



func _ready() -> void:
	connectSteamSignals("lobby_created", "_on_Lobby_Created")
	connectSteamSignals("lobby_chat_update", "_on_Lobby_Chat_Update")
	connectSteamSignals("lobby_message", "_on_Lobby_Message")
	connectSteamSignals("lobby_data_update", "_on_Lobby_Data_Update")
	connectSteamSignals("p2p_session_request", "_on_P2P_Session_Request")
	connectSteamSignals("p2p_session_connect_fail", "_on_P2P_Session_Connect_Fail")
	connectSteamSignals("avatar_loaded", "_loaded_avatar")
	Global.SignalManager.kick_button_pressed.connect(kickButtonPressed) # Arguments passed: player_steam_id


	# This will only happen if someone isn't already in a populated lobby (i.e. they're by themselves)
	if Global.SteamManager.LOBBY_ID == 0:
		createLobby()

	handleScreenResize()
	get_tree().get_root().connect('size_changed', handleScreenResize)


func _process(_delta) -> void:
	if Global.SteamManager.LOBBY_ID > 0:
		readP2PPacket()


func handleScreenResize() -> void:
	midpoint.global_position = Global.SCREEN_CENTER



# Rearrange the array so that each player is at the front center of the "table"
func reorganizeAndRenderPlayers() -> void:
	# If we don't do a deep copy, our reorganization will ruin the Global order
	# Also needs to happen here to make sure it happens after the lobby is created and we are added to it
	#		as well as being refreshed often
	players = Global.SteamManager.LOBBY_MEMBERS.duplicate(true)
	lobby_member_number_label.text = '%s/%s' % [players.size(), Global.LOBBY_MAX_MEMBERS]
	if not players.is_empty():
		while players[0].steam_id != Global.SteamManager.STEAM_ID:
			players.push_back(players.pop_front())
		renderPlayers()


func renderPlayers() -> void:
	var num_players = players.size()
	var starting_angle = 180
	var additional_angle = 360.0/num_players
	var count = 0
	derenderPlayers()
	for player in players:
		var member = Global.LOBBY_MEMBER_SCENE.instantiate()
		midpoint.add_child(member)
		member.setName(player.steam_name)
		member.setSteamID(player.steam_id)
		# Don't show the kick button for me or the PlayerHost
		if not Global.SteamManager.IS_HOST or player.steam_id == Global.SteamManager.PLAYERHOST_STEAM_ID or player.steam_id == Global.SteamManager.STEAM_ID:
			member.hideKickButton()
		if player.large_profile_picture == null:
			player.large_profile_picture = Global.SteamManager.LOBBY_MEMBERS[0].large_profile_picture
		member.setTexture(player.large_profile_picture)

		var profile_distance = Vector2(0,0)
		match num_players:
			1, 2, 4, 6:
				profile_distance += Vector2(0, -400)
			3:
				if count == 0:
					profile_distance += Vector2(0, -400)
				else:
					profile_distance += Vector2(0, -550)
			5, 7, 8, 9, 10:
				if count == 0:
					profile_distance += Vector2(0, -425)
				else:
					profile_distance += Vector2(0, -450)
		member.global_position += profile_distance

		var new_vector = member.global_position - midpoint.global_position

		member.global_position = Global.rotateClockwise(new_vector, starting_angle) + midpoint.global_position
		starting_angle += additional_angle

		count += 1


func derenderPlayers() -> void:
	for child in midpoint.get_children():
		midpoint.remove_child(child)
		child.queue_free()



#####################################
###### USER DEFINED FUNCTIONS #######
#####################################

func displayMessage(message) -> void:
	chat_panel_rtl.add_text("\n" + str(message))


func createLobby() -> void:
	if Global.SteamManager.LOBBY_ID == 0:
		Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, Global.LOBBY_MAX_MEMBERS)


func getLobbyMembers() -> void:
	Global.SteamManager.LOBBY_MEMBERS.clear()

	# Get number of members in lobby
	var member_count = Steam.getNumLobbyMembers(Global.SteamManager.LOBBY_ID)

	# Get member data
	for member in range(0, member_count):
		var member_steam_id = Steam.getLobbyMemberByIndex(Global.SteamManager.LOBBY_ID, member)

		var member_steam_name = Steam.getFriendPersonaName(member_steam_id)

		Steam.getPlayerAvatar(Steam.AVATAR_LARGE, member_steam_id)

		var player_object = {
			'steam_id': member_steam_id,
			'steam_name': member_steam_name,
		}

		addPlayerList(player_object)
	checkMaxLobbyMembersReached()
	reorganizeAndRenderPlayers()


func addPlayerList(player_object) -> void:
	Global.SteamManager.LOBBY_MEMBERS.append(Global.PLAYER_CLASS.new(player_object))

	if Global.SteamManager.IS_HOST:
		Global.SteamManager.LOBBY_MEMBERS[getPlayerIndexBySteamID(Global.SteamManager.STEAM_ID)].is_ready = true


func leaveLobby() -> void:
	if Global.SteamManager.LOBBY_ID != 0:
		displayMessage('Leaving lobby...')

		Steam.leaveLobby(Global.SteamManager.LOBBY_ID)

		Global.SteamManager.LOBBY_ID = 0

		chat_panel.setLabelText('Lobby Name')
		clearChatPanel()

		for members in Global.SteamManager.LOBBY_MEMBERS:
			if members['steam_id'] != Global.SteamManager.STEAM_ID:
				Steam.closeP2PSessionWithUser(int(members['steam_id']))

		Global.SteamManager.LOBBY_MEMBERS.clear()


func kickedFromLobby() -> void:
	leaveLobby()
	get_tree().change_scene_to_packed(Global.TITLE_SCREEN_SCENE)


func clearChatPanel() -> void:
	chat_panel_rtl.clear()


func sendChatMessage() -> void:
	# Get chat message text
	var message = send_message_line_edit.text
	if message == '':
		return
	# Clear chat message input text
	send_message_line_edit.clear()

	# Give the message to Steam
	var sent = Steam.sendLobbyChatMsg(Global.SteamManager.LOBBY_ID, message)

	if not sent:
		displayMessage('ERROR: Chat message failed to send')


func inviteFriends() -> void:
	Steam.activateGameOverlayInviteDialog(Global.SteamManager.LOBBY_ID)


func startGame() -> void:
	get_tree().change_scene_to_packed(Global.GAME_SCENE)
	Global.SoundManager.playSound('start_game')


func readyUp() -> void:
	if Global.SteamManager.LOBBY_MEMBERS[getPlayerIndexBySteamID(Global.SteamManager.STEAM_ID)].is_ready:
		unready()
	else:
		ready_button.text = 'Unready'
		Global.SteamManager.LOBBY_MEMBERS[getPlayerIndexBySteamID(Global.SteamManager.STEAM_ID)].is_ready = true
		toPlayerHost('ready', '')


func unready() -> void:
	ready_button.text = 'Ready Up'
	Global.SteamManager.LOBBY_MEMBERS[getPlayerIndexBySteamID(Global.SteamManager.STEAM_ID)].is_ready = false
	toPlayerHost('unready', '')


func handleReadyUp(steam_id) -> void:
	Global.SteamManager.LOBBY_MEMBERS[getPlayerIndexBySteamID(steam_id)].is_ready = true
	checkLobbyReadyStatus()


func handleUnready(steam_id) -> void:
	Global.SteamManager.LOBBY_MEMBERS[getPlayerIndexBySteamID(steam_id)].is_ready = false
	checkLobbyReadyStatus()


func checkLobbyReadyStatus() -> void:
	var ready_values_array = []
	for member in Global.SteamManager.LOBBY_MEMBERS:
		ready_values_array.append(member.is_ready)

	start_game_button.disabled = not (false not in ready_values_array)


func getPlayerIndexBySteamID(player_steam_id: String) -> int:
	var count = 0
	for player in Global.SteamManager.LOBBY_MEMBERS:
		if player.steam_id == player_steam_id:
			break
		count += 1
	return count


func checkMaxLobbyMembersReached() -> void:
	if Steam.getNumLobbyMembers(Global.SteamManager.LOBBY_ID) >= Global.LOBBY_MAX_MEMBERS:
		invite_friends_button.disabled = true


func kickButtonPressed(player_steam_id) -> void:
	if Global.SteamManager.IS_HOST:
		toSpecificPlayer(player_steam_id, 'kick')






#####################################
######## STEAM CALLBACKS ############
#####################################

#func _on_Lobby_Created(connect_id, lobby_id) -> void:
#	if connect_id == 1:
#		Global.SteamManager.LOBBY_ID = lobby_id
#		Global.SteamManager.IS_HOST = true
#		Global.SteamManager.PLAYERHOST_STEAM_ID = str(Steam.getSteamID())
#
#		# Set Lobby name
#		Steam.setLobbyData(lobby_id, "name", "%s's Lobby" % Global.SteamManager.STEAM_NAME)
#		# Set the ID for the PlayerHost
#		Steam.setLobbyData(lobby_id, 'playerhost_steam_id', Global.SteamManager.PLAYERHOST_STEAM_ID)
#		chat_panel_label.text = Steam.getLobbyData(lobby_id, "name")
#
#		# Allow P2P connections to fallback to being relayed through Steam if needed
#		var is_relay: bool = Steam.allowP2PPacketRelay(true)
#		displayMessage('[STEAM] Allowing Steam to be relay backup: %s' % str(is_relay))

func _on_Lobby_Created(connect_id, lobby_id) -> void:
	if connect_id == 1:
		print('lobby created?')
		Global.SteamManager.LOBBY_ID = lobby_id
		Global.SteamManager.IS_HOST = true
		Global.SteamManager.PLAYERHOST_STEAM_ID = str(Steam.getSteamID())

		# Set Lobby name
		Steam.setLobbyData(lobby_id, "name", "%s's Lobby" % Global.SteamManager.STEAM_NAME)
		# Set the ID for the PlayerHost
		Steam.setLobbyData(lobby_id, 'playerhost_steam_id', Global.SteamManager.PLAYERHOST_STEAM_ID)

		# Allow P2P connections to fallback to being relayed through Steam if needed
		Steam.allowP2PPacketRelay(true)
		chat_panel.setLabelText(Steam.getLobbyData(lobby_id, "name"))

		# Allow P2P connections to fallback to being relayed through Steam if needed
		var is_relay: bool = Steam.allowP2PPacketRelay(true)
		displayMessage('[STEAM] Allowing Steam to be relay backup: %s' % str(is_relay))


func _on_Lobby_Join_Requested(lobby_id, friend_id) -> void:
	external_invite = true
	# Get lobby owners name
	var owner_name = Steam.getFriendPersonaName(friend_id)
#	displayMessage("Joining %s lobby..." % str(owner_name))

	# Join lobby
	joinLobby(lobby_id)


func joinLobby(lobby_id) -> void:
	if Steam.getNumLobbyMembers(lobby_id) >= Global.LOBBY_MAX_MEMBERS:
		return
#	displayMessage("Joining %s lobby..." % Steam.getLobbyData(lobby_id, "name"))

	# Clear previous lobby members list
	Global.SteamManager.LOBBY_MEMBERS.clear()

	# Steam join request
	Steam.joinLobby(lobby_id)


func _on_Lobby_Joined(lobby_id, _permissions, _locked, _response) -> void:
	# Set our lobby id to match what lobby we're in
	Global.SteamManager.LOBBY_ID = lobby_id

	# This prevents a fun bug where if someone creates a game and then joins another game, there are now 2 playerhosts
	var playerhost_steam_id = Steam.getLobbyData(lobby_id, 'playerhost_steam_id')
	if playerhost_steam_id == null or playerhost_steam_id != Global.SteamManager.PLAYERHOST_STEAM_ID:
		Global.SteamManager.IS_HOST = false
		Global.SteamManager.PLAYERHOST_STEAM_ID = playerhost_steam_id

	if external_invite:
		get_tree().change_scene_to_packed(Global.MULTIPLAYER_LOBBY_SCENE)
		# TODO: Not sure how low we can make this, but 1 second definitely works
		await get_tree().create_timer(0.5).timeout


	start_game_button.set_visible(Global.SteamManager.IS_HOST)
	# Playerhost will be made ready automatically later so we only need to show this to the other players
	ready_button.set_visible(not Global.SteamManager.IS_HOST)

	# Set panel lobby name
	chat_panel.setLabelText(Steam.getLobbyData(lobby_id, "name"))

	# Get lobby members
	getLobbyMembers()

	# This makes it so that the PlayerHost is automatically ready
	if Global.SteamManager.IS_HOST:
		handleReadyUp(Global.SteamManager.STEAM_ID)

	makeP2PHandshake()


func _on_Lobby_Data_Update(lobby_id, member_id, key) -> void:
	print("Success, Lobby ID: %s, Member ID: %s, Key: %s" % [lobby_id, member_id, key])


func _on_Lobby_Chat_Update(_lobby_id, _changed_id, making_change_id, chat_state) -> void:
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


func _on_Lobby_Message(_result, user, message, _type) -> void:
	var sender = Steam.getFriendPersonaName(user)
	displayMessage('%s : %s' % [str(sender), str(message)])


func _loaded_avatar(player_steam_id: int, image_size: int, buffer: PackedByteArray) -> void:
	# Create the image and texture for loading
	var avatar_image: Image = Image.create_from_data(image_size, image_size, false, Image.FORMAT_RGBA8, buffer)

	# Set a larger version of the avatar to be used elsewhere
	avatar_image.resize(128, 128, Image.INTERPOLATE_LANCZOS)
	var large_avatar_texture: ImageTexture = ImageTexture.create_from_image(avatar_image)
	Global.SteamManager.LOBBY_MEMBERS[getPlayerIndexBySteamID(str(player_steam_id))].setLargeTexture(large_avatar_texture)

	# Resize the image if it is too large
	if image_size > 128:
		avatar_image.resize(128, 128, Image.INTERPOLATE_LANCZOS)

	# Apply the image to a texture
	var avatar_image_texture: ImageTexture = ImageTexture.create_from_image(avatar_image)

	# Save this texture to the correct player's profile_picture attribute
	Global.SteamManager.LOBBY_MEMBERS[getPlayerIndexBySteamID(str(player_steam_id))].setTexture(avatar_image_texture)
	# TODO: Undo this?
	reorganizeAndRenderPlayers()
#	renderPlayers()







#####################################
######### P2P NETWORKING ############
#####################################

func makeP2PHandshake() -> void:
	displayMessage("[STEAM] Sending P2P handshake to the lobby...\n")
	toEveryone('handshake', {'from': Global.SteamManager.STEAM_NAME})


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
			'kick': kickedFromLobby()
		if Global.SteamManager.IS_HOST:
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
		if Global.SteamManager.LOBBY_MEMBERS.size() > 1:
			# Loop through all members that aren't you
			for member in Global.SteamManager.LOBBY_MEMBERS:
				if member['steam_id'] != Global.SteamManager.STEAM_ID:
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
	sendP2PPacket(int(Global.SteamManager.PLAYERHOST_STEAM_ID), {'type': type, 'data': data})

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





#####################################
######### BUTTON METHODS ############
#####################################
func _on_hover() -> void:
	Global.SoundManager.playSound('hover_02')


func _input(event) -> void:
	if event.is_action_pressed('send_message'):
		sendChatMessage()


func _on_leave_lobby_button_pressed() -> void:
	Global.SoundManager.playSound('select')
	if Global.SteamManager.LOBBY_ID != 0:
		leaveLobby()
	get_parent()._on_back_button_pressed()


func _on_start_game_button_pressed() -> void:
	Global.SoundManager.playSound('select')
	if Global.SteamManager.IS_HOST:
		toEveryone('startGame', '')
	startGame()


func _on_send_message_button_pressed() -> void:
	Global.SoundManager.playSound('select')
	sendChatMessage()


func _on_invite_friends_button_pressed() -> void:
	Global.SoundManager.playSound('select')
	inviteFriends()


func _on_ready_button_pressed() -> void:
	Global.SoundManager.playSound('select')
	readyUp()
