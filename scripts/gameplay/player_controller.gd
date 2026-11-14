extends CharacterBody2D
class_name PrototypePlayer

## S3&K normal Sonic physics. ROM values are 8.8 fixed point per 60 Hz frame;
## multiplying by 60 converts velocity to px/s and by 3600 converts acceleration.
const MAX_SPEED := 360.0 # $600 = 6 px/frame
const ACCELERATION := 168.75 # $00C = 0.046875 px/frame^2
const AIR_ACCELERATION := 337.5 # 2 * Acceleration
const BRAKE := 1800.0 # $080 = 0.5 px/frame^2
const FRICTION := 168.75 # walking ground deceleration
const ROLL_FRICTION := 84.375 # Acceleration / 2 = $006
const ROLL_BRAKE := 450.0 # $020 = 0.125 px/frame^2
const ROM_FIXED_TO_ACCEL := 3600.0 / 256.0 # fixed-point px/frame -> px/s²
const SLOPE_RESIST_RAW := 0x20 # Player_SlopeResist coefficient
const ROLL_REPEL_RAW := 0x50 # Player_RollRepel coefficient
const SLOPE_STASIS_THRESHOLD := 13 # $0D: minimum slope force from rest
const SLOPE_MOVE_LOCK_FRAMES := 30
const SLOPE_REPEL_MIN_ANGLE := 24 # $18 angle units (33.75 degrees)
const SLOPE_SLIP_ANGLE := 48 # $30 angle units (67.5 degrees)
const SLOPE_REPEL_MAX_SPEED := 150.0 # $280 = 2.5 px/frame
const SLOPE_REPEL_SPEED := 30.0 # $80 = 0.5 px/frame
const GROUND_PROBE_OFFSETS := [-5.0, 0.0, 5.0]
const GROUND_PROBE_START := -2.0
const GROUND_PROBE_LENGTH := 10.0
const GROUND_PROBE_MAX_DISTANCE := 8.0
const GROUND_SEPARATION_SPEED := 45.0
const JUMP_IMPULSE := 390.0 # $680 = 6.5 px/frame
const JUMP_RELEASE_SPEED := -240.0 # $400 = 4 px/frame upward
const MAX_RISE_SPEED := -945.0 # $FC0 = 15.75 px/frame
const GRAVITY := 787.5 # $038 = 0.21875 px/frame^2
const SPINDASH_CHARGE_STEP := 512.0 # $200, cap $800
const SPINDASH_DECAY_RATE := 1.0 / 32.0
const SPINDASH_LAUNCH_SPEEDS := [480.0, 510.0, 540.0, 570.0, 600.0, 630.0, 660.0, 690.0, 720.0]

var facing := 1
var rolling := false
var ducking := false
var roll_jumping := false
var jumping := false
var rings := 0
var invulnerability_frames := 0
var hurt := false
var dying := false
var respawn_frames := 0
var invulnerability: float:
	get: return float(invulnerability_frames) / 60.0
var checkpoint_position := Vector2(100.0, 470.0)
var last_contacts := "none"
var death_y := 900.0
var ground_speed := 0.0
var ground_angle := 0.0
var spindash_charging := false
var spindash_charge := 0.0
var last_event := ""
var airborne := false
var slope_move_lock := 0
var player_collider: CollisionShape2D
var capsule_shape: CapsuleShape2D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	floor_snap_length = 8.0
	floor_max_angle = deg_to_rad(89.0)
	floor_stop_on_slope = false
	floor_constant_speed = true
	player_collider = CollisionShape2D.new()
	capsule_shape = CapsuleShape2D.new()
	player_collider.shape = capsule_shape
	add_child(player_collider)
	_update_collision_pose()

