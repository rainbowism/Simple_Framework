PHI :: PHI32;
PHI32 : float : 1.618034;
PHI64 :: 1.61803398874989484820458683436563811772030917980576286213544862270526046281890244970720720418939113748475;

// Turn versions of cephes

/*							sin.c
 *
 *	Circular sine
 *
 *
 *
 * SYNOPSIS:
 *
 * double x, y, sin();
 *
 * y = sin( x );
 *
 *
 *
 * DESCRIPTION:
 *
 * Range reduction is into intervals of pi/4.  The reduction
 * error is nearly eliminated by contriving an extended precision
 * modular arithmetic.
 *
 * Two polynomial approximating functions are employed.
 * Between 0 and pi/4 the sine is approximated by
 *      x  +  x**3 P(x**2).
 * Between pi/4 and pi/2 the cosine is represented as
 *      1  -  x**2 Q(x**2).
 *
 *
 * ACCURACY:
 *
 *                      Relative error:
 * arithmetic   domain      # trials      peak         rms
 *    DEC       0, 10       150000       3.0e-17     7.8e-18
 *    IEEE -1.07e9,+1.07e9  130000       2.1e-16     5.4e-17
 *
 * ERROR MESSAGES:
 *
 *   message           condition        value returned
 * sin total loss   x > 1.073741824e9      0.0
 *
 * Partial loss of accuracy begins to occur at x = 2**30
 * = 1.074e9.  The loss is not gradual, but jumps suddenly to
 * about 1 part in 10e7.  Results may be meaningless for
 * x > 2**49 = 5.6e14.  The routine as implemented flags a
 * TLOSS error for x > 2**30 and returns 0.0.
 */

/*							cos.c
 *
 *	Circular cosine
 *
 *
 *
 * SYNOPSIS:
 *
 * double x, y, cos();
 *
 * y = cos( x );
 *
 *
 *
 * DESCRIPTION:
 *
 * Range reduction is into intervals of pi/4.  The reduction
 * error is nearly eliminated by contriving an extended precision
 * modular arithmetic.
 *
 * Two polynomial approximating functions are employed.
 * Between 0 and pi/4 the cosine is approximated by
 *      1  -  x**2 Q(x**2).
 * Between pi/4 and pi/2 the sine is represented as
 *      x  +  x**3 P(x**2).
 *
 *
 * ACCURACY:
 *
 *                      Relative error:
 * arithmetic   domain      # trials      peak         rms
 *    IEEE -1.07e9,+1.07e9  130000       2.1e-16     5.4e-17
 *    DEC        0,+1.07e9   17000       3.0e-17     7.2e-18
 */

/*							sin.c	*/

/*
Cephes Math Library Release 2.8:  June, 2000
Copyright 1985, 1995, 2000 by Stephen L. Moshier
*/
/*
sincof :: float64.[
           1.58962301576546568060E-10,
           -2.50507477628578072866E-8,
           2.75573136213857245213E-6,
           -1.98412698295895385996E-4,
           8.33333333332211858878E-3,
           -1.66666666666666307295E-1,
          ];
coscof :: float64.[
           -1.13585365213876817300E-11,
           2.08757008419747316778E-9,
           -2.75573141792967388112E-7,
           2.48015872888517045348E-5,
           -1.38888888888730564116E-3,
           4.16666666666665929218E-2,
          ];
*/

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

tsin :: (x: float32) -> float32 #must { return cast(float32) tsin(cast(float64) x); }
tcos :: (x: float32) -> float32 #must { return cast(float32) tcos(cast(float64) x); }

tsin :: (x: float64) -> float64 #must { return inline tsin_or_cos(x, true); }
tcos :: (x: float64) -> float64 #must { return inline tsin_or_cos(x, false); }

