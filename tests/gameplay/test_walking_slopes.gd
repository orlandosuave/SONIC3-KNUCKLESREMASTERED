extends SceneTree

var failures := 0
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for action in ["move_left", "move_right", "roll", "jump"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	for scenario in [Vector2(-0.4, 1), Vector2(0.4, 1), Vector2(-0.4, -1), Vector2(0.4, -1)]:
		var grade: float = scenario.x
		var direction: float = scenario.y
		var action := "move_right" if direction > 0 else "move_left"
		var world := Node2D.new()
		root.add_child(world)
		var floor_body := StaticBody2D.new()
		var polygon := CollisionPolygon2D.new()
		polygon.polygon = PackedVector2Array([Vector2(-2000, 500-2000*grade), Vector2(2000,500+2000*grade),Vector2(2000,2500),Vector2(-2000,2500)])
		floor_body.add_child(polygon)
		world.add_child(floor_body)
		var player = load("res://scripts/gameplay/player_controller.gd").new()
		player.position = Vector2(0, 495)
		player.death_y = 4000
		world.add_child(player)
		for i in 20:
			await physics_frame
			await process_frame
		var tangent := Vector2(1, grade).normalized()
		player.ground_speed = direction * 180.0
		player.velocity = tangent * direction * 180.0
		Input.action_press(action)
		var start: Vector2 = player.position
		for i in 60:
			await physics_frame
			await process_frame
		Input.action_release(action)
		print("grade=",grade," direction=",direction," speed=",player.ground_speed," distance=",(player.position-start).length()," air=",player.airborne)
		var speed: float = player.ground_speed * direction
		var downhill := grade * direction > 0
		if speed < 180.0 or (downhill and speed <= 360.0) or player.airborne:
			failures += 1
			push_error("Walking must retain ground speed uphill and gain momentum downhill")
		world.queue_free()
		await process_frame
	print("Slope regression: %d failures" % failures)
	quit(1 if failures else 0)