func _physics_process(delta: float) -> void:
	if dying:
		if respawn_frames > 0:
			respawn_frames -= 1
			if respawn_frames == 0: reset_to_checkpoint()
		else:
			position += velocity * delta
			velocity.y += GRAVITY * delta
			if global_position.y > death_y: respawn_frames = 60
		queue_redraw()
		return
	if hurt:
		var fall_speed := velocity.y
		move_and_slide()
		velocity.y += 675.0 * delta # loc_122D8: $30 per frame.
		if is_on_floor() and fall_speed >= 0.0:
			hurt = false
			airborne = false
			velocity = Vector2.ZERO
			invulnerability_frames = 120
		if global_position.y > death_y: begin_death()
		_update_contact_text()
		queue_redraw()
		return
	invulnerability_frames = maxi(0, invulnerability_frames - 1)
	var direction := Input.get_axis("move_left", "move_right")
	var down := Input.is_action_pressed("roll")
	var jump_pressed := Input.is_action_just_pressed("jump")
	var spindash_released := false
	var grounded := _is_grounded_for_jump_and_movement()
	if direction != 0.0 and not spindash_charging:
		if (not grounded and not roll_jumping) or (grounded and ground_speed * direction >= 0):
			facing = int(signf(direction))

	# SonicKnux_Roll enters ducking below $100 ground speed. SonicKnux_Spindash
	# starts on a fresh jump press while ducking; held Down maintains the charge.
	if grounded and down and direction == 0.0 and not rolling:
		ducking = true
	elif not down and not spindash_charging:
		ducking = false
	if grounded and down and direction == 0.0 and absf(ground_speed) >= 60.0:
		rolling = true
		ducking = false
	if spindash_charging:
		# loc_11C5E branches to release before decay or another charge tap.
		if down:
			spindash_charge = maxf(0.0, spindash_charge - floorf(spindash_charge * SPINDASH_DECAY_RATE))
			if jump_pressed:
				spindash_charge = minf(2048.0, spindash_charge + SPINDASH_CHARGE_STEP)
		if not down:
			# Counter is stored as the high byte in the ROM; every $200 tap
			# advances two entries in the half-pixel-per-frame launch table.
			var table_index := clampi(int(spindash_charge / 256.0), 0, SPINDASH_LAUNCH_SPEEDS.size() - 1)
			ground_speed = SPINDASH_LAUNCH_SPEEDS[table_index] * facing
			velocity = Vector2(cos(ground_angle), sin(ground_angle)) * ground_speed
			spindash_charging = false
			rolling = true
			ducking = false
			spindash_released = true
			last_event = "Spin Dash released · %.0f px/s" % absf(ground_speed)
	elif grounded and ducking and jump_pressed:
		spindash_charging = true
		spindash_charge = 0.0
		last_event = "Spin Dash charging"
	if spindash_released:
		_update_collision_pose()
		queue_redraw()
		return
	if spindash_charging:
		velocity = Vector2.ZERO
		_update_collision_pose()
		queue_redraw()
		return

	if jump_pressed and grounded and not spindash_released and _has_jump_clearance():
		ground_angle = _read_ground_angle()
		velocity = Vector2(cos(ground_angle), sin(ground_angle)) * ground_speed
		velocity += Vector2(sin(ground_angle), -cos(ground_angle)) * JUMP_IMPULSE
		roll_jumping = rolling
		jumping = true
		rolling = true
		ducking = false
		airborne = true
		last_event = "Roll jump" if roll_jumping else "Jump"
		_update_collision_pose()
		queue_redraw()
		# Sonic_Jump discards the ground-dispatch return address. Air movement
		# begins on the following update, not during the takeoff update.
		return
	if not grounded:
		if jumping and not Input.is_action_pressed("jump"):
			velocity.y = maxf(velocity.y, JUMP_RELEASE_SPEED)
		elif not jumping:
			velocity.y = maxf(velocity.y, MAX_RISE_SPEED)

	if grounded and not spindash_released:
		ground_angle = _read_ground_angle()
		var tangent := Vector2(cos(ground_angle), sin(ground_angle))
		# Keep ROM ground_vel independent of Godot's post-slide velocity.
		# Downhill slide resolution can remove Y; projecting it back every
		# frame repeatedly loses slope momentum.
		ground_speed = _apply_rom_slope_force(ground_speed, ground_angle, rolling, delta)
		var slope_locked := slope_move_lock > 0
		if rolling:
			if not slope_locked:
				ground_speed = _apply_roll_direction(ground_speed, direction, delta)
			ground_speed = move_toward(ground_speed, 0.0, ROLL_FRICTION * delta)
			if absf(ground_speed) < 30.0 and not spindash_charging:
				rolling = false
				ducking = down and direction == 0.0
		elif direction != 0.0 and not slope_locked:
			var desired := direction * MAX_SPEED
			if ground_speed == 0.0 or signf(ground_speed) == signf(desired):
				if absf(ground_speed) < MAX_SPEED:
					ground_speed = move_toward(ground_speed, desired, ACCELERATION * delta)
			else:
				ground_speed = _apply_ground_brake(ground_speed, direction, delta)
		elif direction == 0.0:
			ground_speed = move_toward(ground_speed, 0.0, FRICTION * delta)
		velocity = tangent * ground_speed
		if rolling:
			# Sonic_RollSpeed clamps horizontal velocity to +/-$1000 (16 px/frame).
			velocity.x = clampf(velocity.x, -960.0, 960.0)
	elif not grounded:
		ground_speed = velocity.x
		if direction != 0.0 and not roll_jumping:
			velocity.x = _apply_air_direction(velocity.x, direction, delta)
		# ROM releases the jump button to cap upward speed, independent of the
		# edge; holding it lets gravity extend the arc. Roll-jumps skip air steer.
		if velocity.y >= JUMP_RELEASE_SPEED and velocity.y < 0.0:
			velocity.x = _rom_peak_drag(velocity.x)


	_update_collision_pose()
	var apply_gravity_after_move := (airborne or not grounded) and not spindash_released
	var incoming_velocity := velocity
	move_and_slide()
	# Automatic snapping is disabled by upward world-space velocity, including
	# uphill tangent motion. Maintain existing ground attachment explicitly.
	# Jump takeoff must never use this snap.
	if grounded:
		apply_floor_snap()
	# MoveSprite_TestGravity first moves by the current velocity, then adds $38
	# gravity. Keep that order so the jump's first frame uses the full $680 impulse.
	if apply_gravity_after_move and not is_on_floor():
		velocity.y += GRAVITY * delta

	# A tangent to an uphill floor has negative Y velocity. Test motion against
	# the contact normal instead of world Y so uphill rolling remains grounded.
	var support := _get_ground_support()
	var touching_floor := not support.is_empty()
	var moving_away_from_floor := touching_floor and not grounded and velocity.dot(support.normal) > GROUND_SEPARATION_SPEED
	if touching_floor and not moving_away_from_floor:
		airborne = false
		roll_jumping = false
		jumping = false
		if not grounded: rolling = false
		ground_angle = _angle_from_support(support.normal)
		var floor_tangent := Vector2(cos(ground_angle), sin(ground_angle))
		if not grounded:
			ground_speed = _landing_ground_speed(incoming_velocity + Vector2(0, GRAVITY * delta), ground_angle)
		velocity = floor_tangent * ground_speed
		_apply_slope_repel(delta)
	else:
		airborne = true
		ground_angle = move_toward(ground_angle, 0.0, TAU * (120.0 / 256.0) * delta)
	if is_on_wall():
		if absf(velocity.x) > 0.0:
			velocity.x = 0.0
			ground_speed = 0.0
	if global_position.y > death_y:
		begin_death()
	_update_contact_text()
	queue_redraw()