tsin_or_cos :: (x: float64, $IS_SIN: bool) -> float64 #must {
    #if IS_SIN  if x == 0 return x;

    sf := << cast(*s64)*x;
    exponent := cast(s32) ((sf >> 52) & 0x7ff);
    if exponent == 0x7ff {  // It is nan or inf. Replace with an intrinsic.
        if isnan(x)  return x;  // Cleanup: Redundancies...

        // It's not nan, so it's inf.

        // :MathError
        // Incomplete: Do we signal errors in any other way? Programmer-only error log?
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


/*							atan.c
 *
 *	Inverse circular tangent
 *      (arctangent)
 *
 *
 *
 * SYNOPSIS:
 *
 * double x, y, atan();
 *
 * y = atan( x );
 *
 *
 *
 * DESCRIPTION:
 *
 * Returns radian angle between -pi/2 and +pi/2 whose tangent
 * is x.
 *
 * Range reduction is from three intervals into the interval
 * from zero to 0.66.  The approximant uses a rational
 * function of degree 4/5 of the form x + x**3 P(x)/Q(x).
 *
 *
 *
 * ACCURACY:
 *
 *                      Relative error:
 * arithmetic   domain     # trials      peak         rms
 *    DEC       -10, 10     50000       2.4e-17     8.3e-18
 *    IEEE      -10, 10      10^6       1.8e-16     5.0e-17
 *
 */

tatan :: inline (y: float32) -> float32 { return cast(float32) tatan(cast(float64)y); }

tatan :: inline (x: float64) -> float64 {
    if x == 0.0        return x * INV_PI;
    if x ==  INFINITY  return  0.5;
    if x == -INFINITY  return -0.5;

    sign: s16 = 1;

    if x < 0 {
	    sign = -1;
	    x = -x;
	}

    /* range reduction */

    flag: s16;  // Cleanup: Remove flag?

    y: float64 = ---;
    if x > T3P8 {
	    y = PIO2;
	    flag = 1;
	    x = -1/x;
	} else if x <= 0.66 {
	    y = 0;
	} else {
	    y = PIO4;
	    flag = 2;
	    x = (x-1)/(x+1);
	}

    z := x * x;
    z = z * polynomial_eval(z, P, 4) / polynomial_eval_1(z, Q, 5);

    z = x * z + x;

    if flag == 2       z += 0.5 * MOREBITS;
    else if flag == 1  z += MOREBITS;

    y += z;

    if sign < 0  return -y * INV_PI;
    return y * INV_PI;
}

/*							atan2()
 *
 *	Quadrant correct inverse circular tangent
 *
 *
 *
 * SYNOPSIS:
 *
 * double x, y, z, atan2();
 *
 * z = atan2( y, x );
 *
 *
 *
 * DESCRIPTION:
 *
 * Returns radian angle whose tangent is y/x.
 * Range -PI < z <= +PI.
 *
 *
 * ACCURACY:
 *
 *                      Relative error:
 * arithmetic   domain     # trials      peak         rms
 *    IEEE      -10, 10      10^6       2.5e-16     6.9e-17
 * See atan.c.
 *
 */

tatan2 :: (y: float, x: float) -> float { return cast(float) tatan2(cast(float64) y, cast(float64) x); }

tatan2 :: (y: float64, x: float64) -> float64 {
    //
    // Here we have some preambles to check for nans, +/- zero, and infinities.
    // Original Cephes had ifdefs so that you could compile these out.
    // If you don't care about these, you could skip them. But really, I think
    // if you don't care about these, you are likely to be using some other
    // fast atan2 approximation anyway. Hard to say!
    //

    //
    // We did a substantial amount of streamlining here to remove
    // unnecessary assignments to variables, 'else's that didn't need
    // to be there, etc!
    //
    if isnan(x)  return x * INV_PI;
    if isnan(y)  return y * INV_PI;

    if y == 0 {  // 0.0 compares as equal to -0.0, so .. yeah.
	    if signbit(y) {
		    if x > 0  return y * INV_PI;
		    if x < 0  return -1.0;

			if signbit(x)  return -1.0;
			return y * INV_PI;
		} else {
            // y is +0 if we get here.
		    if x == 0 {
			    if signbit(x) return 1.0;
			    return 0;
			}

            if x > 0   return 0;
            return 1.0;
		}
	}

    if x == 0 {
        if y > 0 return 0.5;
        return -0.5;
	}

    if x == INFINITY {
	    if y ==  INFINITY  return  0.25;
	    if y == -INFINITY  return -0.25;
	    if y < 0  	       return -0.0;

	    return 0;
	}

    if x == -INFINITY {
	    if y ==  INFINITY  return  0.75;
	    if y <= -INFINITY  return -0.75;
	    if y >= 0          return 1.0;

	    return -1.0;
	}

    if y ==  INFINITY  return  0.5;
    if y == -INFINITY  return -0.5;

    code: s16;
    if x < 0  code  = 2;
    if y < 0  code |= 1;

    if x == 0.0 {
	    if code & 1  return -0.5;
	    if y == 0    return 0;

	    return 0.5;
	}

    if y == 0 {
	    if code & 2 return 0.5;
	    return 0;
	}

    z := tatan(y/x);

    if      code == 2  z += 1.0;
    else if code == 3  z -= 1.0;

    if (z == 0) && (y < 0) z = -0.0;

    return z;
}

#scope_file

INFINITY :: FLOAT64_INFINITY;

MOREBITS :: 6.123233995736765886130e-17;

PIO2  :: 0h3ff9_21fb_5444_2d18;
PIO4  :: 0h3fe9_21fb_5444_2d18;

/* tan( 3*pi/8 ) */
T3P8 :: 2.41421356237309504880;

P :: float64.[
      0hbfec007fa1f72594,  // -8.750608600031904122785e-1
      0hc03028545b6b807a,  // -1.615753718733365076637e1
      0hc052c08c36880273,  // -7.500855792314704667340e1
      0hc05eb8bf2d05ba25,  // -1.228866684490136173410e2
      0hc0503669fd28ec8e   // -6.485021904942025371773e1
];

Q :: float64.[
      /* 1.000000000000000000000e0, */
      0h4038dbc45b14603c,  // 2.485846490142306297962e1
      0h4064a0dd43b8fa25,  // 1.650270098316988542046e2
      0h407b0e18d2e2be3b,  // 4.328810604912902668951e2
      0h407e563f13b049ea,  // 4.853903996359136964868e2
      0h4068519efbbd62ec   // 1.945506571482613964425e2
];

FloatInt64 :: union {
    _u64:     u64;
    _s64:     s64;
    _float64: float64;
}

polynomial_eval :: inline (x: float64, coef: [] float64, $N: s32) -> float64 {
    ans := coef[0];

    for 1..N  ans = ans * x + coef[it];

    return ans;
}

polynomial_eval_1 :: inline (x: float64, coef: [] float64, $N: s32) -> float64 {
    ans := x + coef[0];

    for 1..N-1  ans = ans * x + coef[it];

    return ans;
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

signbit :: inline (x: float64) -> u64 {
    value: FloatInt64 = ---;
    value._float64 = x;
    return value._u64 & 0x8000_0000_0000_0000;
}
