
// Turn versions of cephes

tsin :: (x: float32) -> float32 #must { return cast(float32) tsin(cast(float64) x); }
tcos :: (x: float32) -> float32 #must { return cast(float32) tcos(cast(float64) x); }

tsin :: (x: float64) -> float64 #must { return inline tsin_or_cos(x, true); }
tcos :: (x: float64) -> float64 #must { return inline tsin_or_cos(x, false); }

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
