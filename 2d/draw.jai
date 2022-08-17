
draw_begin :: () {
    // load identity
}

draw_end :: () {
    batch_draw();
}

draw_clear :: inline (color: Color) {
    glClearColor(color.r, color.g, color.b, color.a);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
}

draw_clear :: (color: Color8) #expand {
    draw_clear(to_color(color));
}

draw_clear :: () #expand {
    draw_clear(Colors.Black);
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

draw_line :: (a: Vector2, b: Vector2, tints: .. Color) {
    batch_start(.Line);
    {
        push_color(tints[0]);
        push_vertex(.Line, a);
        push_color(tints[1]);
        push_vertex(.Line, b);
    }
    batch_end(.Line);
}

draw_rect :: (rect: Rect, tint := Colors.White) {
    tl, tr, bl, br: Vector2;
    tl.x = rect.x;
    tl.y = rect.y;
    tr.x = rect.x + rect.width;
    tr.y = rect.y;
    bl.x = rect.x;
    bl.y = rect.y + rect.height;
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

draw_rect :: (rect: Rect, tints: .. Color) {
    tl, tr, bl, br: Vector2;
    tl.x = rect.x;
    tl.y = rect.y;
    tr.x = rect.x + rect.width;
    tr.y = rect.y;
    bl.x = rect.x;
    bl.y = rect.y + rect.height;
    br.x = tr.x;
    br.y = bl.y;

    batch_start(.Rect);
    {
        if tints.count < 4 {
            push_color(tints[0]);
            push_vertex(.Rect, tl);
            push_vertex(.Rect, bl);
            push_vertex(.Rect, br);
            push_vertex(.Rect, tr);
        } else {
            push_color(tints[0]);
            push_vertex(.Rect, tl);
            push_color(tints[1]);
            push_vertex(.Rect, bl);
            push_color(tints[2]);
            push_vertex(.Rect, br);
            push_color(tints[3]);
            push_vertex(.Rect, tr);
        }
    }
    batch_end(.Rect);
}

draw_texture :: (
    texture: Texture,
    pos: Vector2
) {
    source, dest: Rect;
    source.width  = xx texture.width;
    source.height = xx texture.height;
    dest.x        = pos.x;
    dest.y        = pos.y;
    dest.width    = source.width;
    dest.height   = source.height;
    draw_texture(texture, source, dest);
}

draw_texture :: (
    texture: Texture,
    source: Rect,
    dest: Rect,
    origin := Vector2.{0, 0},
    rotation: float32 = 0.0,
    tint := Colors.White,
    flip_x := false
) {
    if texture.id == 0  return;

    width:  float32 = xx texture.width;
    height: float32 = xx texture.height;

    tl, tr, bl, br: Vector2;

    if rotation == 0 {
        x := dest.x - origin.x;
        y := dest.y - origin.y;

        tl.x = x;
        tl.y = y;
        tr.x = x + dest.width;
        tr.y = y;
        bl.x = x;
        bl.y = y + dest.height;
        br.x = tr.x;
        br.y = bl.y;
    } else {
        theta_sin := sin(rotation);
        theta_cos := cos(rotation);
        x := dest.x;
        y := dest.y;
        dx := -origin.x;
        dy := -origin.y;

        tl.x = x + dx * theta_cos - dy * theta_sin;
        tl.y = y + dx * theta_sin + dy * theta_cos;
        tr.x = x + (dx + dest.width) * theta_cos - dy * theta_sin;
        tr.y = y + (dx + dest.width) * theta_sin + dy * theta_cos;
        bl.x = x + dx * theta_cos - (dy + dest.height) * theta_sin;
        bl.y = y + dx * theta_sin + (dy + dest.height) * theta_cos;
        br.x = x + (dx + dest.width) * theta_cos - (dy + dest.height) * theta_sin;
        br.y = y + (dx + dest.width) * theta_sin + (dy + dest.height) * theta_cos;
    }

    check_render_limit();
    set_texture(texture.id);
    batch_start(.Texture);
    {
        push_color(tint);

        if flip_x {
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

#scope_file

#import "Math";
