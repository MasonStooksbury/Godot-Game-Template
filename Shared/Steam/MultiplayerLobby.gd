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



func kickButtonPressed(player_steam_id) -> void:
	if Global.SteamManager.IS_HOST:
		toSpecificPlayer(player_steam_id, 'kick')






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
