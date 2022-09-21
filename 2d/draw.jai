draw_begin :: () {
    push_model_view_identity();
}

draw_end :: () {
    batch_draw();
}

draw_line :: (a: Vector2, b: Vector2, tint := Colors.White) {
    batch_start(.Line);
    {
        push_color(tint);
        push_vertex(.Line, a);
        push_vertex(.Line, b);
    }
    batch_end(.Line);
}

draw_line :: (a: Vector2, b: Vector2, tints: [2] Color) {
    batch_start(.Line);
    {
        push_color(tints[0]);
        push_vertex(.Line, a);
        push_color(tints[1]);
        push_vertex(.Line, b);
    }
    batch_end(.Line);
}

draw_circle :: (using circle: *Circle, tint := Colors.White, $segments: int = 32) {
    INCREMENT :: TAU / segments;

    last: Vector2 = ---;
    theta: float;

    batch_start(.Line);
    {
        push_color(tint);
        last.x = cos(0) * radius + position.x;
        last.y = sin(0) * radius + position.y;

        for 0..segments {
            theta += INCREMENT;
            push_vertex(.Line, last);
            last.x = cos(theta) * radius + position.x;
            last.y = sin(theta) * radius + position.y;
            push_vertex(.Line, last);
        }
    }
    batch_end(.Line);
}

draw_circle :: (position: Vector2, radius: float, tint := Colors.White, $segments: int = 32) {
    INCREMENT :: TAU / segments;

    last: Vector2 = ---;
    theta: float;

    batch_start(.Line);
    {
        push_color(tint);
        last.x = cos(0) * radius + position.x;
        last.y = sin(0) * radius + position.y;

        for 0..segments {
            theta += INCREMENT;
            push_vertex(.Line, last);
            last.x = cos(theta) * radius + position.x;
            last.y = sin(theta) * radius + position.y;
            push_vertex(.Line, last);
        }
    }
    batch_end(.Line);
}

draw_poly :: (using polygon: *Polygon($N), tint := Colors.White) {
    batch_start(.Line);
    {
        push_color(tint);
        for 0..N-2 {
            push_vertex(.Line, position + points[it]);
            push_vertex(.Line, position + points[it+1]);
        }
        push_vertex(.Line, position + points[N-1]);
        push_vertex(.Line, position + points[0]);
    }
    batch_end(.Line);
}

draw_rect :: (using obb: *OBB, tint := Colors.White) {
    batch_start(.Rect);
    {
        push_color(tint);
        push_vertex(.Rect, position + points[0]);
        push_vertex(.Rect, position + points[1]);
        push_vertex(.Rect, position + points[2]);
        push_vertex(.Rect, position + points[3]);
    }
    batch_end(.Rect);
}

draw_rect_bottom_center :: (position: Vector2, size: Vector2, tint := Colors.White, rotation: float32 = 0.0) {
    x := position.x - size.x * 0.5;
    y := position.y - size.y;
    tl, tr, bl, br: Vector2 = ---;
    tl.x = x;
    tl.y = y;
    tr.x = x + size.x;
    tr.y = y;
    bl.x = x;
    bl.y = y + size.y;
    br.x = tr.x;
    br.y = bl.y;

    batch_start(.Rect);
    {
        push_color(tint);
        push_vertex(.Rect, tl);
        push_vertex(.Rect, bl);
        push_vertex(.Rect, br);
        push_vertex(.Rect, tr);
    }
    batch_end(.Rect);
}

draw_rect :: (dest: Rect, tint := Colors.White, origin := Vector2.{0, 0}, rotation: float32 = 0.0) {
    tl, tr, bl, br: Vector2 = ---;
    rotate_quad();

    batch_start(.Rect);
    {
        push_color(tint);
        push_vertex(.Rect, tl);
        push_vertex(.Rect, bl);
        push_vertex(.Rect, br);
        push_vertex(.Rect, tr);
    }
    batch_end(.Rect);
}

draw_rect :: (dest: Rect, tints: [4] Color, origin := Vector2.{0, 0}, rotation: float32 = 0.0) {
    tl, tr, bl, br: Vector2 = ---;
    rotate_quad();

    batch_start(.Rect);
    {
        push_color(tints[0]);
        push_vertex(.Rect, tl);
        push_color(tints[1]);
        push_vertex(.Rect, bl);
        push_color(tints[2]);
        push_vertex(.Rect, br);
        push_color(tints[3]);
        push_vertex(.Rect, tr);
    }
    batch_end(.Rect);
}

