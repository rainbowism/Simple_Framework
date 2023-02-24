INV_PI :: 1.0 / PI;

operator / :: (a: Vector2, b: int) -> Vector2 {
    r: Vector2 = ---;
    r.x = a.x / b;
    r.y = a.y / b;
    return r;
}

operator / :: (a: int, b: Vector2) -> Vector2 {
    r: Vector2 = ---;
    r.x = a / b.x;
    r.y = a / b.y;
    return r;
}

is_approx_equal :: inline (a: float, b: float) -> bool #must {
    EPSILON :: 0.00001;
    if a == b  return true; // Handle infinity cases.
    tolerance := EPSILON * abs(a);
    if tolerance < EPSILON  tolerance = EPSILON;
    return abs(a - b) < tolerance;
}

is_approx_equal :: inline (a: float, b: float, $epsilon: float = 0.00001) -> bool #must {
    if a == b  return true; // Handle infinity cases.
    return abs(a - b) < epsilon;
}

is_approx_zero :: inline (value: float, $epsilon: float = 0.00001) -> bool #must {
    return abs(value) < epsilon;
}

inv_lerp :: inline (a: float, b: float, value: float) -> float #must {
    return (value - a) / (b - a);
}

sign :: inline (v: float) -> float #must {
    if v >= 0  return 1;
    return -1;
}

floor :: inline (v: Vector2) -> Vector2 #must {
    r: Vector2 = ---;
    r.x = floor(v.x);
    r.y = floor(v.y);
    return r;
}

clamp :: (x: float, min_value: float, max_value: float) -> float #must {
    // @Fix(sushi): This should work but doesn't...
    // #asm {
    //     x === a;
    //     min_value === b;
    //     max_value === c;
    //     first: vec === 0;
    //     movss first, [x];
    //     maxss first, [min_value];
    //     minss first, [max_value];
    //     movss [x], first;
    // }
    if x < min_value  return min_value;
    if x > max_value  return max_value;
    return x;
}

round :: inline (v: float) -> float #must {
    return floor(v + 0.5);
}

round :: inline (v: Vector2) -> Vector2 #must {
    r: Vector2 = ---;
    r.x = round(v.x);
    r.y = round(v.y);
    return r;
}

smoothstep :: inline (from: float, to: float, value: float) -> float #must {
    if is_approx_equal(from, to)  return from;
    s := inline saturate(inv_lerp(from, to, value));
    return s * s * (3.0 - 2.0 * s);
}

bezier :: (p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2 #must {
    r: Vector2 = ---;
    u  := 1 - t;
    w1 := u * u;
    w2 := 2 * u * t;
    w3 := t * t;
    r.x = w1 * p1.x + w2 * p2.x + w3 * p3.x;
    r.y = w1 * p1.y + w2 * p2.y + w3 * p3.y;
    return v;
}

bezier :: (p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2, t: float) -> Vector2 #must {
    r: Vector2 = ---;
    u  := 1 - t;
    w1 := u * u * u;
    w2 := 3 * u * u * t;
    w3 := 3 * u * t * t;
    w4 := t * t * t;
    r.x = w1 * p1.x + w2 * p2.x + w3 * p3.x + w4 * p4.x;
    r.y = w1 * p1.y + w2 * p2.y + w3 * p3.y + w4 * p4.y;
    return v;
}

perpendicular :: (a: Vector2, $winding: enum { Clockwise; Counter_Clockwise; } = .Counter_Clockwise) -> Vector2 #must {
    r: Vector2 = ---;
    #if winding == .Clockwise {
        r.x =  a.y;
        r.y = -a.x;
    } else {
        r.x = -a.y;
        r.y =  a.x;
    }
    return r;
}

length_squared :: inline (a: Vector2) -> float #must {
    return a.x * a.x + a.y * a.y;
}

cross :: cross_product;

cross_product :: inline (a: Vector2, b: Vector2) -> float #must {
    return a.x * b.y - a.y * b.x;
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

    cos_res := cos(theta);
    sin_res := sin(theta);
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

    cos_x := cos(euler.x);
    sin_x := sin(euler.x);
    cos_y := cos(euler.y);
    sin_y := sin(euler.y);
    cos_z := cos(euler.z);
    sin_z := sin(euler.z);

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

    cos_res := cos(theta);
    sin_res := sin(theta);
    t      := 1.0 - cos_res;

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
