extends Node


# Main Menu
signal open_screen(screen_name: String)


# Multiplayer Lobby Signals
signal kick_button_pressed(player_steam_id: String)
signal kicked_from_lobby
signal create_lobby # TODO: Do I need this?
signal created_lobby
signal player_joined_lobby(player_steam_id: String)
signal player_disconnected(player_steam_id: String)
signal leave_lobby_button_pressed
signal start_game_button_pressed
signal start_game
signal ready_button_pressed
signal handle_ready_up
signal handle_unready
signal check_max_lobby_members_reached
signal reorganize_and_render
signal display_message
signal check_lobby_ready_status
signal read_p2p_packet(player_steam_id: String, readable: Dictionary)
