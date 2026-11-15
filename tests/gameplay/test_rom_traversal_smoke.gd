extends SceneTree
const Player = preload("res://scripts/gameplay/rom_terrain_player.gd")
const Explorer = preload("res://scripts/gameplay/aiz_terrain_explorer.gd")
func _initialize() -> void:
    run.call_deferred()
func run() -> void:
    var p = Player.new()
    root.add_child(p)
    p.configure({}, Vector2(100, 100))
    p.simulate(1.0 / 60.0, 1.0, false)
    assert(p.world_position.x > 100.0)
    assert(p.world_position.y > 100.0)
    p.free()
    var explorer = Explorer.new()
    assert(explorer.view_size.y == 224)
    explorer.free()
    print("ROM traversal scripts loaded; airborne movement smoke: PASS")
    quit(0)
