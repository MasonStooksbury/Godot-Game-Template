extends Node2D


# Steam
var steam_name
var steam_id


# UI
var leave_game_button
var quit_game_button
var play_log_rich_text_label
var turn_direction_sprite
var win_dialog
var extra_card_label
var player_renderer
var play_log_panel
var toggle_play_log_button

var top_of_discard_pile # Card
var current_color
var turn_direction

# Popup Windows
var color_selector
var play_or_keep_selector
var player_selector
var play_card_confirmation
var special_card_selector
var new_game_selector
var general_popup

var discard_pile_position = Vector2(125, 270)
var draw_pile_position = Vector2(300, 270)

var midpoint_radius = 700
var midpoint


# Player
var is_turn = false
var hand = []
var just_drew = false


var debug = false



func _init():
	# Enable processing. Without this, our _process functions will not run
	set_process(true)
	randomize()

	leave_game_button = $LeaveGameButton
	quit_game_button = $QuitGameButton
	midpoint = $HandMidpoint
	turn_direction_sprite = $TurnDirectionSprite
	win_dialog = $WinDialog
	extra_card_label = $CardsToDrawLabel/Label
	player_renderer = $PlayerRenderer
	play_card_confirmation = $PopupWindows/PlayCardConfirmation
	play_or_keep_selector = $PopupWindows/PlayOrKeepSelector
	special_card_selector = $PopupWindows/SpecialCardSelector
	player_selector = $PopupWindows/PlayerSelector
	color_selector = $PopupWindows/ColorSelector
	new_game_selector = $PopupWindows/NewGameSelector
	general_popup = $PopupWindows/GeneralPopup
	play_log_panel = $PlayLogPanel
	play_log_rich_text_label = $PlayLogPanel/RichTextLabel

	debug_print(Global.SteamManager.LOBBY_MEMBERS)

	var viewport_dimensions = get_viewport().get_visible_rect().size
	midpoint.global_position = Vector2(viewport_dimensions.x/2, 1200)

	# Create discard pile card on UI
	createCard('discard', 'DiscardPile', discard_pile_position)

	# Create draw pile card on UI
	createCard('draw', 'DrawPile', draw_pile_position)

	_ready()


func _ready():
	setupConnections()
	# TODO: Delete this?
	#updatePlayerCardCount(Global.SteamManager.STEAM_ID, 10)


func _process(_delta):
	if Global.SteamManager.LOBBY_ID > 0:
		playerReadP2PPacket()


func debug_print(stuff):
	if debug:
		print(stuff)




#####################################
###### USER DEFINED FUNCTIONS #######
#####################################

func displayMessage(message):
	play_log_rich_text_label.add_text("\n" + str(message))


func clearDisplayMessageWindow():
	play_log_rich_text_label.clear()


func playCard(data):
	if not is_turn:
		return

	var card_object = {'special_card': null, 'hand_card_data': data, 'skip_distance': 2}
	if Global.dataToCard(data).is_special:
		card_object['special_card'] = await handleSpecialCard(data)
	debug_print(card_object['special_card'])

	if not just_drew:
		var play_decision = await playCardConfirmation(data)
		if play_decision == 'No':
			enableHand()
			return


	removeCardFromHand(data)
	removeCardFromHandUI(data)

	var skip_distance = 2
	# TODO: Any way to do this card_object thing any better?
	if (data[1] == 'S' or (card_object.special_card != null and card_object.special_card.card_type == 'S')) and top_of_discard_pile.is_special:
		skip_distance = 1
	card_object.skip_distance = skip_distance if data[1] == 'S' or (card_object.special_card != null and card_object.special_card.card_type == 'S') else 1
	toPlayerHost('fromPlayer', {'action': 'playCard', 'card': card_object})
	updateTurn(false)


