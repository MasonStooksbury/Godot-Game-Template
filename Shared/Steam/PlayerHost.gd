extends 'res://RegularPlayer.gd'


# Game management
var players
var num_players
var current_player_index = Global.WINNING_PLAYER_ID
var winning_player_id = Global.WINNING_PLAYER_ID

var deck_copy # Array of cards-as-data
var discard_pile = [] # Array of cards-as-data
var cards_to_draw = 0

var hand_size = 2


func _init():
	# Enable processing. Without this, our _process functions will not run
	set_process(true)
	randomize()

	# TODO: Unfortunately, I think I have to duplicate these assignments in order for it to work properly
	leave_game_button = $LeaveGameButton
	quit_game_button = $QuitGameButton
	midpoint = $HandMidpoint
	turn_direction_sprite = $TurnDirectionSprite
	extra_card_label = $CardsToDrawLabel/Label
	player_renderer = $PlayerRenderer
	play_card_confirmation = $PopupWindows/PlayCardConfirmation
	play_or_keep_selector = $PopupWindows/PlayOrKeepSelector
	special_card_selector = $PopupWindows/SpecialCardSelector
	color_selector = $PopupWindows/ColorSelector
	player_selector = $PopupWindows/PlayerSelector
	new_game_selector = $PopupWindows/NewGameSelector
	general_popup = $PopupWindows/GeneralPopup
	play_log_panel = $PlayLogPanel
	play_log_rich_text_label = $PlayLogPanel/RichTextLabel


	players = Global.LOBBY_MEMBERS
	num_players = players.size()

	# Get the viewport dimensions and set the hand midpoint to its final position
	# TODO: Make this more dynamic and change with screen size
	var viewport_dimensions = get_viewport().get_visible_rect().size
	midpoint.global_position = Vector2(viewport_dimensions.x/2, 1200)

	# Create discard pile card on UI
	super.createCard('discard', 'DiscardPile', discard_pile_position)

	# Create draw pile card on UI
	super.createCard('draw', 'DrawPile', draw_pile_position)

	initializeGame()

	handleFirstCard()

	super._ready()




#func _ready():
#	var viewport_dimensions = get_viewport().get_visible_rect().size
#	midpoint.global_position = Vector2(viewport_dimensions.x/2, 1200)
#
#	# Create discard pile card on UI
#	createCard(discard_pile_position)
#
#	# Create draw pile card on UI
#	createCard(draw_pile_position)




func _process(_delta):
	if Global.LOBBY_ID > 0:
		playerHostReadP2PPacket()



func initializeGame():
	turn_direction = 1
	turn_direction_sprite.flip_h = false
	toEveryone('receiveTurnDirection', {'sprite_flip': turn_direction_sprite.flip_h, 'turn_direction': turn_direction})
	# Create a deep copy of the main cards array, then shuffle it
	deck_copy = Global.deck.duplicate(true)
	deck_copy.shuffle()

	# Create player hands and send them
	for player in players:
		# Assign PlayerHost hand
		if player.steam_id == Global.PLAYERHOST_STEAM_ID:
			for i in range(hand_size):
				var card = Global.dataToCard(drawFromDrawPile())
				addCardToPlayerHostHand(card)
				super.addCardToHandUI(card)
			updateAllPlayerCardCounts(player.steam_id)
			continue
		var player_hand = []
		# Create player hand
		for i in range(hand_size):
			player_hand.append(drawFromDrawPile())

		# Send player their hand
		toSpecificPlayer(player.steam_id, 'receiveCards', player_hand)

		# Set our local version of that player's hand to their hand so we can keep track
		player.hand = player_hand.duplicate(true)
		updateAllPlayerCardCounts(player.steam_id)


	# Draw a card from the draw pile and discard it (face up) as the first card
	discardCard(drawFromDrawPile())
	toEveryone('receiveDiscardCardAndColor', {'card': Global.cardToData(top_of_discard_pile), 'color': current_color})

	# Tell everyone whose turn it is (effectively starting the game)
	# TODO: Do we want to keep this starting player index stuff?
	toEveryone('receiveCurrentPlayerTurn', players[0].steam_id)
	updateTurn(players[0].steam_id == Global.PLAYERHOST_STEAM_ID)

	# TODO: DELETE THIS
	modifyGame()



