extends CanvasLayer

@onready var fade: ColorRect = $Fade
@onready var timer_label: Label = $TimerLabel

func _ready() -> void:
	fade.color.a = 0.0

func _process(_delta: float) -> void:
	# Convert the raw seconds into a clean MM:SS format
	var minutes := int(Global.time_left) / 60
	var seconds := int(Global.time_left) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]
