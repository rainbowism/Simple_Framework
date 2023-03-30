Camera :: struct {
    position: Vector2;
    offset:   Vector2;
    rotation: float;
    zoom:     float = 1.0;
}

get_camera_bounds :: (using camera: Camera, canvas_size: Vector2) -> SAT_Rect {
    transform := make_xform(position, rotation, .{1.0, 1.0} / zoom);
    r: SAT_Rect = ---;
    r.tl = xform(transform, -offset);
    r.tr = xform(transform, .{canvas_size.x - offset.x, -offset.y});
    r.bl = xform(transform, .{-offset.x, canvas_size.y - offset.y});
    r.br = xform(transform, canvas_size - offset);
    return r;
}

get_xform :: inline (using camera: Camera) -> Transform {
    transform := make_xform(offset, rotation, Vector2.{zoom, zoom});
    translate(*transform, -position);
    return transform;
}

get_xform_inv :: inline (using camera: Camera) -> Transform {
    transform := get_xform(camera);
    affine_inverse(*transform);
    return transform;
}
