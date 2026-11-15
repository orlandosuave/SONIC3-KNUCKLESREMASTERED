extends SceneTree

var failures := 0

func check(condition: bool, detail: String) -> void:
    if not condition:
        failures += 1
        push_error(detail)

func find_button(node: Node, label: String) -> Button:
    if node is Button and node.text == label:
        return node
    for child in node.get_children():
        var result := find_button(child, label)
        if result != null:
            return result
    return null

func _initialize() -> void:
    run.call_deferred()

func run() -> void:
    var scene := load("res://scenes/main.tscn")
    check(scene != null, "Main menu scene must load")
    if scene == null:
        quit(1)
        return
    var menu: Node = scene.instantiate()
    root.add_child(menu)
    await process_frame
    var choose := find_button(menu, "Choose ROM")
    var check_rom := find_button(menu, "Check compatibility")
    var movement := find_button(menu, "Play movement prototype")
    check(check_rom != null, "Compatibility action exists")
    check(movement != null, "Movement prototype action exists")
    if check_rom != null:
        check(check_rom.disabled, "Compatibility is gated before ROM selection")
    for viewport_size in [Vector2i(1280,720), Vector2i(1920,720), Vector2i(5120,1440)]:
        root.content_scale_size = viewport_size
        await process_frame
        check(menu.is_inside_tree(), "Menu remains alive at viewport %s" % viewport_size)
    if movement != null:
        movement.pressed.emit()
        await process_frame
        await process_frame
        check(current_scene != null and current_scene.scene_file_path == "res://scenes/movement_prototype.tscn", "Movement prototype button changes scene")
    print("PHASE4_MENU_REGRESSION_FAILURES=", failures)
    quit(1 if failures else 0)