func updateTurn(update):
	is_turn = update
	debug_print('current color: %s' % current_color)

	if is_turn:
		disableHand()
		general_popup.showWindow("It's my turn!")
		await general_popup.clicked_confirm
		enableHand()
		modifyHandVisibility()
	else:
		debug_print('its not my turn')
		disableHand()
		# TODO: Handle whatever happens when it's not my turn


func canPlayCard(card_to_check):
	var color_to_check = current_color if top_of_discard_pile.color != current_color else top_of_discard_pile.color

	if (((color_to_check == 'Z') and card_to_check.is_special) or
			(top_of_discard_pile.is_special and card_to_check.is_special) or
			(color_to_check == card_to_check.color) or
			(top_of_discard_pile.value == card_to_check.value) or
			(card_to_check.color == 'Z')):
		return true
	return false


func modifyHandVisibility():
	for card in midpoint.get_children():
		if not canPlayCard(Global.dataToCard(card.getData())):
			card.disable()



func endTurn():
	toPlayerHost('fromPlayer', {'action': 'endTurn'})
	updateTurn(false)


func setDiscardPile(data):
	top_of_discard_pile = Global.dataToCard(data)
	current_color = top_of_discard_pile.color
	get_node('DiscardPile').setData(top_of_discard_pile.data)


func drawCard():
	if not is_turn:
		return
	disableHand()
	toPlayerHost('fromPlayer', {'action': 'drawCard'})


# TODO: Should this be data or a card?
func removeCardFromHand(data):
	var count = 0
	for card_object in hand:
		if card_object.data == data:
			hand.remove_at(count)
			return
		count += 1


func playOrKeep(card):
	disableHand()
	# Show dialog to choose special
	play_or_keep_selector.showWindow(card.data)
	await play_or_keep_selector.option_selected

	return play_or_keep_selector.getSelection()


func playCardConfirmation(data):
	disableHand()
	# Show dialog to choose special
	play_card_confirmation.showWindow(data)
	await play_card_confirmation.option_selected

	return play_card_confirmation.getSelection()


# TODO: Delete this gross-ness
func setWinDialogText(text):
	win_dialog.get_node('Label').text = text


func createCard(type, node_name, pile_position):
	var card = Global.CARD_SCENE.instantiate()
	card.setup(type)
	card.name = node_name
	card.global_position = pile_position
	add_child(card)


func addCardToHandUI(card):
	var c = Global.CARD_SCENE.instantiate()
	c.setup('hand')
	c.setData(card.data)
	midpoint.add_child(c)
	centerHand()


# TODO: Should this be data or a card?
func removeCardFromHandUI(data):
	for child in midpoint.get_children():
		# While I did - confusingly - name this "getData", the child here is not a Card instance
		if child.getData() == data:
			midpoint.remove_child(child)
			child.queue_free()
			centerHand()
			return


func clearHandUI():
	for child in midpoint.get_children():
		midpoint.remove_child(child)
		child.queue_free()


func centerHand():
	var children = midpoint.get_children()
	var orphans = []

	for child in children:
		midpoint.remove_child(child)
		orphans.append(child)

	orphans.sort_custom(func(a, b): return a.getData() < b.getData())
	for orphan in orphans:
		midpoint.add_child(orphan)

	var rotate_degrees = 3 if midpoint.get_children().size() > 1 else 0
	var starting_angle = -((midpoint.get_children().size() - 1) * rotate_degrees)/2.0

	# Reset all of the cards back to an original position and rotation so the math works
	for child in midpoint.get_children():
		child.global_position = midpoint.global_position + Vector2(0, -midpoint_radius)
		child.global_rotation_degrees = 0

	# Now rotate all cards around the midpoint, then rotate each card individually to match their global rotation
	for child in midpoint.get_children():
		var new_vector = child.global_position - midpoint.global_position

		child.global_position = Global.rotateClockwise(new_vector, starting_angle) + midpoint.global_position
		child.global_rotation_degrees += starting_angle
		starting_angle += rotate_degrees


