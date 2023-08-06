#if !Disable_Render {
    // generate_fractal :: (seed: s64, size: s32,
    //     octaves := 3,
    //     period := 64.0,
    //     persistence := 0.5,
    //     lacunarity := 2.0
    // ) -> Texture {
    //     contexts := NewArray(octaves, *osn_context);
    //     defer free(contexts.data);
    //     for 0..octaves-1  open_simplex_noise(seed + it * 2, *contexts[it]);

    //     bitmap := NewArray(size * size, float);
    //     defer free(bitmap.data);

    //     inv_period := 1.0 / period;

    //     index: int;
    //     for y: 0..size-1 {
    //         for x: 0..size-1 {
    //             bitmap[index] = get_fractal_2d(contexts, xx x, xx y, inv_period, persistence, lacunarity) * 0.5 + 0.5;
    //             index += 1;
    //         }
    //     }

    //     for 0..octaves-1  open_simplex_noise_free(contexts[it]);
    //     return create_grayscale_texture(bitmap, size, size, .Repeat, true);
    // }

    // generate_seamless_fractal :: (seed: s64, size: s32,
    //     octaves := 3,
    //     period := 64.0,
    //     persistence := 0.5,
    //     lacunarity := 2.0
    // ) -> Texture {
    //     contexts := NewArray(octaves, *osn_context);
    //     defer free(contexts.data);
    //     for 0..octaves-1  open_simplex_noise(seed + it * 2, *contexts[it]);

    //     bitmap := NewArray(size * size, float);
    //     defer free(bitmap.data);

    //     inv_size := 1.0 / cast(float) size;
    //     inv_period := 1.0 / period;

    //     index: int;
    //     for i: 0..size-1 {
    //         for j: 0..size-1 {
    //             ii := cast(float) i * inv_size;
    //             jj := cast(float) j * inv_size;

    //             ii *= 2.0 * PI;
    //             jj *= 2.0 * PI;

    //             INV_2PI :: #run 1.0 / (2.0 * PI);
    //             radius := cast(float) size * INV_2PI;
    //             x := radius * sin(jj);
    //             y := radius * cos(jj);
    //             z := radius * sin(ii);
    //             w := radius * cos(ii);

    //             bitmap[index] = get_fractal_4d(contexts, x, y, z, w, inv_period, persistence, lacunarity) * 0.5 + 0.5;

    //             index += 1;
    //         }
    //     }

    //     for 0..octaves-1  open_simplex_noise_free(contexts[it]);
    //     return create_grayscale_texture(bitmap, size, size, .Repeat, true);
    // }

    // get_fractal_2d :: inline (contexts: [] *osn_context, x: float, y: float, inv_period: float, persistence: float, lacunarity: float) -> float {
    //     x *= inv_period;
    //     y *= inv_period;

    //     amplitude := 1.0;
    //     max_value := 1.0;
    //     sum: float64 = open_simplex_noise2(contexts[0], x, y);

    //     for 1..contexts.count-1 {
    //         x *= lacunarity;
    //         y *= lacunarity;
    //         amplitude *= persistence;
    //         max_value += amplitude;
    //         sum += open_simplex_noise2(contexts[it], x, y) * amplitude;
    //     }

    //     return xx (sum / max_value);
    // }

    // get_fractal_4d :: inline (contexts: [] *osn_context, x: float, y: float, z: float, w: float, inv_period: float, persistence: float, lacunarity: float) -> float {
    //     x *= inv_period;
    //     y *= inv_period;
    //     z *= inv_period;
    //     w *= inv_period;

    //     amplitude := 1.0;
    //     max_value := 1.0;
    //     sum: float64 = open_simplex_noise4(contexts[0], x, y, z, w);

    //     for 1..contexts.count-1 {
    //         x *= lacunarity;
    //         y *= lacunarity;
    //         z *= lacunarity;
    //         w *= lacunarity;
    //         amplitude *= persistence;
    //         max_value += amplitude;
    //         sum += open_simplex_noise4(contexts[it], x, y, z, w) * amplitude;
    //     }

    //     return xx (sum / max_value);
    // }
}

// @Todo(sushi): Reimplement u64 hashing with better primes
// get_single_1d :: (seed: u64, position: $T) -> u64 {
//     bits_1 :: 0xB5297A4D;
//     bits_2 :: 0x68E31DA4;
//     bits_3 :: 0x1B56C4E9;

//     mangled := cast,no_check(u64) position;
//     mangled *= bits_1;
//     mangled += seed;
//     mangled ^= mangled >> 8;
//     mangled += bits_2;
//     mangled ^= mangled << 8;
//     mangled *= bits_3;
//     mangled ^= mangled >> 8;
//     return mangled;
// }

// get_single_2d :: (seed: u64, x: $T, y: T) -> u64 {
//     return inline get_single_1d(seed, x + (y * PRIME_Y));
// }

// get_single_3d :: (seed: u64, x: $T, y: T, z: T) -> u64 {
//     return inline get_single_1d(seed, x + (y * PRIME_Y) + (z * PRIME_Z));
// }

// get_single_4d :: (seed: u64, x: $T, y: T, z: T, w: T) -> u64 {
//     return inline get_single_1d(seed, x + (y * PRIME_Y) + (z * PRIME_Z) + (w * PRIME_W));
// }

// get_single_5d :: (seed: u64, x: $T, y: T, z: T, w: T, v: T) -> u64 {
//     return inline get_single_1d(seed, x + (y * PRIME_Y) + (z * PRIME_Z) + (w * PRIME_W) + (v * PRIME_V));
// }