func modifyGame():
	players[getPlayerIndexBySteamID(Global.STEAM_ID)].hand.append(Global.dataToCard('ZW'))
	addCardToHandUI(Global.dataToCard('ZW'))


func handleFirstCard():
	var message_to_display = 'The first card was a '

	match top_of_discard_pile.value:
		# If O or A, do nothing
		'O', 'A':
			return
		# If T or F, add cards to draw
		'T':
			drawTwo()
			message_to_display += 'Draw 2! Play a special card to avoid having to draw %s cards!' % cards_to_draw
		'F':
			drawFour()
			message_to_display += 'Draw 4! Play a special card to avoid having to draw %s cards!' % cards_to_draw
		# If R, change direction
		'R':
			changeDirection()
			var update_message = 'The direction has been reversed on the first turn!'
			toEveryone('receiveLastAction', update_message)
			message_to_display += 'Reverse!'
		# If S, skip current player
		'S':
			nextPlayer()
			var update_message = '%s was skipped on the first turn!' % players[current_player_index].steam_name
			toEveryone('receiveLastAction', update_message)
			message_to_display += 'Skip! ' + update_message

			# Tell everyone whose turn it is
			toEveryone('receiveCurrentPlayerTurn', players[current_player_index].steam_id)

			# Update my play state based on whether or not it's my turn
			updateTurn(players[current_player_index].steam_id == Global.PLAYERHOST_STEAM_ID)
		# If W, current player chooses color, then takes turn
		'W':
			disableHand()
			var new_color = await super.chooseNewColor()
			toEveryone('receiveColor', new_color)
			var update_message = 'The color is now: %s' % Global.COLOR_DICT[new_color]
			toEveryone('receiveLastAction', update_message)
			message_to_display += 'Wild! ' + update_message
			enableHand()
		_:
			message_to_display += top_of_discard_pile.data + '!'
	displayMessage(message_to_display)


#####################################
##### USER DEFINED FUNCTIONS ########
#####################################

func playerHostReadP2PPacket() -> void:
	var packet_size: int = Steam.getAvailableP2PPacketSize(0)
	# There is a packet
	if packet_size > 0:
		super.debug_print('[STEAM] There is a packet available.')
		# Get the packet
		var packet: Dictionary = Steam.readP2PPacket(packet_size, 0)
		# If it is empty, set a warning
		if packet.is_empty():
			super.debug_print('[WARNING] Read an empty packet with non-zero size!')
		# Get the remote user's ID
		var player_steam_id: String = str(packet['steam_id_remote'])
		var packet_code: PackedByteArray = packet['data']
		# Make the packet data readable
		var readable: Dictionary = bytes_to_var(packet_code)
		# Print the packet to output
		#super.displayMessage('[STEAM] Packet from %s: %s' % [str(packet_sender), str(readable)])
		# Append logic here to deal with packet data
		super.debug_print(readable)
		match readable['type']:
			'fromPlayer':
				var action = readable['data']['action']
				#var player_steam_id = readable['data']['steam_id']

				if action == 'playCard':
					super.debug_print(readable['data']['card'])
					var special_card = readable['data']['card']['special_card']
					var hand_card = readable['data']['card']['hand_card_data']
					var skip_distance = readable['data']['card']['skip_distance']

					handleCardFromPlayer(player_steam_id, special_card, hand_card, skip_distance)
					handleAndSendLastAction(player_steam_id, special_card, hand_card)
					updateAllPlayerCardCounts(player_steam_id)

				elif action == 'endTurn':
					#super.displayMessage('Player ended their turn!')
					if cards_to_draw > 0:
						assignCardsToDraw(player_steam_id)
					nextPlayer()
					var update_message = '%s drew a card' % players[getPlayerIndexBySteamID(player_steam_id)].steam_name
					toEveryone('receiveLastAction', update_message)
					toEveryone('receiveCurrentPlayerTurn', players[current_player_index].steam_id)
					displayMessage(update_message)
					updateAllPlayerCardCounts(player_steam_id)
					updateTurn(players[current_player_index].steam_id == Global.PLAYERHOST_STEAM_ID)

				elif action == 'drawCard':
					var drawn_card = drawFromDrawPile()
					toSpecificPlayer(player_steam_id, 'receiveDrawCard', drawn_card)
					addCardToPlayerHand(player_steam_id, drawn_card)

				if players[getPlayerIndexBySteamID(player_steam_id)].hand.size() == 0:
					players[getPlayerIndexBySteamID(player_steam_id)].is_final_turn = true
					toSpecificPlayer(player_steam_id, 'notifyFinalTurn', '')
					toEveryone('receiveFinalTurnWarning', players[getPlayerIndexBySteamID(player_steam_id)].steam_name)
					# TODO: Remove this in favor of a different method
					displayMessage('%s is on their final turn!' % players[getPlayerIndexBySteamID(player_steam_id)].steam_name)




