Transform :: struct {
    _11: float = 1.0;
    _12: float;
    _21: float;
    _22: float = 1.0;
    _31: float;
    _32: float;

#place _11;
    x_basis:  Vector2 = ---;
    y_basis:  Vector2 = ---;
    position: Vector2 = ---;
#place _11;
    columns: [3] Vector2 = ---;
#place _11;
    floats: [6] float = ---;
}

Transform_Identity :: Transform.{1, 0, 0, 1, 0, 0};

tdotx :: inline (using transform: Transform, v: Vector2)  -> float #must { return _11 * v.x + _21 * v.y; }
tdoty :: inline (using transform: Transform, v: Vector2)  -> float #must { return _12 * v.x + _22 * v.y; }
tdotx :: inline (using transform: *Transform, v: Vector2) -> float #must { return _11 * v.x + _21 * v.y; }
tdoty :: inline (using transform: *Transform, v: Vector2) -> float #must { return _12 * v.x + _22 * v.y; }
basis_determinant :: inline (using transform: Transform)  -> float #must { return _11 * _22 - _12 * _21; }

make_xform :: (position: Vector2, x_basis: Vector2, y_basis: Vector2) -> Transform #must {
    r: Transform = ---;
    r.x_basis = x_basis;
    r.y_basis = y_basis;
    r.position = position;
    return r;
}

make_xform :: (position: Vector2, theta: float) -> Transform #must {
    r: Transform = ---;
    r._11 = tcos(theta);
    r._12 = tsin(theta);
    r._21 = -r._12;
    r._22 =  r._11;
    r.position = position;
    return r;
}

make_xform :: (position: Vector2, theta: float, scale: Vector2) -> Transform #must {
    r: Transform = ---;
    r._11 =  tcos(theta) * scale.x;
    r._12 =  tsin(theta) * scale.x;
    r._21 = -tsin(theta) * scale.y;
    r._22 =  tcos(theta) * scale.y;
    r.position = position;
    return r;
}

make_xform :: (position: Vector2, theta: float, scale: Vector2, skew: float) -> Transform #must {
    r: Transform = ---;
    r._11 =  tcos(theta)        * scale.x;
    r._12 =  tsin(theta)        * scale.x;
    r._21 = -tsin(theta + skew) * scale.y;
    r._22 =  tcos(theta + skew) * scale.y;
    r.position = position;
    return r;
}

inverse :: (transform: *Transform) {
    value        := transform._12;
    transform._12 = transform._21;
    transform._21 = value;
    transform.position = inline basis_xform(transform, -transform.position);
}

affine_inverse :: (transform: *Transform) {
    determinant     := basis_determinant(transform);
    inv_determinant := 1.0 / determinant;

    value        := transform._11;
    transform._11 = transform._22;
    transform._22 = value;
    transform.x_basis *= Vector2.{ inv_determinant, -inv_determinant};
    transform.y_basis *= Vector2.{-inv_determinant,  inv_determinant};
    transform.position = inline basis_xform(transform, -transform.position);
}

inverse :: (transform: Transform) -> Transform #must #expand {
    inline inverse(*transform);
    return transform;
}

affine_inverse :: (transform: Transform) -> Transform #must #expand {
    inline affine_inverse(*transform);
    return transform;
}

basis_xform :: (transform: Transform, v: Vector2) -> Vector2 #must #expand {
    r: Vector2 = ---;
    r.x = tdotx(transform, v);
    r.y = tdoty(transform, v);
    return r;
}

basis_xform_inv :: (transform: Transform, v: Vector2) -> Vector2 #must #expand {
    r: Vector2 = ---;
    r.x = dot(transform.x_basis, v);
    r.y = dot(transform.y_basis, v);
    return r;
}

xform :: (transform: Transform, v: Vector2) -> Vector2 #must #expand {
    r: Vector2 = ---;
    r.x = tdotx(transform, v);
    r.y = tdoty(transform, v);
    return r + transform.position;
}

