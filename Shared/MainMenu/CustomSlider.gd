extends PanelContainer

@export var slider_name: String = 'EXAMPLE'
@export var slider_min: float = 0.0
@export var slider_max: float = 1.0
@export var slider_ticks: int = 11
@export var slider_step: float = 0.1

@onready var label = $MarginContainer/HBoxContainer/Label
@onready var slider = $MarginContainer/HBoxContainer/HSlider

signal slider_value_changed(slider_name: String, new_value: float)

# Called when the node enters the scene tree for the first time.
func _ready():
	label.set_text(slider_name if slider_name else 'EXAMPLE')
	slider.set_min(slider_min if slider_min else 0.0)
	slider.set_max(slider_max if slider_max else 1.0)
	slider.set_ticks(slider_ticks if slider_ticks else 11)
	slider.step = slider_step if slider_step else 0.1

func setSliderValue(new_value) -> void:
	slider.value = new_value

func _onSliderValueChanged(value: float) -> void:
	slider_value_changed.emit(slider_name, value)
