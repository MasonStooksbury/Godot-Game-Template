extends Node

# SoundManager signals
signal master_volume_updated(new_value)
signal music_volume_updated(new_value)
signal effects_volume_updated(new_value)
signal ui_volume_updated(new_value)

# Make sure that these are in the exact order as they appear under the Audio tab
enum AudioBusChannels {Master, Music, Effects, UI}

const SETTINGS_CONFIG_FILENAME = 'settings.cfg'

# SOUNDS
var sound_node = preload("res://Shared/Global/Sound.tscn")



var master_volume = 1.0:
	set(value):
		if (master_volume != value):
			master_volume = value
			setBusVolume(AudioBusChannels.Master, master_volume)

var music_volume = 1.0:
	set(value):
		if (music_volume != value):
			music_volume = value
			setBusVolume(AudioBusChannels.Music, music_volume)

var effects_volume = 1.0:
	set(value):
		if (effects_volume != value):
			effects_volume = value
			setBusVolume(AudioBusChannels.Effects, effects_volume)

var ui_volume = 1.0:
	set(value):
		if (ui_volume != value):
			ui_volume = value
			setBusVolume(AudioBusChannels.UI, ui_volume)


func _ready() -> void:
	loadConfigData()


func playSound(sound: String) -> void:
	var audio: AudioStream
	var volume: float = 0.0
	var bus = Global.SoundManager.AudioBusChannels.UI
	match sound:
		'start_game':
#			audio = ''
			volume = 0.5
			bus = Global.SoundManager.AudioBusChannels.Effects
	var sound_obj = sound_node.instantiate()
	self.add_child(sound_obj)
	sound_obj.play_sound(bus, audio, volume)


func loadConfigData() -> void:
	var settings_file = ConfigFile.new()

	var status = settings_file.load('user://%s' % SETTINGS_CONFIG_FILENAME)

	if status == OK:
		master_volume = settings_file.get_value('Settings', 'master_volume')
		music_volume = settings_file.get_value('Settings', 'music_volume')
		effects_volume = settings_file.get_value('Settings', 'effects_volume')
		ui_volume = settings_file.get_value('Settings', 'ui_volume')

		master_volume_updated.emit(master_volume)
		music_volume_updated.emit(music_volume)
		effects_volume_updated.emit(effects_volume)
		ui_volume_updated.emit(ui_volume)


func saveConfigData() -> void:
	var settings_file = ConfigFile.new()

	settings_file.set_value('Settings', 'master_volume', master_volume)
	settings_file.set_value('Settings', 'music_volume', music_volume)
	settings_file.set_value('Settings', 'effects_volume', effects_volume)
	settings_file.set_value('Settings', 'ui_volume', ui_volume)
	settings_file.save('user://%s' % SETTINGS_CONFIG_FILENAME)


func setBusVolume(bus, value) -> void:
	var low_end = -50.0
	var volume_db = low_end - (low_end * value)
	AudioServer.set_bus_volume_db(bus, volume_db)
