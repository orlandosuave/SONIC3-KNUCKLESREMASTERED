extends Node2D
## First playable ROM-grounded traversal slice. All coordinates remain ROM world pixels.
const Collision = preload("res://scripts/gameplay/rom_terrain_collision.gd")
var bundle: Dictionary = {}
var world_position := Vector2.ZERO
var horizontal_speed := 0.0
var vertical_speed := 0.0
var grounded := false
var ground_angle := 0
const ACCEL := 168.75
const MAX_SPEED := 360.0
const GRAVITY := 787.5
const JUMP_SPEED := -390.0
const FEET_OFFSET := 18.0

func configure(terrain: Dictionary, spawn: Vector2) -> void:
    bundle = terrain
    world_position = spawn

func simulate(delta: float, direction: float, jump: bool) -> void:
    horizontal_speed = move_toward(horizontal_speed, direction * MAX_SPEED, ACCEL * delta if direction != 0.0 else 400.0 * delta)
    if jump and grounded:
        vertical_speed = JUMP_SPEED
        grounded = false
    vertical_speed += GRAVITY * delta
    world_position += Vector2(horizontal_speed, vertical_speed) * delta
    if vertical_speed < 0.0:
        return
    var probe := Collision.find_floor(bundle, Vector2i(roundi(world_position.x), roundi(world_position.y + FEET_OFFSET)))
    if not probe.get("ok", false):
        return
    var distance := float(probe.get("distance", 1000))
    if distance <= 6.0 and distance >= -20.0:
        world_position.y += distance
        vertical_speed = 0.0
        grounded = true
        ground_angle = int(probe.get("angle", 0))
    else:
        grounded = false

func _draw() -> void:
    draw_circle(Vector2(0, -6), 13.0, Color("246bdb"))
    draw_circle(Vector2(5, -8), 4.0, Color.WHITE)
    draw_circle(Vector2(6, -8), 2.0, Color.BLACK)
    draw_line(Vector2(-9, 7), Vector2(9, 7), Color("df3434"), 5.0)