func handleAndSendLastAction(player_steam_id, special_card, hand_card):
	var player_name = players[getPlayerIndexBySteamID(player_steam_id)].steam_name
	var message_string = '%s played a' % player_name

	if special_card != null:
		if hand_card[1] == 'A':
			message_string += ' Blank and chose a'
		match special_card.card_type:
			'T':
				message_string += ' Draw 2! Play a special card to avoid having to draw %s cards!' % cards_to_draw
			'F':
				message_string += ' Draw 4! Play a special card to avoid having to draw %s cards!' % cards_to_draw
			'R':
				message_string += ' Reverse!'
			'S':
				message_string += ' Skip!'
			'W':
				message_string += ' Wild. New color is: %s!' % Global.COLOR_DICT[special_card.new_color]
			'O':
				message_string += 'n Omnidirectional NO-U and passed to %s!' % players[getPlayerIndexBySteamID(special_card.chosen_player)].steam_name
		if special_card.new_color != 'Z':
			message_string += '\nThe color is %s' % Global.COLOR_DICT[special_card.new_color]
	else:
		message_string += ' %s %s' % [Global.COLOR_DICT[hand_card[0]], hand_card[1]]

	toEveryone('receiveLastAction', message_string)
	super.displayMessage(message_string)







func handleCardFromPlayer(player_steam_id, special_card, hand_card, skip_distance):
	# TODO: Do I need this?
	var previous_top_of_discard = top_of_discard_pile
	super.setDiscardPile(hand_card)
	removeCardFromPlayerHand(player_steam_id, hand_card)
	toEveryone('receiveDiscardCardAndColor', {'card': Global.cardToData(top_of_discard_pile), 'color': special_card.new_color if special_card != null else hand_card[0]})
	current_color = special_card.new_color if special_card != null else hand_card[0]

	# If the player played a reverse, change the turn direction
	if (special_card != null and special_card.card_type == 'R') or hand_card[1] == 'R':
		changeDirection()

	# Assign or add any cards from the Draw2 and Draw4s
	handleExtraDrawCards(special_card, hand_card, player_steam_id)

	# If the player played an Omnidirectional NO-U, set the current_player_index to that player
	# Otherwise, play as normal
	if (special_card != null and special_card.card_type == 'O') or hand_card[1] == 'O':
		current_player_index = getPlayerIndexBySteamID(special_card.chosen_player)
		checkIfPlayerHasWon()
	else:
		nextPlayer(skip_distance)

	if cards_to_draw > 0 and players[current_player_index].is_final_turn:
		assignCardsToDraw(null if players[current_player_index].steam_id == Global.PLAYERHOST_STEAM_ID else players[current_player_index].steam_id)
		players[current_player_index].is_final_turn = false

	# Tell everyone whose turn it is
	toEveryone('receiveCurrentPlayerTurn', players[current_player_index].steam_id)

	# Update my play state based on whether or not it's my turn
	updateTurn(players[current_player_index].steam_id == Global.PLAYERHOST_STEAM_ID)



