extends Node2D

enum search_distance {Close, Default, Far, Worldwide}

@onready var steam_name = $SteamName
@onready var create_lobby_text_edit = $CreateLobbyButton/CreateLobbyTextEdit
@onready var create_lobby_label = $CreateLobbyButton/CreateLobbyLabel
@onready var players_panel_label = $PlayersPanel/PlayersPanelLabel
@onready var players_panel_rich_text_label = $PlayersPanel/PlayersPanelRichTextLabel
@onready var chat_panel_label = $ChatPanel/ChatPanelLabel
@onready var chat_panel_rich_text_label = $ChatPanel/ChatPanelRichTextLabel






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



func createLobby():
	if Global.LOBBY_ID == 0:
		Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, Global.LOBBY_MAX_MEMBERS)


func displayMessage(message):
	chat_panel_rich_text_label.add_text("\n" + str(message))










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
#			if Global.LOBBY_INVITE_ARG:
#				joinLobby(int(argument))

			# Steam connection argument
			if argument == "+connect_lobby":
				Global.LOBBY_INVITE_ARG = true



func _on_create_lobby_button_pressed():
	createLobby()


func _on_join_lobby_button_pressed():
	pass # Replace with function body.


func _on_leave_lobby_button_pressed():
	pass # Replace with function body.


func _on_start_game_button_pressed():
	pass # Replace with function body.


func _on_send_message_button_pressed():
	pass # Replace with function body.
