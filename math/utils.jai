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

is_approx_equal :: inline (a: Vector2, b: Vector2, $epsilon: float = 0.00001) -> bool #must {
    if a == b  return true; // Handle infinity cases.
    return length_squared(abs(a - b)) < epsilon;
}

is_approx_zero :: inline (value: Vector2, $epsilon: float = 0.00001) -> bool #must {
    return abs(value.x) < epsilon && abs(value.y) < epsilon;
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