func handleExtraDrawCards(special_card, hand_card, player_steam_id):
	var card_type = special_card.card_type if special_card != null else hand_card[1]

	# If the player played a card that isn't R, S, O, T, or F, assign them more cards
	var options = ['T', 'F', 'R', 'S', 'O', 'A']
	super.debug_print('cards: %s' % cards_to_draw)
	if cards_to_draw > 0 and (card_type not in options or hand_card[1] not in options):
		super.debug_print('TIME TO DRAW')
		# Assign cards to draw
		assignCardsToDraw(player_steam_id)
	# If the player played a Draw2 or Draw4 card, increment the counter
	var other_options = ['T', 'F']
	if card_type in other_options or hand_card[1] in other_options:
		if card_type == 'F' or hand_card[1] == 'F':
			drawFour()
		else:
			drawTwo()


func assignCardsToDraw(player_steam_id):
	if player_steam_id != Global.PLAYERHOST_STEAM_ID:
		var extra_cards = []
		for i in range(cards_to_draw):
			var data = drawFromDrawPile()
			addCardToPlayerHand(player_steam_id, data)
			extra_cards.append(data)
		toSpecificPlayer(player_steam_id, 'receiveExtraDrawCards', extra_cards)
	else:
		for i in range(cards_to_draw):
			var card = Global.dataToCard(drawFromDrawPile())
			addCardToPlayerHostHand(card)
			super.addCardToHandUI(card)
	clearCardsToDraw()



func changeDirection():
	super.debug_print('in change direction')
	turn_direction *= -1
	super.debug_print(turn_direction)
	var sprite_flip = abs(turn_direction) != turn_direction
	super.debug_print(sprite_flip)
	turn_direction_sprite.flip_h = sprite_flip
	toEveryone('receiveTurnDirection', {'sprite_flip': sprite_flip, 'turn_direction': turn_direction})


func drawTwo():
	cards_to_draw += 2
	updateExtraCardCount()


func drawFour():
	cards_to_draw += 4
	updateExtraCardCount()


func clearCardsToDraw():
	cards_to_draw = 0
	updateExtraCardCount()


func updateExtraCardCount():
	toEveryone('receiveExtraCardCount', cards_to_draw)
	setExtraCardCountLabel(cards_to_draw)


func nextPlayer(place_amount=1):
	if players.size() == 2:
		if place_amount == 2:
			current_player_index = 0 if current_player_index == 0 else 1
		else:
			current_player_index = 0 if current_player_index == 1 else 1
		checkIfPlayerHasWon()
		return

	var new_player_index = current_player_index + (turn_direction * place_amount)

	var remainder = abs(new_player_index) % num_players

	if new_player_index < 0:
		current_player_index = num_players - remainder
	else:
		current_player_index = remainder

	checkIfPlayerHasWon()


func checkIfPlayerHasWon():
	var current_player = players[current_player_index]
	var hand_to_check = current_player.hand
	super.debug_print('check if won')
	super.debug_print(current_player.is_final_turn and hand_to_check.size() == 0 and cards_to_draw == 0)
	super.debug_print(current_player.is_final_turn)
	super.debug_print(hand_to_check.size() == 0)
	super.debug_print(cards_to_draw == 0)
	if current_player.is_final_turn and hand_to_check.size() == 0 and cards_to_draw == 0:
		endGame()


func drawCard():
	if not is_turn:
		return
	var card = Global.dataToCard(drawFromDrawPile())

	# TODO: If this logic is the same as the player, we need to put it somewhere
	displayMessage("You've been dealt a %s!" % card.data)
	var can_play = super.canPlayCard(card)
	var play_or_keep
	# TODO: delete this
	var test_string = ''
	if can_play:
		play_or_keep = await super.playOrKeep(card)
		if play_or_keep == 'Play':
			just_drew = true
			playCard(card.data)
			just_drew = false
			test_string += 'flump'

	if not can_play or play_or_keep == 'Keep':
		addCardToPlayerHostHand(card)
		super.addCardToHandUI(card)
		if cards_to_draw > 0:
			assignCardsToDraw(Global.PLAYERHOST_STEAM_ID)
		playerHostEndTurn()
		test_string += 'doople'
	super.debug_print('This section should only ever say flump or doople. But never both: [%s]' % test_string)
	updateAllPlayerCardCounts(Global.PLAYERHOST_STEAM_ID)

	var message_string = '%s drew a card' % Global.STEAM_NAME
	toEveryone('receiveLastAction', message_string)
	super.displayMessage(message_string)



