extends Node2D

const PlayerController = preload("res://scripts/gameplay/player_controller.gd")
const ROOM_WIDTH := 2600.0
const FLOOR_Y := 520.0
const RING_POSITIONS := [Vector2(340, 430), Vector2(390, 400), Vector2(440, 430), Vector2(710, 430), Vector2(760, 430), Vector2(1080, 430), Vector2(1130, 390), Vector2(1180, 350), Vector2(1450, 430), Vector2(1500, 430), Vector2(1550, 430), Vector2(1900, 430), Vector2(1950, 430), Vector2(2000, 430)]

var player: PrototypePlayer
var camera: Camera2D
var hud: Label
var start_usec := 0
var frame_count := 0
var measured_fps := 60.0
var elapsed := 0.0
var completed := false
var simulation_ticks := 0
var checkpoint_ticks := 0

func _ready() -> void:
	_ensure_input("move_left", [KEY_LEFT, KEY_A])
	_ensure_input("move_right", [KEY_RIGHT, KEY_D])
	_ensure_input("jump", [KEY_SPACE, KEY_UP, KEY_Z])
	_ensure_input("roll", [KEY_DOWN, KEY_S, KEY_X])
	_build_room()
	_build_hud()
	start_usec = Time.get_ticks_usec()

func _physics_process(_delta: float) -> void:
	if not player.dying: simulation_ticks += 1
	for area in get_tree().get_nodes_in_group("prototype_collectible"):
		if not area.is_queued_for_deletion() and player.can_collect_rings() and area.overlaps_body(player):
			player.rings += 1
			area.queue_free()
	for area in get_tree().get_nodes_in_group("prototype_hazard"):
		if area.overlaps_body(player): player.take_damage(area.global_position.x)

func restore_checkpoint_room() -> void:
	simulation_ticks = checkpoint_ticks
	completed = false
	camera.snap_to_target()
	for area in get_tree().get_nodes_in_group("prototype_collectible"):
		area.free()
	for ring in get_tree().get_nodes_in_group("prototype_spill"):
		ring.free()
	for point in RING_POSITIONS: _add_ring(point)

func _process(delta: float) -> void:
	frame_count += 1
	elapsed += delta
	if elapsed >= 0.5:
		measured_fps = frame_count / elapsed
		frame_count = 0
		elapsed = 0.0
	_update_hud()

func _ensure_input(action: String, keys: Array) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action)
	for keycode in keys:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		if not InputMap.action_has_event(action, event): InputMap.action_add_event(action, event)

func _build_room() -> void:
	var background := ColorRect.new()
	background.color = Color("152941")
	background.position = Vector2(-500, -300)
	background.size = Vector2(ROOM_WIDTH + 1000, 900)
	background.z_index = -10
	add_child(background)
	var far_hills := Polygon2D.new()
	far_hills.polygon = PackedVector2Array([Vector2(-200, 480), Vector2(150, 260), Vector2(470, 480), Vector2(760, 300), Vector2(1100, 480), Vector2(1400, 260), Vector2(1780, 480), Vector2(2200, 290), Vector2(2800, 480), Vector2(2800, 650), Vector2(-200, 650)])
	far_hills.color = Color("203b53")
	far_hills.z_index = -5
	add_child(far_hills)
	_add_profiled_floor()
	_add_solid(Vector2(640, 450), Vector2(180, 20))
	_add_solid(Vector2(1310, 390), Vector2(200, 20))
	_add_solid(Vector2(1770, 450), Vector2(240, 20))
	_add_solid(Vector2(2160, 300), Vector2(20, 180)) # wall contact test
	_add_solid(Vector2(2260, 250), Vector2(240, 20)) # ceiling contact test
	player = PlayerController.new()
	player.position = Vector2(100, FLOOR_Y - 50)
	add_child(player)
	camera = preload("res://scripts/gameplay/prototype_camera.gd").new()
	camera.target = player
	camera.world_bounds = Rect2(0, 0, ROOM_WIDTH, 720)
	add_child(camera)
	camera.make_current()
	for point in RING_POSITIONS:
		_add_ring(point)
	_add_trigger(Vector2(860, FLOOR_Y - 20), Vector2(38, 50), "hazard")
	_add_trigger(Vector2(1250, FLOOR_Y - 20), Vector2(32, 60), "checkpoint")
	_add_trigger(Vector2(ROOM_WIDTH - 100, FLOOR_Y - 40), Vector2(44, 80), "goal")
	queue_redraw()

func _add_profiled_floor() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	var outline := PackedVector2Array([
		Vector2(-200, 520), Vector2(250, 520), Vector2(450, 440),
		Vector2(650, 440), Vector2(850, 520), Vector2(1250, 520),
		Vector2(1450, 460), Vector2(1650, 520), Vector2(ROOM_WIDTH + 200, 520),
		Vector2(ROOM_WIDTH + 200, 720), Vector2(-200, 720)
	])
	var collision := CollisionPolygon2D.new()
	collision.polygon = outline
	body.add_child(collision)
	var visual := Polygon2D.new()
	visual.polygon = outline
	visual.color = Color("31a966")
	body.add_child(visual)
	add_child(body)

