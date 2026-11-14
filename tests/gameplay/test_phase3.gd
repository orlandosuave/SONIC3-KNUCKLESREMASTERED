extends SceneTree

const CameraRules = preload("res://scripts/gameplay/prototype_camera.gd")
const SafeRegion = preload("res://scripts/ui/safe_region.gd")
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
	room.player.set_physics_process(false)
	room.set_physics_process(false)
	room.camera.set_physics_process(false)
	for resolution in [Vector2i(1920, 1080), Vector2i(2520, 1080), Vector2i(5120, 1440)]:
		root.size = resolution
		await process_frame
		await process_frame
		var actual: Vector2 = room.get_viewport_rect().size
		var expected := Vector2(float(resolution.x) / resolution.y * 720.0, 720)
		check(actual.is_equal_approx(expected), "Actual expanded viewport %s, expected %s" % [actual, expected])
		room.camera.snap_to_target()
		check(room.camera.position.x >= actual.x / 2, "Resize reapplies camera bounds")
	for width in [1280.0, 1680.0, 2560.0]:
		var view := Vector2(width, 720)
		var bounds := Rect2(0, 0, 2600, 720)
		for point in [Vector2(-200, -200), Vector2(1300, 360), Vector2(3000, 1000)]:
			var center := CameraRules.bounded_center(point, view, bounds)
			check(center.x - width / 2 >= 0 and center.x + width / 2 <= 2600, "World edges contained at %s" % width)
			check(center.y == 360, "Vertical framing preserved")
		var safe := SafeRegion.content_rect(view, 1280, 16)
		check(safe.size == Vector2(1248, 688), "Safe HUD size stable")
		check(safe.get_center() == view / 2, "Safe HUD centered")
		check(CameraRules.bounded_center(Vector2.ZERO, view, Rect2(1000, 0, 600, 720)) == Vector2(1300, 360), "Narrow authored bounds center without inverted clamp")
	room.player.velocity.x = 1000
	check(room.camera.desired_center().x == room.player.position.x + 120, "Look-ahead capped")
	room.player.velocity.x = -240
	check(room.camera.desired_center().x == room.player.position.x - 60, "Look-ahead follows travel direction")
	room.camera.set_authored_bounds(Rect2(1000, 0, 600, 720))
	check(room.camera.position == Vector2(1300, 360), "Authored bounds applied")
	room.camera.set_authored_bounds(Rect2())
	check(room.camera.active_bounds() == Rect2(0, 0, 2600, 720), "Authored bounds released")
	room.player.checkpoint_position = Vector2(1250, 470)
	room.player.reset_to_checkpoint()
	await process_frame
	check(not room.completed, "Reset does not trigger goal")
	check(Engine.physics_ticks_per_second == 60, "Display changes retain 60 Hz")
	room.free()
	print("Phase 3 camera regression: %d failures" % failures)
	quit(1 if failures else 0)