func drawFromDrawPile():
	var drawn_card = deck_copy.pop_front()

	if deck_copy.size() == 0:
		shuffleDiscardAndReplenishDeck()
	return drawn_card



func playCard(data):
	if not is_turn:
		return

	# var card_object = {'card_type': '', 'new_color': ''}
	var card_object = {'special_card': null, 'hand_card_data': data, 'skip_distance': 2}
	if Global.dataToCard(data).is_special:
		#card_object = await handleSpecialCard(data)
		card_object['special_card'] = await super.handleSpecialCard(data)

	if not just_drew:
		var play_decision = await super.playCardConfirmation(data)
		if play_decision == 'No':
			super.enableHand()
			return

	removeCardFromPlayerHostHand(data)
	super.removeCardFromHandUI(data)



	var skip_distance = 2
	# TODO: Any way to do this card_object thing any better?
	if (data[1] == 'S' or (card_object.special_card != null and card_object.special_card.card_type == 'S')) and top_of_discard_pile.is_special:
		skip_distance = 1
	card_object.skip_distance = skip_distance if data[1] == 'S' or (card_object.special_card != null and card_object.special_card.card_type == 'S') else 1


	# TODO: Original code
#	var skip_distance = 2
#	# TODO: Any way to make card_object better?
#	if (data[1] == 'S' or (card_object.card_type != '' and card_object.card_type == 'S')) and top_of_discard_pile.is_special:
#		super.debug_print('setting skip to 1')
#		skip_distance = 1
#	# TODO: Make this cleaner (variable for skip card, maybe?
#	var do_this = skip_distance if data[1] == 'S' or (card_object.card_type != '' and card_object.card_type == 'S') else 1
#	super.debug_print('skip: %s' % do_this)





	if data[1] == 'R' or (card_object.special_card != null and card_object.special_card.card_type == 'R'):
		changeDirection()
	# TODO: handleExtraDrawCard logic
	handleExtraDrawCards(card_object.special_card, data, Global.PLAYERHOST_STEAM_ID)


	# If played an Omnidirectional NO-U, set the current_player_index to that player
	# Otherwise, play as normal
	if (card_object.special_card != null and card_object.special_card.card_type == 'O') or data[1] == 'O':
		current_player_index = getPlayerIndexBySteamID(card_object.special_card.chosen_player)
		checkIfPlayerHasWon()
	else:
		nextPlayer(card_object.skip_distance)



	# We need to do this afterward because the previous check relies on checking the previous discard card (not mine)
	discardCard(data)
	toEveryone('receiveDiscardCardAndColor', {'card': Global.cardToData(top_of_discard_pile), 'color': card_object.special_card.new_color if card_object.special_card != null else data[0]})


	handleAndSendLastAction(Global.PLAYERHOST_STEAM_ID, card_object.special_card, data)

	# TODO: Do I need to tell everyone that a player was skipped?
	updateAllPlayerCardCounts(Global.PLAYERHOST_STEAM_ID)
	toEveryone('receiveCurrentPlayerTurn', players[current_player_index].steam_id)
	updateTurn(true if players[current_player_index].steam_id == Global.PLAYERHOST_STEAM_ID else false)

	if players[getPlayerIndexBySteamID(Global.PLAYERHOST_STEAM_ID)].hand.size() == 0:
		players[getPlayerIndexBySteamID(Global.PLAYERHOST_STEAM_ID)].is_final_turn = true
		toEveryone('receiveFinalTurnWarning', Global.STEAM_NAME)
		displayMessage('This is your final turn!')





