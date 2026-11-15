extends RefCounted

## Presentation-only geometry. Original collision and gameplay coordinates do not scale.
static func region_size(viewport: Vector2) -> Vector2i:
    if viewport.x <= 0.0 or viewport.y <= 0.0:
        return Vector2i(320, 224)
    return Vector2i(maxi(320, ceili(224.0 * viewport.x / viewport.y)), 224)

static func clamp_origin(origin: Vector2i, view: Vector2i, level: Vector2i) -> Vector2i:
    return Vector2i(
        clampi(origin.x, 0, maxi(level.x - view.x, 0)),
        clampi(origin.y, 0, maxi(level.y - view.y, 0))
    )
