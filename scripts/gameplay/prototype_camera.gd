extends Camera2D
## Presentation only: no gameplay activation depends on the visible rectangle.

@export var look_ahead_seconds := 0.25
@export var maximum_look_ahead := 120.0
@export var follow_speed := 600.0
var target: CharacterBody2D
var world_bounds := Rect2(0, 0, 2600, 720)
var authored_bounds := Rect2()
var center_on_target := false
var follow_character_during_traversal := false

func follows_character() -> bool:
	return center_on_target or (follow_character_during_traversal and not authored_bounds.has_area())

static func bounded_center(desired: Vector2, view_size: Vector2, bounds: Rect2) -> Vector2:
	var half := view_size * 0.5
	var result := bounds.get_center()
	if bounds.size.x >= view_size.x:
		result.x = clampf(desired.x, bounds.position.x + half.x, bounds.end.x - half.x)
	if bounds.size.y >= view_size.y:
		result.y = clampf(desired.y, bounds.position.y + half.y, bounds.end.y - half.y)
	return result

func _ready() -> void:
	position_smoothing_enabled = false
	get_viewport().size_changed.connect(snap_to_target)
	snap_to_target()

func active_bounds() -> Rect2:
	return authored_bounds if authored_bounds.has_area() else world_bounds

func desired_center() -> Vector2:
	var ahead := clampf(target.velocity.x * look_ahead_seconds, -maximum_look_ahead, maximum_look_ahead)
	return target.global_position + Vector2(ahead, -80)

func snap_to_target() -> void:
	if not is_instance_valid(target): return
	global_position = Vector2(target.global_position.x, active_bounds().get_center().y) if follows_character() else bounded_center(desired_center(), get_viewport_rect().size / zoom, active_bounds())
	force_update_scroll()

func set_authored_bounds(bounds: Rect2, follow_character: bool = false) -> void:
	# For a region narrower than the view, center it; content must mask/restrict
	# side reveals separately. This API does not claim encounter isolation.
	authored_bounds = bounds
	# Character-centered staging relies on the encounter masks to conceal
	# outside scenery, instead of clamping the camera away from the player.
	center_on_target = follow_character and bounds.has_area()
	snap_to_target()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target): return
	if follows_character():
		snap_to_target()
		return
	var desired := global_position.move_toward(desired_center(), follow_speed * delta)
	global_position = bounded_center(desired.round(), get_viewport_rect().size / zoom, active_bounds())
