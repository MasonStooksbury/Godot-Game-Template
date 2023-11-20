extends AudioStreamPlayer

var offset = 0


func play_sound(bus, sound_stream, volume) -> void:
	set_stream(sound_stream)
	set_volume_db(volume)
	set_bus(Global.SoundManager.AudioBusChannels.keys()[bus])
	play(0)


func _on_finished():
	queue_free()
