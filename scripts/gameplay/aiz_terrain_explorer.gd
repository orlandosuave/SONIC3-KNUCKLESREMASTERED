extends Node2D

const Terrain = preload("res://scripts/rom/rom_terrain_decoder.gd")
const Session = preload("res://scripts/gameplay/aiz_terrain_session.gd")
const VIEW_SIZE := Vector2i(320, 224)
const SCROLL_STEP := 16
var origin := Vector2i(0x1995, 0x3B0)
var foreground: Texture2D
var background: Texture2D
var status: Label

func _ready() -> void:
    if not Session.bundle.get("ok", false):
        call_deferred("_return_to_menu")
        return
    status = Label.new()
    status.position = Vector2(8, 8)
    status.add_theme_color_override("font_color", Color.WHITE)
    add_child(status)
    _render()

func _return_to_menu() -> void:
    get_tree().change_scene_to_file("res://scenes/main.tscn")

func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    if event.keycode == KEY_ESCAPE:
        get_tree().change_scene_to_file("res://scenes/main.tscn")
        return
    var direction := Vector2i.ZERO
    match event.keycode:
        KEY_LEFT, KEY_A: direction.x = -1
        KEY_RIGHT, KEY_D: direction.x = 1
        KEY_UP, KEY_W: direction.y = -1
        KEY_DOWN, KEY_S: direction.y = 1
    if direction == Vector2i.ZERO:
        return
    var layer: Dictionary = Session.bundle["foreground"]
    var limit := Vector2i(int(layer["width_chunks"]) * 128, int(layer["height_chunks"]) * 128) - VIEW_SIZE
    origin = Vector2i(clampi(origin.x + direction.x * SCROLL_STEP, 0, maxi(limit.x, 0)), clampi(origin.y + direction.y * SCROLL_STEP, 0, maxi(limit.y, 0)))
    _render()

func _render() -> void:
    var region := Rect2i(origin, VIEW_SIZE)
    var fg := Terrain.render_region(Session.bundle, "foreground", region)
    var bg := Terrain.render_region(Session.bundle, "background", region)
    if not fg.get("ok", false):
        status.text = "Terrain: " + str(fg.get("error", "render failed"))
        return
    foreground = ImageTexture.create_from_image(fg["image"])
    background = ImageTexture.create_from_image(bg["image"]) if bg.get("ok", false) else null
    status.text = "Angel Island Act 1 | X %d Y %d | Arrows/WASD: scroll | Esc: menu" % [origin.x, origin.y]
    queue_redraw()

func _draw() -> void:
    var viewport_size := get_viewport_rect().size
    var scale_factor: float = maxf(1.0, floorf(minf(viewport_size.x / VIEW_SIZE.x, viewport_size.y / VIEW_SIZE.y)))
    var rect := Rect2((viewport_size - Vector2(VIEW_SIZE) * scale_factor) / 2.0, Vector2(VIEW_SIZE) * scale_factor)
    draw_rect(rect, Color("152941"))
    if background != null:
        draw_texture_rect(background, rect, false)
    if foreground != null:
        draw_texture_rect(foreground, rect, false)
