package graphics

import "core:math/linalg"

Transform :: struct {
    position: linalg.Vector2f32,
    pivot:    linalg.Vector2f32,
    scale:    linalg.Vector2f32,
    rotation: f32,
}

InitTransform :: proc(transform: ^Transform) {
    transform.position = linalg.Vector2f32{0, 0}
    transform.pivot    = linalg.Vector2f32{0, 0}
    transform.scale    = linalg.Vector2f32{1, 1}
    transform.rotation = 0
}