func removeCardFromArray(array, card):
	var count = 0
	for thing in array:
		if thing.getData() == card.getData():
			array.remove_at(count)
			return
		count += 1


# Save this for debugging/testing
#func _draw():
#	draw_circle_arc(midpoint.global_position, midpoint_radius, -90, 90, Color(1, 0, 0))


# Save this for debugging/testing
func draw_circle_arc(center, radius, angle_from, angle_to, color):
	var nb_points = 32
	var points_arc = PackedVector2Array()

	for i in range(nb_points + 1):
		var angle_point = deg_to_rad(angle_from + i * (angle_to-angle_from) / nb_points - 90)
		points_arc.push_back(center + Vector2(cos(angle_point), sin(angle_point)) * radius)

	for index_point in range(nb_points):
		draw_line(points_arc[index_point], points_arc[index_point + 1], color)
























func setupConnections():
	pass


func disableHand():
	for child in midpoint.get_children():
		child.disable()


func enableHand():
	for child in midpoint.get_children():
		child.enable()
	modifyHandVisibility()


func chooseSpecial():
	disableHand()
	# Show dialog to choose special
	special_card_selector.showWindow()
	await special_card_selector.card_selected
	return special_card_selector.getSelectedCard()


func chooseNewColor():
	disableHand()
	# Show dialog to choose new color
	color_selector.showWindow()
	await color_selector.color_selected

	return color_selector.getSelectedColor()


func choosePlayer():
	disableHand()
	player_selector.showWindow()
	await player_selector.player_selected

	return player_selector.getSelectedPlayerId()


func handleSpecialCard(data):
	var card_type = data[1]
	var chosen_player = null
	var new_color = data[0]

	match data[1]:
		'O':
			# Show "choose player for Omnidirectional NO-U" thing
			chosen_player = await choosePlayer()
		'A':
			# Have the player choose which special they want, but don't progress until they do
			var chosen_special = await chooseSpecial()
			card_type = chosen_special[1]

			if card_type == 'O':
				chosen_player = await choosePlayer()

	match data[1]:
		'W', 'F', 'O', 'A':
			# Have the player choose which color they want, but don't progress until they do
			new_color = await chooseNewColor()


	enableHand()
	return {'new_color': new_color, 'card_type': card_type, 'chosen_player': chosen_player}


func resetGame():
	hand = []
	just_drew = false
	clearHandUI()
	clearDisplayMessageWindow()
	hideWinnerPopup()


func showWinnerPopup(text):
	new_game_selector.showWindow(text)


func hideWinnerPopup():
	new_game_selector.hideWindow()


# TODO: Code this
func showFinalTurnDialog():
	pass


func setExtraCardCountLabel(count):
	extra_card_label.text = str(count)


func updatePlayerCardCount(player_steam_id, card_count):
	player_renderer.setPlayerCardCount(player_steam_id, card_count)


func togglePlayLogPanel():
	var animation_time = 0.10

	play_log_panel.set_pivot_offset(Global.getTopRightPivotOffset(play_log_panel))
	var new_value = !play_log_panel.visible
	if new_value:
		play_log_panel.visible = new_value
		create_tween().tween_property(play_log_panel, 'scale', Vector2(new_value, new_value), animation_time)
	else:
		await create_tween().tween_property(play_log_panel, 'scale', Vector2(new_value, new_value), animation_time).finished
		play_log_panel.visible = new_value


































#####################################
######## NETWORKING METHODS #########
#####################################

func toPlayerHost(type, data):
	sendP2PPacket(int(Global.SteamManager.PLAYERHOST_STEAM_ID), {'type': type, 'data': data})







#####################################
######### P2P NETWORKING ############
#####################################


