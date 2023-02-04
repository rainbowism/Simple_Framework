operator - :: (a: Vector2) -> Vector2 {
    r: Vector2 = ---;
    r.x = -a.x;
    r.y = -a.y;
    return r;
}

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

// Turn versions of cephes

tsin :: (x: float32) -> float32 #must { return cast(float32) tsin(cast(float64) x); }
tcos :: (x: float32) -> float32 #must { return cast(float32) tcos(cast(float64) x); }
// tatan :: inline (y: float32) -> float32 { return cast(float32) atan(cast(float64)y); }

//
// We worked on this code a bunch to make it faster than base Cephes, and we did --
// by a more-than-2x speedup. However, now we are in a place where we are still
// slower than the Windows libc version, and it looks like the bottleneck now
// is just how much math we are doing. So maybe it would be fruitful to look
// at a different algorithm at this point, for something that approximates
// with fewer multiply-adds in some way.
//
// Alternatively, it seems we are still spending a fair chunk of CPU power just
// to do an fmod on x, essentially. So, if we had a faster way of doing that,
// we would be pretty good. Note that even though we have this variable j that
// is limited to a small positive number, for the math shown here, y has to stay big
// because x is big. That seems like an opportunity to fix something.
//
//    -jblow, 30 June 2020
//

tsin_or_cos :: (x: float64, $IS_SIN: bool) -> float64 #must {
    #if IS_SIN  if x == 0 return x;

    sf := << cast(*s64)*x;
    exponent := cast(s32) ((sf >> 52) & 0x7ff);
    if exponent == 0x7ff {  // It is nan or inf. Replace with an intrinsic.
        if isnan(x) return x;  // @Cleanup: Redundancies...

        // It's not nan, so it's inf.

        // :MathError
        // @Incomplete: Do we signal errors in any other way? Programmer-only error log?
	    // mtherr( "sin", DOMAIN );
	    return FLOAT64_NAN;
    }

    /* make argument positive but save the sign */
    negate : s64 = 0;
    {
        //
        // The code here was:
        //
        //   if x < 0 {   // We could do a branch-free negate here if we really wanted to, like we do on returning, but ... is it worth it?
	    //       x = -x;
	    //       #if IS_SIN  negate = 1;
	    //   }
        //
        // But we wanted to do it in a branch-free way, so, you see the below:
        //
        flint: FloatInt64 = ---;
        flint._float64 = x;
        #if IS_SIN  negate = xx(flint._u64 >> 63);
        flint._u64 &= 0x7fff_ffff_ffff_ffff;
        x = flint._float64;
    }


    if x > LOSSTH {
        // :MathError
	    // mtherr( "sin", TLOSS );
	    return 0;
	}


    // We know x is not negative.
    // So taking the floor is the same as casting to int (casts round toward 0,
    // but when you're always positive, that is the floor).
    // Here we cast to s64, which will not preserve input angles greater than
    // 2**64, but, we don't have enough precision up there to sensibly perform
    // trig anyway -- and this algorithm already bailed out if the input angle
    // is higher than LOSSTH, which is only about 1 billion, way less than
    // 2**64.
    j := cast(s64)(x*4.0);

    /* map zeros to origin */
    j += (j & 1);

    y := cast(float64) j;

    j = j & 0b111; /* octant modulo 360 degrees */  // But, the low bit actually cannot be 1, since we made j even above, so we could have masked by 0b110.

    // The code below used to be:
    //
    // if j > 3 {
	//    negate ^= 1;
	//    j -= 4;
    // }
    //
    // But we wanted to get rid of the 'if' statement, for performance, because
    // the branch predictor might have problems with it in many use cases.
    //
    // If j > 3, then j & 4, and furthermore, no higher bits are set on j.
    // So if we want to toggle 'negate' iff j > 3, we xor it with (j >> 2).
    // j -= 4 is the same as masking j & 2.
    //

    /* reflect in x axis */

    negate ^= (j >> 2);
    j = j & 2;  // Semi-redundant with & 6 above?!?

    // When we get to this point, j can only be 0 or 2.
    // Each increment of j represents 45 degrees, so 0 and 2 are one quadrant apart.
    // sin and cos want the same behavior, offset by one quadrant.
    #if !IS_SIN {
        // Here we wanted to do:
        //     if j  negate ^= 1;
        // But j can only be 2 or 0, so we toggle by j >> 1.
        negate ^= (j >> 1);
        j = xx !j;   // Should get optimized out alongside the if below.
    }

    /* Extended precision modular arithmetic */

    z := (((x * PI) - y * DP1) - y * DP2) - y * DP3;
    zz := z * z;

    r: float64 = ---;
    if j  r = 1.0 - zz*.5 + zz * zz * polynomial_eval_coscof5(zz);
	else  r = z  +  z * (zz * polynomial_eval_sincof5(zz));

    //
    // The code here to return the value was:
    //
    //    if negate  return -r;
    //    return r;
    //
    // But we want to return in a branch-free way, so, we do the thing
    // where we toggle the sign bit of the result if negate is 1.
    //
    flint: FloatInt64 = ---;
    flint._float64 = r;
    flint._u64 ^= xx(negate << 63);
    return flint._float64;
}

tsin :: (x: float64) -> float64 #must { return inline tsin_or_cos(x, true); }

tcos :: (x: float64) -> float64 #must { return inline tsin_or_cos(x, false); }

#scope_file

FloatInt64 :: union {
    _u64:     u64;
    _s64:     s64;
    _float64: float64;
}

polynomial_eval_coscof5 :: inline (x: float64) -> float64 #must {
    x2 := x*x;
    x4 := x2*x2;

    return (-1.13585365213876817300E-11*x + 2.08757008419747316778E-9)*x4 +
           (-2.75573141792967388112E-7*x  + 2.48015872888517045348E-5)*x2 +
            -1.38888888888730564116E-3*x  + 4.16666666666665929218E-2;
}

polynomial_eval_sincof5 :: inline (x: float64) -> float64 #must {
    x2 := x*x;
    x4 := x2*x2;

    return (1.58962301576546568060E-10*x -  2.50507477628578072866E-8)*x4 +
           (2.75573136213857245213E-6*x  -  1.98412698295895385996E-4)*x2 +
            8.33333333332211858878E-3*x  -  1.66666666666666307295E-1;
}

#import "Math";
