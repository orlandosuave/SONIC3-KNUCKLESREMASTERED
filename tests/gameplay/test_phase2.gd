extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var room = load("res://scenes/movement_prototype.tscn").instantiate()
	root.add_child(room)
	var player = room.player
	player.set_physics_process(false)
	player.rings = 40
	player.take_damage(player.position.x + 20)
	check(player.velocity == Vector2(-120, -240), "Hurt knockback away from right hazard")
	check(player.rings == 0 and player.hurt, "Damage enters hurt and removes all rings")
	check(not player.can_collect_rings(), "Hurt cannot collect rings")
	await process_frame
	var spills := 0
	for child in room.get_children():
		if child.get_script() == load("res://scripts/gameplay/scattered_ring.gd"):
			spills += 1
			child.queue_free()
	check(spills == 32, "Scatter capped at 32")
	player.hurt = false
	player.invulnerability_frames = 90
	check(not player.can_collect_rings(), "90 frames blocks pickup")
	player.invulnerability_frames = 89
	check(player.can_collect_rings(), "89 frames permits pickup")
	player.invulnerability_frames = 0
	player.take_damage(player.position.x - 20)
	check(player.dying and player.velocity == Vector2(0, -420), "Zero rings launches death")
	player.reset_to_checkpoint()
	player.position = Vector2(100, 520)
	player.rings = 1
	player.take_damage(120)
	player.set_physics_process(true)
	Input.action_press("move_right")
	await physics_frame
	await process_frame
	check(player.velocity.x == -120.0, "Hurt ignores steering")
	Input.action_release("move_right")
	for frame in 90:
		await physics_frame
		await process_frame
		if not player.hurt: break
	check(not player.hurt and not player.airborne, "Hurt lands")
	check(player.invulnerability_frames == 120, "Landing starts 120-frame immunity")
	player.begin_death()
	for frame in 240:
		await physics_frame
		await process_frame
		if not player.dying: break
	check(not player.dying and player.rings == 0, "Death returns to checkpoint without rings")
	check(player.position.is_equal_approx(player.checkpoint_position), "Checkpoint location restored")
	player.set_physics_process(false)
	player.position = Vector2(2300, 100)
	var ring_script = load("res://scripts/gameplay/scattered_ring.gd")
	var rings: Array = []
	for x in [100.0, 350.0, 750.0]:
		var ring = ring_script.new()
		ring.player = player
		ring.position = Vector2(x, 380)
		ring.velocity = Vector2(0, 180)
		room.add_child(ring)
		rings.append(ring)
	var bounced := [false, false, false]
	for frame in 255:
		await physics_frame
		await process_frame
		for i in rings.size():
			var ring = rings[i]
			if not is_instance_valid(ring): continue
			var floor_y: float = 520.0 if i == 0 else 480.0
			check(ring.position.y <= floor_y - 7.9, "Ring penetrated flat/slope floor")
			if ring.velocity.y < 0: bounced[i] = true
	for i in rings.size():
		check(bounced[i], "Ring bounced on terrain %d" % i)
		check(not is_instance_valid(rings[i]), "Ring expires after 255 physics ticks")
	print("Gameplay regression: %d failures" % failures)
	room.queue_free()
	quit(1 if failures else 0)
