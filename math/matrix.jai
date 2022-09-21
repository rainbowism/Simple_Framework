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