func discardCard(data):
	top_of_discard_pile = Global.dataToCard(data)
	discard_pile.append(data)
	current_color = data[0]
	get_node('DiscardPile').setData(data)


func shuffleDiscardAndReplenishDeck():
	deck_copy = discard_pile.duplicate(true)
	deck_copy.shuffle()
	discard_pile.clear()



func addCardToPlayerHand(player_steam_id, data):
	players[getPlayerIndexBySteamID(player_steam_id)].hand.append(data)


func removeCardFromPlayerHand(player_steam_id, data):
	players[getPlayerIndexBySteamID(player_steam_id)].hand.erase(data)


# Different from addCardToPlayerHand() in that it adds a card instead of data
func addCardToPlayerHostHand(card):
	players[getPlayerIndexBySteamID(Global.PLAYERHOST_STEAM_ID)].hand.append(card)


func removeCardFromPlayerHostHand(data):
	var count = 0
	var playerhost = players[getPlayerIndexBySteamID(Global.PLAYERHOST_STEAM_ID)]
	for card in playerhost.hand:
		if card.data == data:
			playerhost.hand.remove_at(count)
			return
		count += 1


func playerHostEndTurn():
	updateTurn(false)
	nextPlayer()
	toEveryone('receiveCurrentPlayerTurn', players[current_player_index].steam_id)


func updateTurn(update):
	is_turn = update
	if is_turn:
		#super.displayMessage("It's my turn!!!")
		super.disableHand()
		general_popup.showWindow("It's my turn!")
		await general_popup.clicked_confirm
		super.enableHand()
		super.modifyHandVisibility()
	else:
		super.debug_print('not my turn')
		super.disableHand()


func getPlayerIndexBySteamName(player_steam_name):
	var count = 0
	for player in players:
		if player.steam_name == player_steam_name:
			return count
		count += 1


func getPlayerIndexBySteamID(player_steam_id):
	var count = 0
	for player in players:
		if str(player.steam_id) == str(player_steam_id):
			return count
		count += 1


func endGame():
	super.debug_print('THERE WAS A WINNER')
	super.debug_print(players[current_player_index].steam_name)
	# Tell everyone who won
	var win_message = '%s wins!' % players[current_player_index].steam_name
	toEveryone('showWinner', win_message)
	# Prompt PlayerHost to start new game
	new_game_selector.showWindow(win_message)
	await new_game_selector.option_selected

	if new_game_selector.getSelection() == 'NewGame':
		# If yes, reset game and inform players
		toEveryone('resetGame', '')
		resetGame()
	else:
		# If no, leave somehow?
		pass


func resetGame():
	super.hideWinnerPopup()
	super.clearDisplayMessageWindow()
	current_player_index = 0
	# Reset all player hands and is_final_turn booleans
	for player in players:
		player.hand = []
		player.is_final_turn = false
	# Clear my UI hand
	super.clearHandUI()
	discard_pile = []
	clearCardsToDraw()
	initializeGame()



func updateAllPlayerCardCounts(player_steam_id):
	var relevant_player_card_count = players[getPlayerIndexBySteamID(player_steam_id)].hand.size()
	toEveryone('updatePlayerCardCount', {'player_steam_id': player_steam_id, 'card_count': relevant_player_card_count})
	super.updatePlayerCardCount(player_steam_id, relevant_player_card_count)






#####################################
######## NETWORKING METHODS #########
#####################################

func toEveryone(type, data):
	super.sendP2PPacket(0, {'type': type, 'data': data})

func toSpecificPlayer(player_steam_id, type, data):
	super.sendP2PPacket(int(player_steam_id), {'type': type, 'data': data})







#####################################
######### BUTTON METHODS ############
#####################################

func _on_leave_game_button_pressed():
	pass # Replace with function body.


func _on_quit_game_button_pressed():
	pass # Replace with function body.


func _on_end_turn_button_pressed():
	playerHostEndTurn()

func _on_toggle_play_log_button_pressed():
	super.togglePlayLogPanel()
