extends Control

@onready var title_screen = $TitleScreen
@onready var game = $Game
@onready var multiplayer_screen = $MultiplayerScreen
@onready var settings_screen = $SettingsScreen
@onready var credits_screen = $CreditsScreen
@onready var camera = $Camera

@onready var screens = [title_screen, multiplayer_screen, settings_screen, credits_screen, game]

# Called when the node enters the scene tree for the first time.
func _ready():
	Global.SignalManager.open_screen.connect(openScreen)
	toggle_screen('~', true)



func _on_pressed():
	Global.SoundManager.playSound('select-button')

func _on_mouse_entered():
	Global.SoundManager.playSound('hover')

func toggle_screen(screen_name: String, toggle_title: bool = false) -> void:
	for screen in screens:
		screen.visible = screen_name in screen.name
	title_screen.visible = toggle_title
	camera.global_position = Global.SCREEN_CENTER


func openScreen(screen: String) -> void:
	if screen == 'Title':
		toggle_screen('~', true)
	else:
		toggle_screen(screen)


func _on_new_game_button_pressed():
	toggle_screen('Game')

func _on_multiplayer_button_pressed():
	Global.SignalManager.create_lobby.emit()
	toggle_screen('Multiplayer')

func _on_settings_button_pressed():
	toggle_screen('Settings')

func _on_credits_button_pressed():
	toggle_screen('Credits')

func _on_back_button_pressed():
	toggle_screen('~', true)



