Transform :: struct {
    _11: float = 1.0;
    _12: float;
    _21: float;
    _22: float = 1.0;
    _31: float;
    _32: float;
#place _11;
    columns: [3] Vector2;
#place _11;
    floats: [6] float;
#place _11;
    x_basis: Vector2;
#place _21;
    y_basis: Vector2;
#place _31;
    position: Vector2;
}

tdotx :: inline (using transform: Transform, v: Vector2) -> float #must { return _11 * v.x + _21 * v.y; }
tdoty :: inline (using transform: Transform, v: Vector2) -> float #must { return _12 * v.x + _22 * v.y; }
basis_determinant :: inline (using transform: Transform) -> float #must { return _11 * _22 - _12 * _21; }

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
    return transform;
}

make_xform :: (position: Vector2, x_basis: Vector2, y_basis: Vector2) -> Transform #must {
    r: Transform = ---;
    r.x_basis = x_basis;
    r.y_basis = y_basis;
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

basis_xform :: (transform: Transform, v: Vector2) -> Vector2 #must {
    r: Vector2 = ---;
    r.x = tdotx(transform, v);
    r.y = tdoty(transform, v);
    return r;
}

basis_xform_inv :: (transform: Transform, v: Vector2) -> Vector2 #must {
    r: Vector2 = ---;
    r.x = dot(transform.x_basis, v);
    r.y = dot(transform.y_basis, v);
    return r;
}

xform :: (transform: Transform, v: Vector2) -> Vector2 #must {
    r: Vector2 = ---;
    r.x = tdotx(transform, v);
    r.y = tdoty(transform, v);
    return r + transform.position;
}

xform_inv :: (transform: Transform, v: Vector2) -> Vector2 #must {
    r: Vector2 = ---;
    r.x = dot(transform.x_basis, v - transform.position);
    r.y = dot(transform.y_basis, v - transform.position);
    return r;
}

set_rotation_scale :: (transform: Transform, theta: float, scale: Vector2) -> Transform #must {
    r: Transform = ---;
    r._11 =  tcos(theta) * scale.x;
    r._12 =  tsin(theta) * scale.x;
    r._21 = -tsin(theta) * scale.y;
    r._22 =  tcos(theta) * scale.y;
    r.position = transform.position;
    return transform;
}

set_rotation_scale_skew :: (transform: Transform, theta: float, scale: Vector2, skew: float) -> Transform #must {
    r: Transform = ---;
    r._11 =  tcos(theta)        * scale.x;
    r._12 =  tsin(theta)        * scale.x;
    r._21 = -tsin(theta + skew) * scale.y;
    r._22 =  tcos(theta + skew) * scale.y;
    r.position = transform.position;
    return transform;
}

inverse :: (transform: Transform) -> Transform #must {
    r := transform;
    value := r._12;
    r._12  = r._21;
    r._21  = value;
    r.position = inline basis_xform(r, -r.position);
    return r;
}

affine_inverse :: (transform: Transform) -> Transform #must {
    determinant     := basis_determinant(transform);
    inv_determinant := 1.0 / determinant;

    r := transform;
    value := r._11;
    r._11  = r._22;
    r._22  = value;
    r.x_basis *= Vector2.{ inv_determinant, -inv_determinant};
    r.y_basis *= Vector2.{-inv_determinant,  inv_determinant};
    r.position = inline basis_xform(r, -r.position);
    return r;
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

get_rotation :: (transform: Transform) -> float #must {
    // @Todo(sushi): Remove factors of PI.
    return atan2(transform._12 * PI, transform._11 * PI) * INV_PI;
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
	return acos(dot(unit_vector(transform.x_basis), sign(determinant) * unit_vector(transform.y_basis))) * INV_PI - 0.5;
}