func _read_ground_angle() -> float:
	var support := _get_ground_support()
	if support.is_empty():
		return ground_angle
	return _angle_from_support(support.normal)

func _angle_from_support(normal: Vector2) -> float:
	# The rightward floor tangent is (normal.y, -normal.x) in screen coordinates.
	return atan2(normal.x, -normal.y)

func _is_grounded_for_jump_and_movement() -> bool:
	var support := _get_ground_support()
	if support.is_empty():
		return false
	# Rolling uphill/downhill has a vertical component tangent to the surface.
	# Reject actual takeoff using normal velocity, not world-Y velocity.
	return not airborne or velocity.dot(support.normal) <= GROUND_SEPARATION_SPEED

func _get_ground_support() -> Dictionary:
	if is_on_floor():
		return {"normal": get_floor_normal(), "distance": 0.0}
	var space := get_world_2d().direct_space_state
	var excluded: Array[RID] = [get_rid()]
	var nearest_hit: Dictionary = {}
	var nearest_distance := INF
	for horizontal_offset in GROUND_PROBE_OFFSETS:
		var ray_start := global_position + Vector2(horizontal_offset, GROUND_PROBE_START)
		var ray_end := ray_start + Vector2(0.0, GROUND_PROBE_LENGTH)
		var query := PhysicsRayQueryParameters2D.create(ray_start, ray_end, collision_mask, excluded)
		query.collide_with_areas = false
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var normal: Vector2 = hit.normal
		if normal.dot(Vector2.UP) < cos(floor_max_angle):
			continue
		var distance := global_position.distance_to(hit.position)
		if distance <= GROUND_PROBE_MAX_DISTANCE and distance < nearest_distance:
			nearest_distance = distance
			nearest_hit = {"normal": normal, "distance": distance}
	return nearest_hit

