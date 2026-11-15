extends SceneTree

const Rules = preload("res://scripts/gameplay/terrain_view_rules.gd")
var failures := 0

func _initialize() -> void:
    run.call_deferred()

func run() -> void:
    var cases := {
        Vector2(320, 224): 320,
        Vector2(1280, 720): 399,
        Vector2(1920, 1080): 399,
        Vector2(3440, 1440): 536,
        Vector2(5120, 1440): 797
    }
    for screen in cases:
        var region: Vector2i = Rules.region_size(screen)
        if region != Vector2i(cases[screen], 224):
            failures += 1
            push_error("Unexpected visible terrain at %s: %s" % [screen, region])
    if Rules.region_size(Vector2.ZERO) != Vector2i(320, 224):
        failures += 1
    if Rules.clamp_origin(Vector2i(990, 800), Vector2i(797, 224), Vector2i(1280, 896)) != Vector2i(483, 672):
        failures += 1
        push_error("Widescreen origin exceeds terrain bounds")
    if Rules.clamp_origin(Vector2i(-20, -10), Vector2i(797, 224), Vector2i(1280, 896)) != Vector2i.ZERO:
        failures += 1
        push_error("Negative origin not clamped")
    if Rules.clamp_origin(Vector2i(80, 40), Vector2i(797, 224), Vector2i(320, 128)) != Vector2i.ZERO:
        failures += 1
        push_error("Viewport larger than level not centered safely")
    print("Phase 4 ultrawide terrain geometry: %d failures" % failures)
    quit(1 if failures else 0)
