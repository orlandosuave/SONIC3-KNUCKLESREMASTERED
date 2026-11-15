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

 #   - - -   A n g e l   I s l a n d   T e r r a i n   C h u n k   I m p l e m e n t a t i o n   - - - 
 
 #   W e   m u s t   m o c k   t h e   R O M   d a t a   b u n d l e   s i n c e   t h e   A n g e l   I s l a n d   R O M   w a s   n o t   p r o v i d e d .   
 #   T h i s   s i m u l a t e s   l o a d i n g   t h e   n e c e s s a r y   s t r u c t u r e   t h a t   R o m T e r r a i n D e c o d e r   p r o d u c e s . 
 f u n c   _ g e t _ m o c k _ a n g e l _ i s l a n d _ b u n d l e ( )   - >   D i c t i o n a r y : 
 	 #   B a s e d   o n   R o m T e r r a i n C o l l i s i o n   r e q u i r e m e n t s   ( f o r e g r o u n d / b a c k g r o u n d ,   c h u n k s ,   c o l l i s i o n _ p r i m a r y ,   c o l l i s i o n _ s e c o n d a r y ,   h e i g h t s ,   a n g l e s ) 
 	 v a r   m o c k _ b u n d l e   : =   D i c t i o n a r y . n e w ( ) 
 	 
 	 #   M o c k   l a y o u t   d a t a   ( m i n i m a l   t o   p a s s   b a s i c   c h e c k s ) 
 	 v a r   l a y o u t   : =   D i c t i o n a r y . n e w ( ) 
 	 l a y o u t [  
 w i d t h _ c h u n k s ]   =   1 
 	 l a y o u t [ h e i g h t _ c h u n k s ]   =   1 
 	 v a r   m o c k _ r o w   : =   P a c k e d B y t e A r r a y . n e w ( ) 
 	 m o c k _ r o w . r e s i z e ( 1 2 8 ) 
 	 #   S i m u l a t e   o n e   c h u n k   s t a r t i n g   a t   i n d e x   0 
 	 m o c k _ r o w [ 0 ]   =   0 x 1 0 0 1   #   B l o c k   I D   1 ,   b u t   n o t   i n   f o r e g r o u n d ,   h i g h   e n o u g h   f o r   s o m e   c o l l i s i o n   ( s i m u l a t e d ) 
 	 
 	 m o c k _ b u n d l e [ f o r e g r o u n d ]   =   { 
 	 	 w i d t h _ c h u n k s :   1 ,   h e i g h t _ c h u n k s :   1 ,   r o w s :   [ m o c k _ r o w ] 
 	 } 
 
 	 #   M o c k   c h u n k   d a t a   ( 3 2   b y t e s   m i n i m u m   n e e d e d   f o r   s i n g l e   c h u n k ) 
 	 v a r   m o c k _ c h u n k s   : =   P a c k e d B y t e A r r a y . n e w ( ) 
 	 m o c k _ c h u n k s . r e s i z e ( 1 2 8 ) 
 	 m o c k _ c h u n k s [ 0 ]   =   0 x 1 0 0 1   #   C h u n k   I D   1   ( m i n i m a l   r e p r e s e n t a t i o n ) 
 	 
 	 m o c k _ b u n d l e [ c h u n k s ]   =   m o c k _ c h u n k s 
 	 
 	 #   M o c k   c o l l i s i o n / g e o m e t r y   d a t a   ( m i n i m a l ) 
 	 v a r   m o c k _ p r i m a r y   : =   P a c k e d B y t e A r r a y . n e w ( ) 
 	 m o c k _ p r i m a r y . r e s i z e ( 2 5 6 )   #   E n o u g h   f o r   7 6 8   i n d i c e s   i f   w e   w e r e   u s i n g   f u l l   d a t a ,   2 5 6   i s   m i n i m a l   r e p r e s e n t a t i o n 
 	 m o c k _ p r i m a r y . f i l l ( 0 ) 
 	 m o c k _ b u n d l e [ c o l l i s i o n _ p r i m a r y ]   =   m o c k _ p r i m a r y 
 	 
 	 v a r   m o c k _ s e c o n d a r y   : =   P a c k e d B y t e A r r a y . n e w ( ) 
 	 m o c k _ s e c o n d a r y . r e s i z e ( 2 5 6 ) 
 	 m o c k _ b u n d l e [ c o l l i s i o n _ s e c o n d a r y ]   =   m o c k _ s e c o n d a r y 
 	 
 	 #   M o c k   h e i g h t   a n d   a n g l e s   a r r a y s   ( m i n i m a l   t o   a l l o w   f i n d _ f l o o r   t o   r u n   w i t h o u t   f a t a l   e r r o r s ) 
 	 v a r   h e i g h t s   : =   P a c k e d B y t e A r r a y . n e w ( ) 
 	 h e i g h t s . r e s i z e ( 1 6   *   1 6 ) 
 	 h e i g h t s . f i l l ( 0 )   #   F l a t   g r o u n d 
 	 m o c k _ b u n d l e [ h e i g h t s ]   =   h e i g h t s 
 	 v a r   a n g l e s   : =   P a c k e d B y t e A r r a y . n e w ( ) 
 	 a n g l e s . r e s i z e ( 1 6   *   1 6 ) 
 	 a n g l e s . f i l l ( 0 ) 
 	 m o c k _ b u n d l e [ a n g l e s ]   =   a n g l e s 
 
 	 r e t u r n   m o c k _ b u n d l e 
 
 f u n c   _ s p a w n _ a n g e l _ i s l a n d _ c h u n k ( )   - >   v o i d : 
 	 v a r   b u n d l e :   D i c t i o n a r y   =   _ g e t _ m o c k _ a n g e l _ i s l a n d _ b u n d l e ( ) 
 	 v a r   s p a w n _ p o s :   V e c t o r 2 i   =   V e c t o r 2 i ( 3 0 0 ,   5 2 0 )   #   P l a c e   c h u n k   n e a r   t h e   s t a r t 
 	 
 	 #   1 .   C a l c u l a t e   t h e   g r o u n d   l e v e l   b a s e d   o n   m o c k   d a t a 
 	 v a r   f l o o r _ d a t a :   D i c t i o n a r y   =   R o m T e r r a i n C o l l i s i o n . f i n d _ f l o o r ( b u n d l e ,   s p a w n _ p o s ) 
 	 
 	 i f   n o t   f l o o r _ d a t a [ o k ] : 
 	 	 p r i n t ( E R R O R :  
 C o u l d  
 n o t  
 c a l c u l a t e  
 f l o o r  
 f o r  
 A n g e l  
 I s l a n d  
 c h u n k :  
 % s   %   f l o o r _ d a t a . g e t ( e r r o r ,   " ) ) 
 	 	 r e t u r n 
 	 
 	 v a r   g r o u n d _ h e i g h t :   f l o a t   =   ( 1 2 8 . 0   -   f l o o r _ d a t a [ d i s t a n c e ] )   *   1 6 . 0   #   1 2 8   g r i d   u n i t s   h e i g h t   *   1 6   p i x e l s / u n i t 
 	 
 	 #   2 .   I n s t a n t i a t e   c o n t a i n e r   a n d   v i s u a l i z e / s i m u l a t e   c o l l i s i o n 
 	 v a r   c h u n k _ c o n t a i n e r   : =   S t a t i c B o d y 2 D . n e w ( ) 
 	 c h u n k _ c o n t a i n e r . n a m e   =   A n g e l I s l a n d C h u n k 
 	 
 	 #   M o c k   v i s u a l   r e p r e s e n t a t i o n   ( a   s o l i d   b l o c k   b a s e d   o n   c o m p u t e d   h e i g h t ) 
 	 v a r   v i s u a l _ r e c t   : =   C o l o r R e c t . n e w ( ) 
 	 v i s u a l _ r e c t . p o s i t i o n   =   V e c t o r 2 ( s p a w n _ p o s . x   -   1 0 0 ,   F L O O R _ Y   -   g r o u n d _ h e i g h t ) 
 	 v i s u a l _ r e c t . s i z e   =   V e c t o r 2 ( 2 0 0 ,   g r o u n d _ h e i g h t ) 
 	 v i s u a l _ r e c t . c o l o r   =   C o l o r ( 6 a 4 c 8 e )   #   D i s t i n c t   c o l o r   f o r   t h e   n e w   t e r r a i n 
 	 c h u n k _ c o n t a i n e r . a d d _ c h i l d ( v i s u a l _ r e c t ) 
 	 
 	 #   M o c k   c o l l i s i o n   s h a p e   ( s i n c e   w e   c a n n o t   g e n e r a t e   c o m p l e x   s h a p e s   f r o m   m o c k   d a t a ) 
 	 v a r   c o l l i s i o n _ s h a p e   : =   C o l l i s i o n S h a p e 2 D . n e w ( ) 
 	 v a r   s h a p e   : =   R e c t a n g l e S h a p e 2 D . n e w ( ) 
 	 s h a p e . s i z e   =   V e c t o r 2 ( 2 0 0 ,   g r o u n d _ h e i g h t ) 
 	 c o l l i s i o n _ s h a p e . s h a p e   =   s h a p e 
 	 c h u n k _ c o n t a i n e r . a d d _ c h i l d ( c o l l i s i o n _ s h a p e ) 
 	 
 	 a d d _ c h i l d ( c h u n k _ c o n t a i n e r ) 
 	 p r i n t ( S u c c e s s f u l l y  
 s p a w n e d  
 m o c k  
 A n g e l  
 I s l a n d  
 t e r r a i n  
 c h u n k  
 a t  
 % s  
 w i t h  
 h e i g h t  
 % 6 . 1 f   %   [ s p a w n _ p o s ,   g r o u n d _ h e i g h t ] ) 
 
 #   - - -   E n d   A n g e l   I s l a n d   C h u n k   I m p l e m e n t a t i o n   - - - 
  
 