extends Control

@onready var title_screen = $TitleScreen
@onready var single_player_screen = $SingleplayerScreen
@onready var multiplayer_screen = $MultiplayerScreen
@onready var settings_screen = $SettingsScreen
@onready var credits_screen = $CreditsScreen
@onready var game = $Game

@onready var screens = [title_screen, single_player_screen, multiplayer_screen, settings_screen, credits_screen, game]

# Called when the node enters the scene tree for the first time.
func _ready():
	Global.SignalManager.open_screen.connect(toggle_screen)
	toggle_screen('Title')


func toggle_screen(screen_name: String) -> void:
	for screen in screens:
		screen.visible = screen_name in screen.name




func _on_pressed():
	Global.SoundManager.playSound('select-button')

func _on_mouse_entered():
	Global.SoundManager.playSound('hover')

func _on_singleplayer_button_pressed():
	toggle_screen('Singleplayer')

func _on_multiplayer_button_pressed():
	Global.SignalManager.create_lobby.emit()
	toggle_screen('Multiplayer')

func _on_settings_button_pressed():
	toggle_screen('Settings')

func _on_credits_button_pressed():
	toggle_screen('Credits')

func _on_back_button_pressed():
	toggle_screen('Title')

func _on_quit_button_pressed():
	get_tree().quit()
