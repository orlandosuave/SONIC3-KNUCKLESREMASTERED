extends Node2D

const Terrain = preload("res://scripts/rom/rom_terrain_decoder.gd")
const Session = preload("res://scripts/gameplay/aiz_terrain_session.gd")
const WORLD_HEIGHT := 224
const ViewRules = preload("res://scripts/gameplay/terrain_view_rules.gd")
const Collision = preload("res://scripts/gameplay/rom_terrain_collision.gd")
const RomPlayer = preload("res://scripts/gameplay/rom_terrain_player.gd")
var view_size := Vector2i(320, WORLD_HEIGHT)
const SCROLL_STEP := 16
var origin := Vector2i(0x1995, 0x3B0)
var foreground: Texture2D
var background: Texture2D
var status: Label
var sonic: Node2D
var follow_sonic := true

func _ready() -> void:
    if not Session.bundle.get("ok", false):
        call_deferred("_return_to_menu")
        return
    status = Label.new()
    status.position = Vector2(8, 8)
    status.add_theme_color_override("font_color", Color.WHITE)
    add_child(status)
    get_viewport().size_changed.connect(_on_viewport_resized)
    _on_viewport_resized()

func _on_viewport_resized() -> void:
    var screen := get_viewport_rect().size
    if screen.y <= 0.0:
        return
    view_size = ViewRules.region_size(screen)
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
    var limit := Vector2i(int(layer["width_chunks"]) * 128, int(layer["height_chunks"]) * 128) - view_size
    origin = Vector2i(clampi(origin.x + direction.x * SCROLL_STEP, 0, maxi(limit.x, 0)), clampi(origin.y + direction.y * SCROLL_STEP, 0, maxi(limit.y, 0)))
    _render()

func _render() -> void:
    var region := Rect2i(origin, view_size)
    var fg := Terrain.render_region(Session.bundle, "foreground", region)
    var bg := Terrain.render_region(Session.bundle, "background", region)
    if not fg.get("ok", false):
        status.text = "Terrain: " + str(fg.get("error", "render failed"))
        return
    foreground = ImageTexture.create_from_image(fg["image"])
    background = ImageTexture.create_from_image(bg["image"]) if bg.get("ok", false) else null
    var probe_point := origin + Vector2i(view_size.x / 2, view_size.y / 2)
    var floor_probe := Collision.find_floor(Session.bundle, probe_point)
    var floor_info := "unavailable"
    if floor_probe.get("ok", false):
        floor_info = "distance %s angle %s" % [str(floor_probe.get("distance", "?")), str(floor_probe.get("angle", "?"))]
    status.text = "Angel Island Act 1 | X %d Y %d | Center floor: %s | Arrows: move | Enter: jump | Shift+arrows: pan | F: follow | Esc: menu" % [origin.x, origin.y, floor_info]
    queue_redraw()

func _draw() -> void:
    var viewport_size := get_viewport_rect().size
    var scale_factor: float = viewport_size.y / float(WORLD_HEIGHT)
    var rect := Rect2((viewport_size - Vector2(view_size) * scale_factor) / 2.0, Vector2(view_size) * scale_factor)
    draw_rect(rect, Color("152941"))
    if background != null:
        draw_texture_rect(background, rect, false)
    if foreground != null:
        draw_texture_rect(foreground, rect, false)
