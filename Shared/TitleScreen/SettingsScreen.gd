extends Control

const CONFIG_FILENAME: String = 'settings.cfg'

@onready var master_volume_slider = $VolumeControlsVBox/MasterVolumeHBox/MasterVolumeSlider
@onready var music_volume_slider = $VolumeControlsVBox/MusicVolumeHBox/MusicVolumeSlider
@onready var effects_volume_slider = $VolumeControlsVBox/EffectsVolumeHBox/EffectsVolumeSlider
@onready var ui_volume_slider = $VolumeControlsVBox/UIVolumeHBox/UIVolumeSlider

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
	master_volume_slider.value = new_value

func _music_volume_signal(new_value):
	music_volume_slider.value = new_value

func _effects_volume_signal(new_value):
	effects_volume_slider.value = new_value

func _ui_volume_signal(new_value):
	ui_volume_slider.value = new_value



# These signals respond to UI changes to the slider values
func _on_master_volume_slider_value_changed(value):
	Global.SoundManager.master_volume = value


func _on_music_volume_slider_value_changed(value):
	Global.SoundManager.music_volume = value


func _on_effects_volume_slider_value_changed(value):
	Global.SoundManager.effects_volume = value
	playPreview('effects')

func _on_ui_volume_slider_value_changed(value):
	Global.SoundManager.ui_volume = value
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
	get_tree().change_scene_to_packed(Global.TITLE_SCREEN_SCENE)
