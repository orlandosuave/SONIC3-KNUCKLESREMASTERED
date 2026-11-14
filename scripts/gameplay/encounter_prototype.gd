extends "res://scripts/gameplay/movement_prototype.gd"
## Original staging fixture; not an implementation of a campaign boss.
const ARENA := Rect2(1200, 0, 1280, 720)
const ENTRANCE_X := 1280.0
const CUE_TICKS := 120
const DEMO_TICKS := 300
var encounter_state := 0 # approach, cue, demonstration, released
var encounter_ticks := 0
var mask: Control
var boss: Polygon2D
var gates: Array[StaticBody2D] = []

func _build_room() -> void:
	_add_solid(Vector2(2000, 620), Vector2(7200, 200))
	player = PlayerController.new()
	player.position = Vector2(100, 470)
	player.checkpoint_position = player.position
	add_child(player)
	camera = preload("res://scripts/gameplay/prototype_camera.gd").new()
	camera.target = player
	camera.follow_character_during_traversal = true
	camera.world_bounds = Rect2(0, 0, 4000, 720)
	add_child(camera)
	camera.make_current()
	for x in [ARENA.position.x, ARENA.end.x]:
		var gate := StaticBody2D.new()
		gate.position = Vector2(x, 360)
		gate.collision_layer = 0
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(24, 1440)
		collider.shape = shape
		gate.add_child(collider)
		add_child(gate)
		gates.append(gate)
	boss = Polygon2D.new()
	boss.polygon = PackedVector2Array([Vector2(-48, 0), Vector2(-30, -40), Vector2(30, -40), Vector2(48, 0), Vector2(30, 32), Vector2(-30, 32)])
	boss.position = Vector2(2200, 340)
	boss.color = Color("ef8c54")
	boss.visible = false
	add_child(boss)
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	mask = preload("res://scripts/ui/encounter_mask.gd").new()
	layer.add_child(mask)
	_add_trigger(Vector2(3500, 480), Vector2(44, 80), "goal")
	_add_sign(Vector2(400, 400), "ENCOUNTER STAGING TEST\nMove right to enter. R: restart demo")
	_add_sign(Vector2(2750, 400), "CAMERA RELEASED\nContinue right to the goal")
	queue_redraw()

func _draw() -> void:
	# World-fixed markers make camera tracking visible even on the flat test floor.
	for x in range(-1400, 5401, 200):
		draw_line(Vector2(x, 520), Vector2(x, 580), Color("c5e38b"), 3)
		draw_line(Vector2(x, 580), Vector2(x + 100, 580), Color("c5e38b"), 3)

func _add_sign(point: Vector2, text: String) -> void:
	var label := Label.new()
	label.position = point
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	add_child(label)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if player.dying: return
	if encounter_state == 0:
		if player.position.x >= ENTRANCE_X and player.position.x < ARENA.end.x and player.position.y >= 0 and player.position.y <= 540:
			encounter_state = 1
			encounter_ticks = 0
			mask.stage = 1
			camera.set_authored_bounds(ARENA, true)
			for gate in gates: gate.collision_layer = 1
		return
	if encounter_state == 3: return
	encounter_ticks += 1
	if encounter_ticks == CUE_TICKS:
		encounter_state = 2
		boss.visible = true
	if encounter_state == 2:
		boss.position.y = 340 + sin(float(encounter_ticks - CUE_TICKS) * TAU / 120) * 48
	if encounter_ticks >= CUE_TICKS + DEMO_TICKS:
		encounter_state = 3
		mask.stage = 2
		boss.visible = false
		for gate in gates: gate.collision_layer = 0
		camera.set_authored_bounds(Rect2())

func restore_checkpoint_room() -> void:
	simulation_ticks = 0
	completed = false
	encounter_state = 0
	encounter_ticks = 0
	mask.stage = 0
	boss.visible = false
	for gate in gates: gate.collision_layer = 0
	camera.set_authored_bounds(Rect2())
	for ring in get_tree().get_nodes_in_group("prototype_spill"): ring.queue_free()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		player.reset_to_checkpoint()

func _update_hud() -> void:
	super._update_hud()
	if hud == null: return
	var captions := ["Camera following player — approach the arena →", "GET READY — camera centered on player", "Boss staging demo — gates open shortly", "Camera following player — continue right →"]
	hud.text = "ENCOUNTER STAGING TEST\n%s\nR: restart • Placeholder boss, no attacks\n" % captions[encounter_state] + hud.text.trim_prefix("MOVEMENT PROTOTYPE\n")
