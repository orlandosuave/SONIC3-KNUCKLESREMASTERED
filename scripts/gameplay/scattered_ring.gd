extends CharacterBody2D

const GRAVITY := 337.5 # Obj_Bouncing_Ring: $18 / 256 * 60²
var player: PrototypePlayer
var age_frames := 0

func _ready() -> void:
	add_to_group("prototype_spill")
	collision_layer = 0
	collision_mask = 1
	add_collision_exception_with(player)
	var collider := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	collider.shape = circle
	add_child(collider)

func _physics_process(delta: float) -> void:
	age_frames += 1
	var hit := move_and_collide(velocity * delta)
	velocity.y += GRAVITY * delta
	if hit != null:
		var normal := hit.get_normal()
		if normal.y < -0.1 and velocity.y > 0.0:
			# ROM floor response reverses Y and retains 3/4 speed, preserving X.
			var raw_y := roundi(velocity.y * 256.0 / 60.0)
			velocity.y = -float(raw_y - (raw_y >> 2)) * 60.0 / 256.0
		else:
			velocity = velocity.bounce(normal) * 0.75
	if player.can_collect_rings() and global_position.distance_to(player.global_position + Vector2(0, -19)) < 24.0:
		player.rings += 1
		queue_free()
	if age_frames >= 255 or global_position.y > player.death_y:
		queue_free()

func _draw() -> void:
	draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 20, Color("ffd64a"), 3.0)
