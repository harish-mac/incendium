extends Node2D

@onready var soul1: AnimatedSprite2D = $AnimatedSprite2D
@onready var soul2: AnimatedSprite2D = $AnimatedSprite2D2
@onready var soul3: AnimatedSprite2D = $AnimatedSprite2D3

var previous_lives := 3
var waiting_for_fade := false


func _ready() -> void:
	soul1.play("default")
	soul2.play("default")
	soul3.play("default")

	previous_lives = Global.lives

	soul1.visible = Global.lives >= 1
	soul2.visible = Global.lives >= 2
	soul3.visible = Global.lives >= 3


func _process(_delta: float) -> void:

	# A life was lost
	if Global.lives < previous_lives:
		waiting_for_fade = true
		previous_lives = Global.lives

	# Wait until screen is completely black
	if waiting_for_fade:
		var fade = get_node_or_null("../Fade")

		if fade != null and fade.color.a >= 0.99:
			soul1.visible = Global.lives >= 1
			soul2.visible = Global.lives >= 2
			soul3.visible = Global.lives >= 3

			waiting_for_fade = false
