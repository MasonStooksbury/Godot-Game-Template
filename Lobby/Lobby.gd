extends Node2D

enum search_distance {Close, Default, Far, Worldwide}

@onready var steam_name = $SteamName
@onready var create_lobby_text_edit = $CreateLobbyButton/CreateLobbyTextEdit
@onready var create_lobby_label = $CreateLobbyButton/CreateLobbyLabel
@onready var players_panel_label = $PlayersPanel/PlayersPanelLabel
@onready var players_panel_rich_text_label = $PlayersPanel/PlayersPanelRichTextLabel
@onready var chat_panel_label = $ChatPanel/ChatPanelLabel
@onready var chat_panel_rich_text_label = $ChatPanel/ChatPanelRichTextLabel
@onready var lobby_list_popup_panel = $LobbyListPopupPanel
@onready var lobby_list_popup_panel_vbox_container = $LobbyListPopupPanel/Panel/ScrollContainer/VBoxContainer






func _ready():
	steam_name.text = Global.STEAM_NAME

	connectSteamSignals("lobby_created", "_on_Lobby_Created")
	connectSteamSignals("lobby_match_list", "_on_Lobby_Match_List")
	connectSteamSignals("lobby_joined", "_on_Lobby_Joined")
	connectSteamSignals("lobby_chat_update", "_on_Lobby_Chat_Update")
	connectSteamSignals("lobby_message", "_on_Lobby_Message")
	connectSteamSignals("lobby_data_update", "_on_Lobby_Data_Update")
	connectSteamSignals("lobby_invite", "_on_Lobby_Invite")
	connectSteamSignals("join_requested", "_on_Lobby_Join_Requested")
#	connectSteamSignals("persona_state_change", "_on_Persona_Change")
	connectSteamSignals("p2p_session_request", "_on_P2P_Session_Request")
	connectSteamSignals("p2p_session_connect_fail", "_on_P2P_Session_Connect_Fail")


func displayMessage(message):
	chat_panel_rich_text_label.add_text("\n" + str(message))



func createLobby():
	if Global.LOBBY_ID == 0:
		Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, Global.LOBBY_MAX_MEMBERS)



func joinLobby(lobby_id):
	lobby_list_popup_panel.hide()
	var name = Steam.getLobbyData(lobby_id, "name")
	displayMessage("Joining %s lobby..." % str(name))

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

		addPlayerList(member_steam_id, member_steam_name)



func addPlayerList(steam_id, steam_name):
	Global.LOBBY_MEMBERS.append({'steam_id': steam_id, 'steam_name': steam_name})

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

		for members in Global.LOBBY_MEMBERS:
			Steam.closeP2PSessionWithUser(members['steam_id'])

		Global.LOBBY_MEMBERS.clear()


#################################
######## STEAM CALLBACKS ########
#################################

func _on_Lobby_Created(connect, lobby_id):
	print('created?')
	if connect == 1:
		Global.LOBBY_ID = lobby_id
		displayMessage("Created lobby: %s" % create_lobby_text_edit.text)

		# Set Lobby name
		Steam.setLobbyData(lobby_id, "name", create_lobby_text_edit.text)
		var name = Steam.getLobbyData(lobby_id, "name")
		chat_panel_label.text = str(name)



func _on_Lobby_Joined(lobby_id, permissions, locked, response):
	# Set our lobby id to match what lobby we're in
	Global.LOBBY_ID = lobby_id

	# Set panel lobby name
	var name = Steam.getLobbyData(lobby_id, "name")
	chat_panel_label.text = str(name)

	# Get lobby members
	getLobbyMembers()



func _on_Lobby_Join_Requested(lobby_id, friend_id):
	# Get lobby owners name
	var owner_name = Steam.getFriendPersonaName(friend_id)
	displayMessage("Joining %s lobby..." % str(owner_name))

	# Join lobby
	joinLobby(lobby_id)



func _on_Lobby_Data_Update(success, lobby_id, member_id, key):
	print("Success: %s, Lobby ID: %s, Member ID: %s, Key: %s", [success, lobby_id, member_id, key])



func _on_Lobby_Chat_Update(lobby_id, changed_id, making_change_id, chat_state):
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



#func _on_Lobby_Match_List(lobbies):
#	for lobby in lobbies:
#		var lobby_name = Steam.getLobbyData(lobby, 'name')
#
#		var lobby_members = Steam.getNumLobbyMembers(lobby)
#
#		var lobby_button = Button.new()
#		lobby_button.set_text('Lobby %s: %s - [%s] Players(s)')
#		lobby_button.set_size(Vector2(800,50))
#		lobby_button.set_name('lobby_%s' % str(lobby))
##		lobby_button.pressed.connect('joinLobby')
#
#		lobby_list_popup_panel_vbox_container.add_child(lobby_button)






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



func _on_create_lobby_button_pressed():
	createLobby()


func _on_join_lobby_button_pressed():
	lobby_list_popup_panel.popup()

	# Set server search distance to worldwide
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	displayMessage("Searching for lobbies...")

	Steam.requestLobbyList()


func _on_leave_lobby_button_pressed():
	pass # Replace with function body.


func _on_start_game_button_pressed():
	pass # Replace with function body.


func _on_send_message_button_pressed():
	pass # Replace with function body.


func _on_close_lobby_list_button_pressed():
	lobby_list_popup_panel.hide()
