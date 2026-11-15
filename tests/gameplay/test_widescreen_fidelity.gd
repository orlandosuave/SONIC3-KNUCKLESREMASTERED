extends SceneTree

const CameraRules = preload("res://scripts/gameplay/prototype_camera.gd")
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(3440, 1440), Vector2i(5120, 1440)]
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var baseline_position := Vector2.ZERO
	var baseline_velocity := Vector2.ZERO
	for resolution in RESOLUTIONS:
		root.size = resolution
		await process_frame
		var room = load("res://scenes/movement_prototype.tscn").instantiate()
		root.add_child(room)
		await process_frame
		await process_frame
		var visible: Vector2 = room.get_viewport_rect().size
		var expected_width := 720.0 * float(resolution.x) / float(resolution.y)
		check(absf(visible.x - expected_width) < 1.0, "Hor+ world width at %s: %s versus %s" % [resolution, visible.x, expected_width])
		check(absf(visible.y - 720.0) < 0.01, "Fixed logical height at %s" % resolution)
		room.set_physics_process(false)
		room.player.set_physics_process(false)
		room.camera.set_physics_process(false)
		room.player.position = Vector2(100, 470)
		room.player.velocity = Vector2(240, -180)
		var start_position: Vector2 = room.player.position
		var start_velocity: Vector2 = room.player.velocity
		room.camera.snap_to_target()
		check(room.player.position == start_position and room.player.velocity == start_velocity, "Camera resize does not mutate simulation at %s" % resolution)
		if resolution == RESOLUTIONS[0]:
			baseline_position = start_position
			baseline_velocity = start_velocity
		else:
			check(room.player.position == baseline_position and room.player.velocity == baseline_velocity, "Simulation initial state independent of resolution at %s" % resolution)
		var center := CameraRules.bounded_center(Vector2(1300, 360), visible, Rect2(0, 0, 2600, 720))
		check(center.x >= visible.x * 0.5 and center.x <= 2600 - visible.x * 0.5, "32:9 camera contained at %s" % resolution)
		room.free()
	check(Engine.physics_ticks_per_second == 60, "Original simulation tick rate remains 60 Hz")
	print("Phase 4 widescreen fidelity regression: %d failures" % failures)
	quit(1 if failures else 0)
