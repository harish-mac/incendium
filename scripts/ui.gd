extends CanvasLayer

@onready var fade: ColorRect = $Fade

func _ready() -> void:
	fade.color.a = 0.0
