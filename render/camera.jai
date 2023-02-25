Camera :: struct {
    position: Vector2;
    offset:   Vector2;
    rotation: float;
    zoom:     float = 1.0;
}

get_camera_matrix :: (using camera: Camera) -> Matrix4 {
    m := make_rotate_matrix4(.{0, 0, 1}, rotation);
    // m := make_rotate_matrix4(rotation);
    m *= make_scale_matrix4(zoom);
    m *= make_translation_matrix4(-position);
    m  = make_translation_matrix4(offset) * m;

    return m;
}

get_camera_bounds :: (using camera: Camera, canvas_size: Vector2) -> SAT_Rect {
    transform := make_xform(position, rotation, Vector2.{1.0, 1.0} / zoom);
    r: SAT_Rect = ---;
    r.tl = xform(transform, -offset);
    r.tr = xform(transform, .{canvas_size.x - offset.x, -offset.y});
    r.bl = xform(transform, .{-offset.x, canvas_size.y - offset.y});
    r.br = xform(transform, canvas_size - offset);
    return r;
}

get_xform :: inline (using camera: Camera) -> Transform {
    return make_xform(position, rotation, Vector2.{1.0, 1.0} / zoom);
}

get_xform_inv :: inline (using camera: Camera) -> Transform {
    transform := make_xform(position, rotation, Vector2.{1.0, 1.0} / zoom);
    affine_inverse(*transform);
    return transform;
}
