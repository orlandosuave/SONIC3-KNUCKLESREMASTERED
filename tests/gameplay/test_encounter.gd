extends SceneTree
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var room = load("res://scenes/encounter_prototype.tscn").instantiate()
	root.add_child(room)
	room.set_physics_process(false)
	room.player.set_physics_process(false)
	room.camera.set_physics_process(false)
	for resolution in [Vector2i(1920, 1080), Vector2i(2520, 1080), Vector2i(5120, 1440)]:
		root.size = resolution
		room.player.position = Vector2(1279, 520)
		room.restore_checkpoint_room()
		await process_frame
		room._physics_process(1.0 / 60)
		check(room.encounter_state == 0 and not room.boss.visible, "Visibility cannot start encounter")
		var entrance_screen: float = (root.get_canvas_transform() * Vector2(1280, 0)).x
		check(is_equal_approx(room.mask.visible_horizontal_range().y, minf(entrance_screen, room.get_viewport_rect().size.x)), "Approach conceals arena at world entrance")
		room.player.position.x = 1280
		room._physics_process(1.0 / 60)
		check(room.encounter_state == 1 and room.camera.authored_bounds == room.ARENA, "World entrance locks camera")
		check(room.gates[0].collision_layer == 1 and room.gates[1].collision_layer == 1, "Arena gates close")
		for tick in 119: room._physics_process(1.0 / 60)
		check(not room.boss.visible, "Cue lasts full 120 ticks")
		room._physics_process(1.0 / 60)
		check(room.boss.visible and room.encounter_state == 2, "Boss appears on tick 120")
		await process_frame
		var span: Vector2 = room.mask.visible_horizontal_range()
		var transform := root.get_canvas_transform()
		check(is_equal_approx(span.x, maxf(0, (transform * room.ARENA.position).x)) and is_equal_approx(span.y, minf(room.get_viewport_rect().size.x, (transform * room.ARENA.end).x)), "Mask follows authored arena while camera centers player")
		check(room.camera.position == Vector2(room.player.position.x, 360), "Encounter centers player horizontally")
		# Resize during the lock, then restore this test's resolution.
		root.size = Vector2i(1600, 450)
		await process_frame
		check(is_equal_approx(room.mask.visible_horizontal_range().x, 1200), "Live resize preserves side mask")
		root.size = resolution
		await process_frame
		for tick in 299: room._physics_process(1.0 / 60)
		check(room.encounter_state == 2, "Demo remains locked through tick 419")
		room._physics_process(1.0 / 60)
		check(room.encounter_state == 3 and not room.camera.authored_bounds.has_area(), "Tick 420 releases camera")
		check(room.mask.stage == 2 and room.gates[0].collision_layer == 0 and room.gates[1].collision_layer == 0, "Release removes masks and gates")
		room.player.reset_to_checkpoint()
		await process_frame
		check(room.encounter_state == 0 and not room.boss.visible and room.mask.stage == 0, "Checkpoint resets staging")
	# Exercise real collision against both active arena gates.
	room.player.position = Vector2(1280, 520)
	room._physics_process(1.0 / 60)
	await physics_frame
	await process_frame
	room.player.velocity = Vector2(-720, 0)
	for tick in 30:
		room.player.move_and_slide()
		await physics_frame
	check(room.player.position.x >= 1220, "Left gate physically contains player")
	room.player.position = Vector2(2400, 520)
	room.player.velocity = Vector2(720, 0)
	for tick in 30:
		room.player.move_and_slide()
		await physics_frame
	check(room.player.position.x <= 2460, "Right gate physically contains player")
	room.player.begin_death()
	room.player.reset_to_checkpoint()
	await process_frame
	check(room.encounter_state == 0 and room.gates[0].collision_layer == 0, "Death reset opens gates")
	# Keep all real physics callbacks enabled to verify horizontal centering
	# against the moving player on subsequent frames.
	for resolution in [Vector2i(1920, 1080), Vector2i(2520, 1080), Vector2i(5120, 1440)]:
		root.size = resolution
		room.player.position = Vector2(100, 520)
		room.player.velocity = Vector2.ZERO
		room.player.ground_speed = 0
		room.restore_checkpoint_room()
		room.set_physics_process(true)
		room.player.set_physics_process(true)
		room.camera.set_physics_process(true)
		Input.action_press("move_right")
		var approach_frames := 0
		var locked_frames := 0
		var first_locked_x := 0.0
		var last_locked_x := 0.0
		for frame in 900:
			await physics_frame
			await process_frame
			if room.encounter_state == 0:
				approach_frames += 1
				check(room.camera.get_screen_center_position().is_equal_approx(Vector2(room.player.position.x, 360)), "Approach camera follows from spawn at %s" % resolution)
			if room.encounter_state == 1 or room.encounter_state == 2:
				if locked_frames == 0: first_locked_x = room.player.position.x
				last_locked_x = room.player.position.x
				locked_frames += 1
				check(room.camera.get_screen_center_position().is_equal_approx(Vector2(room.player.position.x, 360)), "Rendered camera keeps moving player centered at %s" % resolution)
			if room.encounter_state == 3: break
		for frame in 30:
			await physics_frame
			await process_frame
			check(room.camera.get_screen_center_position().is_equal_approx(Vector2(room.player.position.x, 360)), "Camera continues following after release")
		Input.action_release("move_right")
		check(approach_frames > 100, "Live approach tested from spawn")
		check(locked_frames > 100 and last_locked_x - first_locked_x > 500, "Live player traversed locked arena")
		check(room.encounter_state == 3, "Live encounter releases after demo")
		room.set_physics_process(false)
		room.player.set_physics_process(false)
		room.camera.set_physics_process(false)
	room.free()
	print("Encounter regression: %d failures" % failures)
	quit(1 if failures else 0)