xform_inv :: (transform: Transform, v: Vector2) -> Vector2 #must #expand {
    r: Vector2 = ---;
    r.x = dot(transform.x_basis, v - transform.position);
    r.y = dot(transform.y_basis, v - transform.position);
    return r;
}

xform_many :: (transform: Transform, v: [] Vector2) {
    for 0..v.count-1 {
        r: Vector2 = ---;
        r.x = tdotx(transform, v[it]);
        r.y = tdoty(transform, v[it]);
        v[it] = r + transform.position;
    }
}

translate_by :: inline (transform: *Transform, offset: Vector2) {
    using transform;
    _31 += tdotx(transform, offset);
    _32 += tdoty(transform, offset);
}

rotate_by :: inline (transform: *Transform, theta: float) {
    using transform;
    cost := tcos(theta);
    sint := tsin(theta);
    x_basis = .{cost * _11 + sint * _12, -sint * _11 + cost * _12};
    y_basis = .{cost * _21 + sint * _22, -sint * _21 + cost * _22};
}

scale_by :: inline (transform: *Transform, scale: Vector2) {
    using transform;
    x_basis *= scale.x;
    y_basis *= scale.y;
}

scale_by :: inline (transform: *Transform, scale: float) {
    using transform;
    x_basis *= scale;
    y_basis *= scale;
}

set_rotation_scale :: (transform: *Transform, theta: float, scale: Vector2) {
    transform._11 =  tcos(theta) * scale.x;
    transform._12 =  tsin(theta) * scale.x;
    transform._21 = -tsin(theta) * scale.y;
    transform._22 =  tcos(theta) * scale.y;
}

set_rotation_scale_skew :: (transform: *Transform, theta: float, scale: Vector2, skew: float) {
    transform._11 =  tcos(theta)        * scale.x;
    transform._12 =  tsin(theta)        * scale.x;
    transform._21 = -tsin(theta + skew) * scale.y;
    transform._22 =  tcos(theta + skew) * scale.y;
}

set_rotation_scale :: (transform: Transform, theta: float, scale: Vector2) -> Transform #must #expand {
    inline set_rotation_scale(*transform, theta, scale);
    return transform;
}

set_rotation_scale_skew :: (transform: Transform, theta: float, scale: Vector2, skew: float) -> Transform #must #expand {
    inline set_rotation_scale_skew(*transform, theta, scale, skew);
    return transform;
}

operator * :: (left: Transform, right: Transform) -> Transform #must {
    r := left;
    r.position = xform(r, right.position);
    x0 := tdotx(r, right.x_basis);
    x1 := tdoty(r, right.x_basis);
    y0 := tdotx(r, right.y_basis);
    y1 := tdoty(r, right.y_basis);
    r._11 = x0;
    r._12 = x1;
    r._21 = y0;
    r._22 = y1;
    return r;
}

get_rotation :: (transform: Transform) -> float #must #expand {
    return tatan2(transform._12, transform._11);
}

get_scale :: (transform: Transform) -> Vector2 #must {
    determinant := basis_determinant(transform);
    r: Vector2 = ---;
    r.x = length(transform.x_basis);
    r.y = length(transform.y_basis) * sign(determinant);
    return r;
}

get_skew :: (transform: Transform) -> float #must {
    determinant := basis_determinant(transform);
    // @Todo(sushi): Remove factors of PI.
    // return acos(dot(unit_vector(transform.x_basis), sign(determinant) * unit_vector(transform.y_basis))) * INV_PI - 0.5;
    return 0.0;
}

test_transform :: () {
    for 1..20 {
        theta := cast(float) it * 0.1;
        info("rotation: % = %", theta, get_rotation(make_xform(.{0, 0}, theta)));
        info("scale:    % = %", theta, get_scale(make_xform(.{0, 0}, 0, .{theta, theta})));
    }
}