func _add_solid(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 1
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	var visual := ColorRect.new()
	visual.color = Color("31a966") if center.y > FLOOR_Y else Color("46728a")
	visual.position = -size * 0.5
	visual.size = size
	body.add_child(visual)
	add_child(body)

func _add_ring(point: Vector2) -> void:
	var area := Area2D.new()
	area.position = point
	area.collision_layer = 0
	area.collision_mask = 1
	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 13
	shape_node.shape = circle
	area.add_child(shape_node)
	area.add_to_group("prototype_collectible")
	var ring := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 17:
		var angle := TAU * float(i) / 16.0
		var radius := 11.0 if i % 2 == 0 else 7.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	ring.polygon = points
	ring.color = Color("ffd64a")
	area.add_child(ring)
	add_child(area)

func spawn_scattered_rings(origin: Vector2, count: int) -> void:
	var ring_script = preload("res://scripts/gameplay/scattered_ring.gd")
	for index in mini(count, 32):
		# ROM $288 sequence: mirrored pairs, sixteen angles per speed tier.
		var pair := (index % 16) / 2
		var angle := float(0x88 + int(pair) * 0x10) * TAU / 256.0
		var speed := 240.0 if index < 16 else 120.0
		var ring = ring_script.new()
		ring.player = player
		ring.position = origin + Vector2(0, -19)
		ring.velocity = Vector2(int(sin(angle) * 256.0), int(cos(angle) * 256.0)) * speed / 256.0
		if index % 2 == 1:
			ring.velocity.x = -ring.velocity.x
		# Damage can occur while physics queries are being flushed.
		call_deferred("add_child", ring)

func _add_trigger(point: Vector2, size: Vector2, kind: String) -> void:
	var area := Area2D.new()
	if kind == "hazard": area.add_to_group("prototype_hazard")
	area.position = point
	area.collision_layer = 0
	area.collision_mask = 1
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	shape_node.shape = shape
	area.add_child(shape_node)
	var marker := ColorRect.new()
	marker.position = -size * 0.5
	marker.size = size
	marker.color = Color("c84c56", 0.8) if kind == "hazard" else Color("83e2d4", 0.85)
	area.add_child(marker)
	area.body_entered.connect(func(body: Node2D):
		if body != player: return
		match kind:
			"hazard": player.take_damage(point.x)
			"checkpoint":
				player.checkpoint_position = Vector2(point.x, FLOOR_Y - 50)
				checkpoint_ticks = simulation_ticks
				marker.color = Color("9be2b2", 0.9)
			"goal": completed = true
	)
	add_child(area)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var safe := preload("res://scripts/ui/safe_region.gd").new()
	layer.add_child(safe)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 0)
	safe.add_child(panel)
	hud = Label.new()
	hud.add_theme_color_override("font_color", Color("f1f5fa"))
	hud.add_theme_font_size_override("font_size", 15)
	hud.add_theme_constant_override("line_spacing", 3)
	panel.add_child(hud)
	var help := Label.new()
	help.text = "Move: A/D or ←/→  Jump: Space/Z  Spin Dash: hold S/↓ + tap Space/Z, release Down  Esc: menu"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", Color("e1e9f2"))
	safe.add_child(help)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	help.offset_top = -48
	var exit_button := Button.new()
	exit_button.text = "Back"

	exit_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	safe.add_child(exit_button)
	exit_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	exit_button.offset_left = -80
	exit_button.offset_bottom = 32
	var options_layer := CanvasLayer.new()
	options_layer.layer = 10
	add_child(options_layer)
	var options_dialog := CenterContainer.new()
	options_dialog.name = "HudSettingsOverlay"
	options_layer.add_child(options_dialog)
	options_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	options_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	var options_panel := PanelContainer.new()
	options_panel.custom_minimum_size.x = 560
	options_dialog.add_child(options_panel)
	var options_content := VBoxContainer.new()
	options_panel.add_child(options_content)
	var options := preload("res://scripts/ui/display_options.gd").new()
	options_content.add_child(options)
	var close_options := Button.new()
	close_options.text = "Close settings"
	close_options.pressed.connect(func(): options_dialog.hide())
	options_content.add_child(close_options)
	options_dialog.hide()
	var options_button := Button.new()
	options_button.text = "HUD settings"
	safe.add_child(options_button)
	options_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	options_button.offset_left = -220
	options_button.offset_right = -90
	options_button.offset_bottom = 32
	options_button.pressed.connect(func(): options_dialog.show())
	_update_hud()

func _update_hud() -> void:
	if player == null or hud == null: return
	var elapsed_seconds := float(simulation_ticks) / 60.0
	var state := "grounded"
	if player.dying:
		state = "dead"
	elif player.hurt:
		state = "hurt"
	elif player.spindash_charging:
		state = "spin dash charging %d%%" % roundi(player.spindash_charge / 2048.0 * 100.0)
	elif player.roll_jumping and player.airborne:
		state = "roll-jumping"
	elif player.airborne:
		state = "airborne"
	elif player.rolling:
		state = "rolling"
	hud.text = "MOVEMENT PROTOTYPE\nSpeed: %6.1f px/s (Y %6.1f)   Rings: %02d   State: %s\nContacts: %s\nSimulation: %d Hz   Render: %4.1f FPS   Time: %5.2f s%s%s" % [player.velocity.x, player.velocity.y, player.rings, state, player.last_contacts, Engine.physics_ticks_per_second, measured_fps, elapsed_seconds, "\n" + player.last_event if not player.last_event.is_empty() else "", "\nGOAL REACHED" if completed else ""]

func _draw() -> void:
	for x in range(0, int(ROOM_WIDTH) + 1, 100):
		draw_line(Vector2(x, FLOOR_Y + 1), Vector2(x + 70, FLOOR_Y + 1), Color("c5e38b", 0.7), 3)
