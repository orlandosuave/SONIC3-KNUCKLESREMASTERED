extends CharacterBody2D

@export var movement_speed: float = 250.0

func _physics_process(delta):
    var direction = Input.get_axis("ui_left", "ui_right")
    velocity.x = direction * movement_speed
    move_and_slide()
