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
