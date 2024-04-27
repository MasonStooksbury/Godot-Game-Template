extends Control

const CONFIG_FILENAME: String = 'settings.cfg'

@onready var master_volume_slider = $ScreenVBox/VolumeControlsVBox/MasterVolumeSlider
@onready var music_volume_slider = $ScreenVBox/VolumeControlsVBox/MusicVolumeSlider
@onready var ui_volume_slider = $ScreenVBox/VolumeControlsVBox/UIVolumeSlider
@onready var effects_volume_slider = $ScreenVBox/VolumeControlsVBox/EffectsVolumeSlider

var done_loading = false

func _ready() -> void:
	Global.SoundManager.master_volume_updated.connect(_master_volume_signal)
	Global.SoundManager.music_volume_updated.connect(_music_volume_signal)
	Global.SoundManager.effects_volume_updated.connect(_effects_volume_signal)
	Global.SoundManager.ui_volume_updated.connect(_ui_volume_signal)

	# I realize that technically we're loading the config twice, but it's necessary to make sure the sliders are set properly
	#	cuts down on coupled code if we do it this way.
	# This could also be solved by making ones Main Menu one scene instead of many
	Global.SoundManager.loadConfigData()
	done_loading = true


# These respond to signals from the config file being loaded
func _master_volume_signal(new_value):
	master_volume_slider.setSliderValue(new_value)

func _music_volume_signal(new_value):
	music_volume_slider.setSliderValue(new_value)

func _effects_volume_signal(new_value):
	effects_volume_slider.setSliderValue(new_value)

func _ui_volume_signal(new_value):
	ui_volume_slider.setSliderValue(new_value)



# This signal responds to UI changes to the slider
func _on_slider_value_changed(slider_name: String, new_value: float):
	if 'Master' in slider_name:
		Global.SoundManager.master_volume = new_value
		#playPreview('master')
	elif 'Music' in slider_name:
		Global.SoundManager.music_volume = new_value
		#playPreview('master')
	elif 'UI' in slider_name:
		Global.SoundManager.effects_volume = new_value
		playPreview('effects')
	elif 'Effects' in slider_name:
		Global.SoundManager.ui_volume = new_value
		playPreview('ui')


func playPreview(type: String) -> void:
	if not done_loading:
		return
	match type:
		'master':
			pass
		'music':
			pass
		'effects':
			Global.SoundManager.playSound('start_game')
		'ui':
			Global.SoundManager.playSound('select')



func _on_back_button_pressed():
	Global.SoundManager.playSound('select')
	Global.SoundManager.saveConfigData()
	Global.SignalManager.open_screen.emit('Title')


func _on_back_button_mouse_entered():
	Global.SoundManager.playSound('hover')