draw_texture :: (
    texture: Texture,
    pos: Vector2,
    tint := Colors.White,
    origin := Vector2.{0, 0},
    rotation: float = 0.0
) {
    source, dest: Rect;
    source.width  = xx texture.width;
    source.height = xx texture.height;
    dest.x        = pos.x;
    dest.y        = pos.y;
    dest.width    = source.width;
    dest.height   = source.height;
    draw_texture(
        texture, source, dest,
        origin = origin,
        rotation = rotation,
        tint = tint
    );
}

draw_texture :: (
    texture: Texture,
    src: Vector2,
    dst: Vector2,
    size: Vector2,
    tint := Colors.White,
    origin := Vector2.{0, 0},
    rotation: float = 0.0
) {
    source, dest: Rect = ---;
    source.x = src.x;
    source.y = src.y;
    source.width  = size.x;
    source.height = size.y;
    dest.x        = dst.x;
    dest.y        = dst.y;
    dest.width    = size.x;
    dest.height   = size.y;
    draw_texture(
        texture, source, dest,
        origin = origin,
        rotation = rotation,
        tint = tint
    );
}

draw_texture :: (
    texture: Texture,
    source: Rect,
    dest: Rect,
    tint := Colors.White,
    origin := Vector2.{0, 0},
    rotation: float = 0.0,
    $flip_x := false
) {
    if texture.id == 0  return;

    width:  float = xx texture.width;
    height: float = xx texture.height;

    tl, tr, bl, br: Vector2 = ---;
    rotate_quad();

    set_texture(texture.id);
    batch_start(.Texture);
    {
        push_color(tint);

        #if flip_x {
            push_uv((source.x + source.width) / width, source.y / height);
            push_vertex(.Texture, tl);
            push_uv((source.x + source.width) / width, (source.y + source.height) / height);
            push_vertex(.Texture, bl);
            push_uv(source.x / width, (source.y + source.height) / height);
            push_vertex(.Texture, br);
            push_uv(source.x / width, source.y / height);
            push_vertex(.Texture, tr);
        } else {
            push_uv(source.x / width, source.y / height);
            push_vertex(.Texture, tl);
            push_uv(source.x / width, (source.y + source.height) / height);
            push_vertex(.Texture, bl);
            push_uv((source.x + source.width) / width, (source.y + source.height) / height);
            push_vertex(.Texture, br);
            push_uv((source.x + source.width) / width, source.y / height);
            push_vertex(.Texture, tr);
        }
    }
    batch_end(.Texture);
}

draw_text :: (font: Font, text: string, position: Vector2, tint := Colors.White) {
    offset := position;
    for 0..text.count-1 {
        if text[it] < 32 || text[it] >= 128  continue;
        glyph := font.glyphs[text[it] - 32];
        draw_texture(font.texture, glyph.src, glyph.dst + offset, glyph.size, tint);
        offset.x += glyph.advance_x;
    }
}

#scope_file

rotate_quad :: () #expand {
    if `rotation == 0 {
        x := `dest.x - `origin.x;
        y := `dest.y - `origin.y;

        `tl.x = x;
        `tl.y = y;
        `tr.x = x + `dest.width;
        `tr.y = y;
        `bl.x = x;
        `bl.y = y + `dest.height;
        `br.x = `tr.x;
        `br.y = `bl.y;
    } else {
        theta_sin := sin(`rotation);
        theta_cos := cos(`rotation);
        x := `dest.x;
        y := `dest.y;
        dx := -`origin.x;
        dy := -`origin.y;

        `tl.x = x + dx * theta_cos - dy * theta_sin;
        `tl.y = y + dx * theta_sin + dy * theta_cos;
        `tr.x = x + (dx + `dest.width) * theta_cos - dy * theta_sin;
        `tr.y = y + (dx + `dest.width) * theta_sin + dy * theta_cos;
        `bl.x = x + dx * theta_cos - (dy + `dest.height) * theta_sin;
        `bl.y = y + dx * theta_sin + (dy + `dest.height) * theta_cos;
        `br.x = x + (dx + `dest.width) * theta_cos - (dy + `dest.height) * theta_sin;
        `br.y = y + (dx + `dest.width) * theta_sin + (dy + `dest.height) * theta_cos;
    }
}

#import "Math";
