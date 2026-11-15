extends SceneTree

const CameraRules = preload("res://scripts/gameplay/prototype_camera.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var actor := CharacterBody2D.new()
	root.add_child(actor)
	var camera := CameraRules.new()
	camera.target = actor
	camera.world_bounds = Rect2(400, 200, 3200, 900)
	root.add_child(camera)
	camera.set_physics_process(false)
	for view in [Vector2(1280, 720), Vector2(1920, 720), Vector2(2560, 720), Vector2(3200, 900), Vector2(5120, 1440)]:
		for desired in [Vector2(-999, -999), Vector2(2000, 600), Vector2(9999, 9999)]:
			var result := CameraRules.bounded_center(desired, view, camera.world_bounds)
			if view.x <= camera.world_bounds.size.x:
				check(result.x - view.x * 0.5 >= 400 and result.x + view.x * 0.5 <= 3600, "Horizontal viewport must remain within bounds: %s %s" % [view, desired])
			else:
				check(is_equal_approx(result.x, 2000), "Oversized viewport must center horizontally")
			if view.y <= camera.world_bounds.size.y:
				check(result.y - view.y * 0.5 >= 200 and result.y + view.y * 0.5 <= 1100, "Vertical viewport must remain within bounds")
			else:
				check(is_equal_approx(result.y, 650), "Oversized viewport must center vertically")
	actor.global_position = Vector2(1200, 500)
	actor.velocity = Vector2(1000, 0)
	camera.snap_to_target()
	check(camera.global_position.x >= 400, "Camera snap uses world bounds")
	camera.set_authored_bounds(Rect2(1000, 300, 600, 400), true)
	check(camera.follows_character(), "Authored encounter camera follows character")
	check(is_equal_approx(camera.global_position.x, 1200), "Encounter camera tracks character x")
	check(is_equal_approx(camera.global_position.y, 500), "Encounter camera maintains authored vertical center")
	camera.set_authored_bounds(Rect2(), false)
	check(not camera.follows_character(), "Leaving encounter restores bounded camera")
	check(camera.active_bounds() == camera.world_bounds, "Leaving encounter restores world bounds")
	camera.queue_free()
	actor.queue_free()
	print("Phase 4 camera regression: %d failures" % failures)
	quit(1 if failures else 0)