func _apply_rom_slope_force(speed: float, angle: float, is_rolling: bool, delta: float) -> float:
	# The ROM multiplies the angle sine by $20 when walking and $50 when rolling.
	# Opposing roll-slope force is quarter strength; downhill force stays full.
	var coefficient := ROLL_REPEL_RAW if is_rolling else SLOPE_RESIST_RAW
	var sine_raw := int(sin(angle) * 256.0)
	var force_raw := (sine_raw * coefficient) >> 8
	if is_rolling and speed != 0.0 and signf(float(force_raw)) != signf(speed):
		force_raw = floori(float(force_raw) / 4.0)
	if not is_rolling and speed == 0.0 and absi(force_raw) < SLOPE_STASIS_THRESHOLD:
		return speed
	return speed + float(force_raw) * ROM_FIXED_TO_ACCEL * delta

func _apply_roll_direction(speed: float, direction: float, delta: float) -> float:
	# Sonic_RollSpeed does not accelerate a roll. Matching-direction input only
	# changes facing; opposite input subtracts $20 and bottoms out at +/-$80.
	if direction < 0.0 and speed > 0.0:
		speed -= ROLL_BRAKE * delta
		if speed < 0.0: speed = -SLOPE_REPEL_SPEED
	elif direction > 0.0 and speed < 0.0:
		speed += ROLL_BRAKE * delta
		if speed >= 0.0: speed = SLOPE_REPEL_SPEED
	return speed

func _apply_slope_repel(delta: float) -> void:
	# Player_SlopeRepel creates a 30-frame lock on slow, steep slopes and either
	# nudges Sonic downhill or transitions him to the air on very steep ground.
	if slope_move_lock > 0:
		slope_move_lock -= 1
		return
	var angle_units := absf(ground_angle) * 256.0 / TAU
	if angle_units < SLOPE_REPEL_MIN_ANGLE or absf(ground_speed) >= SLOPE_REPEL_MAX_SPEED:
		return
	slope_move_lock = SLOPE_MOVE_LOCK_FRAMES
	if angle_units >= SLOPE_SLIP_ANGLE:
		airborne = true
		return
	ground_speed += signf(ground_angle) * SLOPE_REPEL_SPEED
	velocity = Vector2(cos(ground_angle), sin(ground_angle)) * ground_speed

func _update_collision_pose() -> void:
	# Sonic_Jump restores default radii for a roll-jump. Ducking and walking
	# off a ledge also retain the standing radii; normal jumps use 7x14.
	var compact := rolling and not roll_jumping
	var target_radius := 7.0 if compact else 9.0
	var target_height := 28.0 if compact else 38.0
	# Rebuilding the physics shape every tick can invalidate resting contacts.
	if capsule_shape.radius != target_radius or capsule_shape.height != target_height:
		capsule_shape.radius = target_radius
		capsule_shape.height = target_height
		player_collider.position.y = -target_height * 0.5

func _landing_ground_speed(incoming: Vector2, angle: float) -> float:
	# loc_11F9C/loc_11FAE/loc_11FC2: shallow floor uses X, moderate
	# slopes use half Y, steep slopes use capped Y in the downhill direction.
	var units := absf(angle) * 256.0 / TAU
	if units < 16.0: return incoming.x
	var raw_y := roundi(incoming.y * 256.0 / 60.0)
	if units < 32.0: raw_y >>= 1
	else: raw_y = mini(raw_y, 0xFC0)
	return float(raw_y) * 60.0 / 256.0 * signf(angle)

