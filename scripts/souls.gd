extends Node2D

## Horizontal gap between flames (pixels)
@export var spacing: float = 26.0

var _flames: Array[AnimatedSprite2D] = []


func _ready() -> void:
	# Reuse the 3 flames already in souls.tscn, then clone more up to 9
	for child in get_children():
		if child is AnimatedSprite2D:
			_flames.append(child)

	var template: AnimatedSprite2D = _flames[0]
	while _flames.size() < Global.MAX_LIVES:
		var clone := template.duplicate() as AnimatedSprite2D
		add_child(clone)
		_flames.append(clone)

	# Line them up and desync the animations so they flicker naturally
	for i in _flames.size():
		var f := _flames[i]
		f.position.x = i * spacing
		f.play("default")
		f.frame_progress = randf()


func _process(_delta: float) -> void:
	# One flame per remaining life; they go out from the right
	for i in _flames.size():
		_flames[i].visible = i < Global.lives
