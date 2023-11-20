extends Control

signal send_message_button_pressed

@onready var chat_label_text = $MarginContainer/VBoxContainer/ChatPanelLabel


func _on_send_message_button_pressed() -> void:
	#emit_signal('send_message_button_pressed')
	pass


func setLabelText(new_text: String) -> void:
	chat_label_text.set_text(new_text)