func _has_jump_clearance() -> bool:
	# ROM requires six pixels overhead along the surface normal. This uses
	# the prototype shape; ROM tile probes remain a separate fidelity gap.
	var normal := Vector2(sin(_read_ground_angle()), -cos(_read_ground_angle()))
	return not test_move(global_transform, normal * 6.0)

func _apply_ground_brake(speed: float, direction: float, delta: float) -> float:
	var next := speed + direction * BRAKE * delta
	if (direction < 0 and next < 0) or (direction > 0 and next >= 0):
		return direction * 30.0 # sub_113F6/sub_11482: +/-$80 reversal.
	return next

func _apply_air_direction(speed: float, direction: float, delta: float) -> float:
	# Preserve existing overspeed when input points in its direction.
	if speed * direction >= MAX_SPEED: return speed
	var next := speed + direction * AIR_ACCELERATION * delta
	return minf(next, MAX_SPEED) if direction > 0 else maxf(next, -MAX_SPEED)

func _rom_peak_drag(speed: float) -> float:
	# Arithmetic shift is applied to signed 8.8 velocity, not px/second.
	var raw := roundi(speed * 256.0 / 60.0)
	var slowed := raw - (raw >> 5)
	return float(slowed) * 60.0 / 256.0

func _update_contact_text() -> void:
	var contacts: PackedStringArray = []
	if is_on_floor(): contacts.append("floor %.0f°" % rad_to_deg(ground_angle))
	if is_on_wall(): contacts.append("wall")
	if is_on_ceiling(): contacts.append("ceiling")
	last_contacts = ", ".join(contacts) if not contacts.is_empty() else "air"

func _draw() -> void:
	var color := Color("ffdf3d") if invulnerability <= 0.0 or (invulnerability_frames / 8) % 2 == 0 else Color("ffffff")
	var compact := rolling and not roll_jumping
	var radius := 12.0 if compact else 16.0
	var center_y := -14.0 if compact else -19.0
	draw_circle(Vector2(0, center_y), radius, color)
	draw_arc(Vector2(0, center_y), radius, -1.0, 1.0, 12, Color("e34845"), 4.0)
	draw_line(Vector2(-5, center_y - 6), Vector2(7, center_y - 6), Color("17202d"), 2.0)

func take_damage(hazard_x: float = NAN) -> void:
	if invulnerability_frames > 0 or hurt or dying:
		return
	if rings > 0:
		last_event = "Hit · lost %d rings" % rings
		if get_parent() != null and get_parent().has_method("spawn_scattered_rings"):
			get_parent().spawn_scattered_rings(global_position, rings)
		rings = 0
		hurt = true
		invulnerability_frames = 120
		spindash_charging = false
		spindash_charge = 0.0
		ducking = false
		var knockback_direction := -facing if is_nan(hazard_x) else (-1 if global_position.x < hazard_x else 1)
		velocity = Vector2(knockback_direction * 120.0, -240.0)
		ground_speed = 0.0
		airborne = true
		rolling = false
		roll_jumping = false
		jumping = false
	else:
		begin_death()

func can_collect_rings() -> bool:
	return not dying and not hurt and invulnerability_frames < 90

func begin_death() -> void:
	if dying: return
	dying = true
	hurt = false
	respawn_frames = 0
	spindash_charging = false
	rolling = false
	roll_jumping = false
	jumping = false
	ducking = false
	airborne = true
	ground_speed = 0.0
	velocity = Vector2(0, -420.0) # Kill_Character: -$700.
	last_event = "Death · returning to checkpoint"

func reset_to_checkpoint() -> void:
	if get_parent().has_method("restore_checkpoint_room"):
		get_parent().call_deferred("restore_checkpoint_room")
	dying = false
	hurt = false
	respawn_frames = 0
	rings = 0
	global_position = checkpoint_position
	velocity = Vector2.ZERO
	ground_speed = 0.0
	spindash_charging = false
	spindash_charge = 0.0
	rolling = false
	ducking = false
	roll_jumping = false
	jumping = false
	airborne = false
	slope_move_lock = 0
	invulnerability_frames = 0
