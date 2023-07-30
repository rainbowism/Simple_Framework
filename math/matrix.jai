make_ortho_matrix :: (left: float, right: float, bottom: float, top: float, near: float, far: float, $depth_range_01 := false) -> Matrix4 {
    m: Matrix4;

    m._11 = 2.0 / (right - left);
    m._14 = -(right + left) / (right - left);

    m._22 = 2.0 / (top - bottom);
    m._24 = -(top + bottom) / (top - bottom);

    #if depth_range_01 {
        // To map -1,1 depth range to 0,1 we transform z as follows: z' = z * 0.5 + 0.5
        m._33 = (-2 / (far - near)) * 0.5            + m._43 * 0.5;
        m._34 = (-(far + near) / (far - near)) * 0.5 + m._44 * 0.5;
    } else {
        m._33 = -2 / (far - near);
        m._34 = -(far + near) / (far - near);
    }

    m._44 = 1.0;

    return m;
}

make_translation_matrix4 :: (v: Vector2) -> Matrix4 #must {
    m := Matrix4_Identity;

    m._14 = v.x;
    m._24 = v.y;

    return m;
}

make_scale_matrix4 :: (v: Vector2) -> Matrix4 #must {
    m := Matrix4_Identity;

    m._11 = v.x;
    m._22 = v.y;

    return m;
}

make_scale_matrix4 :: (scale: float) -> Matrix4 #must {
    m := Matrix4_Identity;

    m._11 = scale;
    m._22 = scale;

    return m;
}

make_rotate_matrix4 :: (axis: Vector3, theta: float) -> Matrix4 #must {
    m: Matrix4 = ---;

    normalized := unit_vector(axis);
    using normalized;

    cos_res := tcos(theta);
    sin_res := tsin(theta);
    t      := 1.0 - cos_res;

    m._11 = x * x * t +     cos_res;
    m._12 = y * x * t + z * sin_res;
    m._13 = z * x * t - y * sin_res;
    m._14 = 0.0;

    m._21 = x * y * t - z * sin_res;
    m._22 = y * y * t +     cos_res;
    m._23 = z * y * t + x * sin_res;
    m._24 = 0.0;

    m._31 = x * z * t + y * sin_res;
    m._32 = y * z * t - x * sin_res;
    m._33 = z * z * t +     cos_res;
    m._34 = 0.0;

    m._41 = 0.0;
    m._42 = 0.0;
    m._43 = 0.0;
    m._44 = 1.0;

    return m;
}

make_rotate_matrix4 :: (using euler: Vector3) -> Matrix4 #must {
    m: Matrix4 = ---;

    cos_x := tcos(euler.x);
    sin_x := tsin(euler.x);
    cos_y := tcos(euler.y);
    sin_y := tsin(euler.y);
    cos_z := tcos(euler.z);
    sin_z := tsin(euler.z);

    m._11 =  cos_z * cos_y;
    m._12 = (cos_z * sin_y * sin_x) - (sin_z * cos_x);
    m._13 = (cos_z * sin_y * cos_x) + (sin_z * sin_x);
    m._14 = 0.0;

    m._21 =  sin_z * cos_y;
    m._22 = (sin_z * sin_y * sin_x) + (cos_z * cos_x);
    m._23 = (sin_z * sin_y * cos_x) - (cos_z * sin_x);
    m._24 = 0.0;

    m._31 = -sin_y;
    m._32 = cos_y * sin_x;
    m._33 = cos_y * cos_x;
    m._34 = 0.0;

    m._41 = 0.0;
    m._42 = 0.0;
    m._43 = 0.0;
    m._44 = 1.0;

    transpose(*m);

    return m;
}

translate :: (m: Matrix4, t: Vector2) -> Matrix4 #must {
    result := m;
    inline translate(*result, t);
    return result;
}

translate :: (m: *Matrix4, t: Vector2) {
    m._14 += m._11 * t.x + m._12 * t.y;
    m._24 += m._21 * t.x + m._22 * t.y;
    m._34 += m._31 * t.x + m._32 * t.y;
    m._44 += m._41 * t.x + m._42 * t.y;
}

rotate :: (m: Matrix4, axis: Vector3, theta: float) {
    rotate_matrix: Matrix4 = ---;

    normalized := unit_vector(axis);
    using normalized;

    cos_res := tcos(theta);
    sin_res := tsin(theta);
    t       := 1.0 - cos_res;

    rotate_matrix._11 = x * x * t +     cos_res;
    rotate_matrix._12 = y * x * t + z * sin_res;
    rotate_matrix._13 = z * x * t - y * sin_res;
    rotate_matrix._14 = 0.0;

    rotate_matrix._21 = x * y * t - z * sin_res;
    rotate_matrix._22 = y * y * t +     cos_res;
    rotate_matrix._23 = z * y * t + x * sin_res;
    rotate_matrix._24 = 0.0;

    rotate_matrix._31 = x * z * t + y * sin_res;
    rotate_matrix._32 = y * z * t - x * sin_res;
    rotate_matrix._33 = z * z * t +     cos_res;
    rotate_matrix._34 = 0.0;

    rotate_matrix._41 = 0.0;
    rotate_matrix._42 = 0.0;
    rotate_matrix._43 = 0.0;
    rotate_matrix._44 = 1.0;

    return inline multiply(m, rotate_matrix);
}

scale_xy :: (m: *Matrix4, scale: float) {
    m._11 *= scale;
    m._21 *= scale;
    m._31 *= scale;

    m._12 *= scale;
    m._22 *= scale;
    m._32 *= scale;
}
