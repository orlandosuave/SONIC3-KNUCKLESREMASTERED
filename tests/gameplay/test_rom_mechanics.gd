extends SceneTree

const Player = preload("res://scripts/gameplay/player_controller.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for action in ["move_left", "move_right", "roll", "jump"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	var world := Node2D.new()
	root.add_child(world)
	var player := Player.new()
	world.add_child(player)
	player.set_physics_process(false)
	player.death_y = 10000
	check(Engine.physics_ticks_per_second == 60, "Simulation stays at 60 Hz")
	check(is_equal_approx(player._rom_peak_drag(60), 58.125), "Positive $100 drag subtracts $8")
	check(is_equal_approx(player._rom_peak_drag(-60.234375), -58.125), "Negative signed shift rounds down")
	check(player._apply_air_direction(600, 1, 1.0/60) == 600, "Air input retains overspeed")
	check(player._apply_air_direction(-600, -1, 1.0/60) == -600, "Left air overspeed retained")
	check(player._apply_ground_brake(10, -1, 1.0/60) == -30, "Ground braking reverses through zero")
	check(player._landing_ground_speed(Vector2(120, 300), 0) == 120, "Flat landing retains X")
	check(player._landing_ground_speed(Vector2(120, 300), PI/6) == 150, "Moderate landing converts half Y")
	check(player._landing_ground_speed(Vector2(120, 1200), -PI/3) == -945, "Steep landing caps and signs Y")
	player.ground_angle = PI/4
	player.ground_speed = 200
	player._apply_slope_repel(1.0/60)
	check(player.slope_move_lock == 0, "No steep slope lock above $280")
	player.ground_speed = 100
	player._apply_slope_repel(1.0/60)
	check(player.slope_move_lock == 30 and player.ground_speed == 130, "Slow steep slope push and lock")
	player.slope_move_lock = 0
	player.ducking = true
	player._update_collision_pose()
	check(player.capsule_shape.height == 38, "Duck retains standing collision size")
	player.ducking = false
	player.rolling = true
	player.roll_jumping = true
	player._update_collision_pose()
	check(player.capsule_shape.height == 38, "Roll jump restores standing collision size")
	player.roll_jumping = false
	player.rolling = false
	for y in [-300.0, -120.0, 0.0, 120.0, 1000.0]:
		player.position = Vector2(0, -500)
		player.airborne = true
		player.jumping = false
		player.velocity = Vector2(60, y)
		player._physics_process(1.0/60)
		var expected_x := 58.125 if y == -120.0 else 60.0
		check(is_equal_approx(player.velocity.x, expected_x), "Air drag range Y=%s" % y)
		check(is_equal_approx(player.velocity.y, y+13.125), "Air gravity has no invented fall cap")
	player.jumping = true
	player.velocity = Vector2(0, -390)
	player._physics_process(1.0/60)
	check(player.velocity.y == -226.875, "Unheld jump caps upward speed before gravity")
	player.jumping = false
	player.ground_angle = 0
	player.spindash_charging = true
	player.spindash_charge = 512
	player.facing = 1
	Input.action_press("move_left")
	player._physics_process(1.0/60)
	Input.action_release("move_left")
	check(player.spindash_charge == 512 and player.facing == 1 and player.velocity.x == 540, "Release preserves charge and facing")
	var floor_body := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(2000, 100)
	collider.shape = shape
	floor_body.position = Vector2(0, 550)
	floor_body.add_child(collider)
	world.add_child(floor_body)
	player.position = Vector2(0, 490)
	player.velocity = Vector2.ZERO
	player.ground_speed = 0
	player.rolling = false
	player.set_physics_process(true)
	for i in 30:
		await physics_frame
		await process_frame
	player.set_physics_process(false)
	check(not player.airborne, "Player settled on real floor")
	var before := player.position
	Input.action_press("jump")
	player._physics_process(1.0/60)
	check(player.jumping and player.velocity.y == -390, "Jump applies full $680 impulse")
	check(player.position == before, "Takeoff skips ground dispatch movement")
	check(player.capsule_shape.height == 28, "Normal jump uses compact collision size")
	player.set_physics_process(true)
	var peak := player.position.y
	for i in 120:
		await physics_frame
		await process_frame
		peak = minf(peak, player.position.y)
		if not player.jumping and not player.airborne: break
	player.set_physics_process(false)
	check(before.y - peak > 90 and before.y - peak < 105, "Held jump follows expected normal gravity arc")
	check(not player.jumping and not player.airborne and not player.rolling, "Normal jump lands and exits ball state")
	Input.action_release("jump")
	player.position = Vector2(0, 500)
	player.airborne = false
	player.jumping = false
	player.rolling = false
	player.velocity = Vector2.ZERO
	player._update_collision_pose()
	var ceiling := StaticBody2D.new()
	var roof_collider := CollisionShape2D.new()
	var roof_shape := RectangleShape2D.new()
	roof_shape.size = Vector2(200, 20)
	roof_collider.shape = roof_shape
	ceiling.position = Vector2(0, 449)
	ceiling.add_child(roof_collider)
	world.add_child(ceiling)
	await physics_frame
	await process_frame
	check(not player._has_jump_clearance(), "Less than six pixels overhead blocks jump")
	world.queue_free()
	print("ROM mechanics regression: %d failures" % failures)
	quit(1 if failures else 0)
