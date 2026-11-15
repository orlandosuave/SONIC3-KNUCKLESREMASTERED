extends CharacterBody2D

@export var movement_speed: float = 250.0

func _physics_process(delta: float) -> void:
	var direction = 0
	if Input.is_action_pressed("ui_right"):
		direction = 1
	elif Input.is_action_pressed("ui_left"):
		direction = -1
	
	# Set velocity based on input and speed
	velocity = Vector2(direction * movement_speed, velocity.y)
	
	# Move and slide without arguments
	move_and_slide()