get_single_1d :: (seed: u32, position: $T) -> u32 {
    bits_1 :: 0xB5297A4D;
    bits_2 :: 0x68E31DA4;
    bits_3 :: 0x1B56C4E9;

    mangled := cast,no_check(u32) position;
    mangled *= bits_1;
    mangled += seed;
    mangled ^= mangled >> 8;
    mangled += bits_2;
    mangled ^= mangled << 8;
    mangled *= bits_3;
    mangled ^= mangled >> 8;
    return mangled;
}

get_single_2d :: (seed: u32, x: $T, y: T) -> u32 {
    return inline get_single_1d(seed, x + (y * PRIME_Y));
}

get_single_3d :: (seed: u32, x: $T, y: T, z: T) -> u32 {
    return inline get_single_1d(seed, x + (y * PRIME_Y) + (z * PRIME_Z));
}

get_single_4d :: (seed: u32, x: $T, y: T, z: T, w: T) -> u32 {
    return inline get_single_1d(seed, x + (y * PRIME_Y) + (z * PRIME_Z) + (w * PRIME_W));
}

get_single_5d :: (seed: u32, x: $T, y: T, z: T, w: T, v: T) -> u32 {
    return inline get_single_1d(seed, x + (y * PRIME_Y) + (z * PRIME_Z) + (w * PRIME_W) + (v * PRIME_V));
}

get_single_float :: (seed: u32, position: $T) -> float {
    randint := (inline get_single_1d(seed, position)) & MASK;
    return randint / cast(float) MASK;
}

get_single_float :: (seed: u32, x: $T, y: T) -> float {
    randint := (inline get_single_2d(seed, x, y)) & MASK;
    return randint / cast(float) MASK;
}

// Adapted from SquirrelNoise5 by Squirrel Eiserloh under [CC-BY-3.0 US]
//  - http://eiserloh.net/noise/SquirrelNoise5.hpp

squirrel_noise :: (position: $T, seed: $S) -> u32 {
    Bits_1 :: 0xD2A80A3F; // 0b11010010101010000000101000111111
    Bits_2 :: 0xA884F197; // 0b10101000100001001111000110010111
    Bits_3 :: 0x6C736F4B; // 0b01101100011100110110111101001011
    Bits_4 :: 0xB79F3ABB; // 0b10110111100111110011101010111011
    Bits_5 :: 0x1B56C4f5; // 0b00011011010101101100010011110101

    mangled := (cast,no_check(*u32) *position).*;
    mangled *= Bits_1;
    mangled += (cast,no_check(*u32) *seed).*;
    mangled ^= (mangled >> 9);
    mangled += Bits_2;
    mangled ^= (mangled >> 11);
    mangled *= Bits_3;
    mangled ^= (mangled >> 13);
    mangled += Bits_4;
    mangled ^= (mangled >> 15);
    mangled *= Bits_5;
    mangled ^= (mangled >> 17);
    return mangled;
}

get_1d :: (position: $T, seed: $S, $R := u32) -> R {
     return cast,no_check(R) squirrel_noise(position, seed);
}

get_2d :: (x: $T, y: T, seed: $S, $R := u32) -> R {
     return cast,no_check(R) squirrel_noise(x + (PRIME_1 * y), seed);
}

get_3d :: (x: $T, y: T, z: T, seed: $S, $R := u32) -> R {
     return cast,no_check(R) squirrel_noise(x + (PRIME_1 * y) + (PRIME_2 * z), seed);
}

get_4d :: (x: $T, y: T, z: T, w: T, seed: $S, $R := u32) -> R {
     return cast,no_check(R) squirrel_noise(x + (PRIME_1 * y) + (PRIME_2 * z) + (PRIME_3 * w), seed);
}

get_1d_zto :: (position: $T, seed: $S) -> float {
    return cast(float) (INV_U32_MAX * (cast(float64) squirrel_noise(position, seed)));
}

get_2d_zto :: (x: $T, y: T, seed: $S, $R := u32) -> R {
    return cast(float) (INV_U32_MAX * (cast(float64) get_2d(x, y, seed)));
}

get_3d_zto :: (x: $T, y: T, z: T, seed: $S, $R := u32) -> R {
    return cast(float) (INV_U32_MAX * (cast(float64) get_3d(x, y, z, seed)));
}

get_4d_zto :: (x: $T, y: T, z: T, w: T, seed: $S, $R := u32) -> R {
    return cast(float) (INV_U32_MAX * (cast(float64) get_4d(x, y, z, w, seed)));
}

get_1d_noto :: (position: $T, seed: $S) -> float {
    return cast(float) (INV_S32_MAX * (cast(float64) squirrel_noise(position, seed)));
}

get_2d_noto :: (x: $T, y: T, seed: $S, $R := u32) -> R {
    return cast(float) (INV_S32_MAX * (cast(float64) get_2d(x, y, seed)));
}

get_3d_noto :: (x: $T, y: T, z: T, seed: $S, $R := u32) -> R {
    return cast(float) (INV_S32_MAX * (cast(float64) get_3d(x, y, z, seed)));
}

get_4d_noto :: (x: $T, y: T, z: T, w: T, seed: $S, $R := u32) -> R {
    return cast(float) (INV_S32_MAX * (cast(float64) get_4d(x, y, z, w, seed)));
}

#scope_file

INV_U32_MAX :: (1.0 / cast(float64) U32_MAX);
INV_S32_MAX :: (1.0 / cast(float64) S32_MAX);

PRIME_1 :: 0x0BD4_BCB5;
PRIME_2 :: 0x0063_D68D;
PRIME_3 :: 0x0005_7377;

PRIME_Y :: 0x1DDE90C9;
PRIME_Z :: 0x43C42E4D;
PRIME_W :: 0x668B6E2F;
PRIME_V :: 0x3F8A6FC7;

RANDRANGE : u32 : 1 << 24;
MASK :: RANDRANGE - 1;

// #import "Random";
// #import "OpenSimplexNoise";
