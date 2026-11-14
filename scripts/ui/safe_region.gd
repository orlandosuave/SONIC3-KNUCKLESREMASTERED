extends Control
## Center essential UI within a configurable logical width on panoramic screens.
@export var maximum_width := 1280.0
@export var inset := 16.0

static func content_rect(view_size: Vector2, width: float, margin: float) -> Rect2:
	var safe_width := minf(view_size.x, width)
	return Rect2(Vector2((view_size.x - safe_width) * 0.5 + margin, margin),
		Vector2(maxf(0, safe_width - margin * 2), maxf(0, view_size.y - margin * 2)))

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(update_layout)
	var preferences := get_node_or_null("/root/UiPreferences")
	if preferences != null:
		preferences.changed.connect(_apply_preferences)
		_apply_preferences()
	update_layout()

func _apply_preferences() -> void:
	var preferences := get_node("/root/UiPreferences")
	maximum_width = preferences.WIDTHS[preferences.width_mode]
	inset = preferences.margin
	update_layout()

func update_layout() -> void:
	var region := content_rect(get_viewport_rect().size, maximum_width, inset)
	position = region.position
	size = region.size
