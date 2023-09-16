extends AudioStreamPlayer

var offset = 0


func play_sound(sound_stream, volume=0.0):
	set_stream(sound_stream)
	self.set_volume_db(volume)
	play(offset)


func _on_finished():
	queue_free()
