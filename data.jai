Point2 :: struct {
    x, y: s32;
}

Recti :: struct {
    x, y:          s32;
    width, height: s32;
}

intersect :: inline (p: Point2, r: Recti) -> bool {
    return r.x <= p.x && r.width  >= p.x &&
           r.y <= p.y && r.height >= p.y;
}

Color :: struct {
    r, g, b, a: float32;
}

Color8 :: struct {
    r, g, b, a: u8;
}

ONE_OVER_255 : float32 : 1.0 / 255;

alloc_color :: (r: float32, g: float32, b: float32, a: float32) -> Color {
    c: Color = ---;
    c.r = r;
    c.g = g;
    c.b = b;
    c.a = a;
    return c;
}

alloc_color8 :: (r: u8, g: u8, b: u8, a: u8) -> Color8 {
    c: Color8 = ---;
    c.r = r;
    c.g = g;
    c.b = b;
    c.a = a;
    return c;
}

to_color :: (in: Color8) -> Color {
    out: Color = ---;
    out.r = (cast(float32) in.r) * ONE_OVER_255;
    out.g = (cast(float32) in.g) * ONE_OVER_255;
    out.b = (cast(float32) in.b) * ONE_OVER_255;
    out.a = (cast(float32) in.a) * ONE_OVER_255;
    return out;
}
