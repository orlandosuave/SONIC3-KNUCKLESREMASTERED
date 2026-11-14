extends Control
## Draw above the world, below the HUD, using the actual camera transform.
var arena := Rect2(1200, 0, 1280, 720)
var entrance_x := 1280.0
var stage := 0 # 0: conceal ahead; 1: isolate arena; 2: released

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func visible_horizontal_range() -> Vector2:
	var transform := get_viewport().get_canvas_transform()
	var width := get_viewport_rect().size.x
	if stage == 0:
		return Vector2(0, clampf((transform * Vector2(entrance_x, 0)).x, 0, width))
	if stage == 1:
		return Vector2(clampf((transform * arena.position).x, 0, width),
			clampf((transform * arena.end).x, 0, width))
	return Vector2(0, width)

func _draw() -> void:
	var view := get_viewport_rect().size
	var span := visible_horizontal_range()
	draw_rect(Rect2(0, 0, span.x, view.y), Color("101827"))
	draw_rect(Rect2(span.y, 0, view.x - span.y, view.y), Color("101827"))