func playerReadP2PPacket() -> void:
	var packet_size: int = Steam.getAvailableP2PPacketSize(0)
	# There is a packet
	if packet_size > 0:
		debug_print('[STEAM] There is a packet available.')
		# Get the packet
		var packet: Dictionary = Steam.readP2PPacket(packet_size, 0)
		# If it is empty, set a warning
		if packet.is_empty():
			debug_print('[WARNING] Read an empty packet with non-zero size!')
		# Get the remote user's ID
		# TODO69: Can this make it so that I don't need to pass in steam id?
		var _packet_sender: String = str(packet['steam_id_remote'])
		var packet_code: PackedByteArray = packet['data']
		# Make the packet data readable
		var readable: Dictionary = bytes_to_var(packet_code)
		# Print the packet to output
		#displayMessage('[STEAM] Packet from %s: %s' % [str(packet_sender), str(readable)])
		# Append logic here to deal with packet data
		debug_print('readable')
		debug_print(readable)
		match readable['type']:
			'receiveCards':
				for card in readable['data']:
					var card_object = Global.dataToCard(card)
					hand.append(card_object)
					addCardToHandUI(card_object)
			'receiveDrawCard':
				var card = Global.dataToCard(readable['data'])
				# TODO: If this logic ends up being the same as host, we need to put it somewhere
				displayMessage("You've been dealt a %s %s" % [Global.COLOR_DICT[card.data[0]], card.data[1]])
				var can_play = canPlayCard(card)
				var play_or_keep
				# TODO: delete this
				var test_string = ''
				if can_play:
					play_or_keep = await playOrKeep(card)
					if play_or_keep == 'Play':
						just_drew = true
						playCard(card.data)
						just_drew = false
						test_string += 'flump'

				if not can_play or play_or_keep == 'Keep':
					hand.append(card)
					addCardToHandUI(card)
					endTurn()
					test_string += 'doople'
				debug_print('This section should only ever say flump or doople. But never both: [%s]' % test_string)
			'receiveCurrentPlayerTurn': updateTurn(readable['data'] == Global.SteamManager.STEAM_ID)
			'receiveDiscardCardAndColor':
				setDiscardPile(readable['data']['card'])
				current_color = readable['data']['color']
			'receiveColor': current_color = readable['data']
			'receiveTurnDirection':
				turn_direction = readable['data']['turn_direction']
				turn_direction_sprite.flip_h = readable['data']['sprite_flip']
			'receiveExtraDrawCards':
				for card_data in readable['data']:
					var card = Global.dataToCard(card_data)
					hand.append(card)
					addCardToHandUI(card)
				setExtraCardCountLabel(0)
			'receiveExtraCardCount': setExtraCardCountLabel(readable['data'])
			'receiveLastAction': displayMessage(readable['data'])
			'receiveFinalTurnWarning': displayMessage('%s is on their final turn!' % readable['data'])
			'notifyFinalTurn': showFinalTurnDialog()
			'updatePlayerCardCount': updatePlayerCardCount(readable['data']['player_steam_id'], readable['data']['card_count'])
			'showWinner': showWinnerPopup(readable['data'])
			'resetGame': resetGame()


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
					# TODO: Is this retry logic a bad idea?
					if not send_response:
						Steam.sendP2PPacket(int(member['steam_id']), packet_data, send_type, channel)
	# Else send the packet to a particular user
	else:
		# Send this packet
		send_response = Steam.sendP2PPacket(target, packet_data, send_type, channel)
		if not send_response:
			Steam.sendP2PPacket(target, packet_data, send_type, channel)
	# The packets send response is...?
	#displayMessage('[STEAM] P2P packet sent successfully? %s' % str(send_response))








#####################################
######### BUTTON METHODS ############
#####################################


func _on_leave_game_button_pressed():
	pass # Replace with function body.


func _on_quit_game_button_pressed():
	pass # Replace with function body.


func _on_end_turn_button_pressed():
	endTurn()

func _on_toggle_play_log_button_pressed():
	togglePlayLogPanel()
