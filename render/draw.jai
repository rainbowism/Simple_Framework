draw_begin :: inline (time: float, $use_render_target := true) {
    gpu_begin_frame();
    _profiler_draw_task = gpu_begin_task("Draw", Colors8.Medium_Purple);
    render_begin(time, use_render_target);
}

draw_begin :: inline (time: float, camera: Camera, $use_render_target := true) {
    gpu_begin_frame();
    _profiler_draw_task = gpu_begin_task("Draw", Colors8.Medium_Purple);
    render_begin(time, camera, use_render_target);
}

draw_batch :: batch_draw;

draw_end :: inline () {
    draw_buffer();
    batch_draw();
    gpu_end_task(_profiler_draw_task);
}

draw_buffer :: ($draw_screen := true) {
    if render_ctx.state.buffer_drawn  return;
    batch_draw();
    glDisable(GL_DEPTH_TEST);
    defer glEnable(GL_DEPTH_TEST);
    glBindFramebuffer(GL_FRAMEBUFFER, render_ctx.target[RENDER_TARGET_MAIN].fbo);
    draw_render_texture(render_ctx.target[RENDER_TARGET_PARTICLE]);
    render_bloom(
        render_ctx.bloom,
        render_ctx.target[RENDER_TARGET_MAIN].fbo,
        render_ctx.target[RENDER_TARGET_PARTICLE].color,
        0.005
    );
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    draw_clear();
    #if draw_screen  draw_render_texture(render_ctx.target[RENDER_TARGET_MAIN]);
    bind_screen_texture();
    render_ctx.state.buffer_drawn = true;
}

bind_screen_texture :: inline () {
    glActiveTexture(GL_TEXTURE0 + cast,no_check(GLuint) render_ctx.max_texture_slot);
    glBindTexture(GL_TEXTURE_2D, render_ctx.target[RENDER_TARGET_MAIN].color);
}

draw_line :: (a: Vector2, b: Vector2, tint := Colors.White) {
    batch_start(.Line);
    {
        push_color(tint);
        push_primitive(.Line, a);
        push_primitive(.Line, b);
    }
    batch_end(.Line);
}

draw_line :: (a: Vector2, b: Vector2, tints: [2] Color) {
    batch_start(.Line);
    {
        push_color(tints[0]);
        push_primitive(.Line, a);
        push_color(tints[1]);
        push_primitive(.Line, b);
    }
    batch_end(.Line);
}

draw_circle :: (using circle: *Circle, tint := Colors.White, $segments: int = 32) {
    INCREMENT :: 1.0 / segments;

    position := circle.position;

    last: Vector2 = ---;
    theta: float;

    batch_start(.Line);
    {
        push_color(tint);
        last.x = tcos(0) * radius + position.x;
        last.y = tsin(0) * radius + position.y;

        for 0..segments {
            theta += INCREMENT;
            push_primitive(.Line, last);
            last.x = tcos(theta) * radius + position.x;
            last.y = tsin(theta) * radius + position.y;
            push_primitive(.Line, last);
        }
    }
    batch_end(.Line);
}

draw_circle :: (position: Vector2, radius: float, tint := Colors.White, $segments: int = 32) {
    INCREMENT :: 1.0 / segments;

    position := position;

    last: Vector2 = ---;
    theta: float;

    batch_start(.Line);
    {
        push_color(tint);
        last.x = tcos(0) * radius + position.x;
        last.y = tsin(0) * radius + position.y;

        for 0..segments {
            theta += INCREMENT;
            push_primitive(.Line, last);
            last.x = tcos(theta) * radius + position.x;
            last.y = tsin(theta) * radius + position.y;
            push_primitive(.Line, last);
        }
    }
    batch_end(.Line);
}

draw_poly :: (using polygon: *Polygon($N), tint := Colors.White) {
    batch_start(.Line);
    {
        push_color(tint);
        for 0..N-2 {
            push_primitive(.Line, position + points[it]);
            push_primitive(.Line, position + points[it+1]);
        }
        push_primitive(.Line, position + points[N-1]);
        push_primitive(.Line, position + points[0]);
    }
    batch_end(.Line);
}

draw_rect :: (obb: *OBB, tint := Colors.White) {
    position := oobb.position;
    batch_start(.Rect);
    {
        push_color(tint);
        push_primitive(.Rect, position + points[0]);
        push_primitive(.Rect, position + points[1]);
        push_primitive(.Rect, position + points[2]);
        push_primitive(.Rect, position + points[3]);
    }
    batch_end(.Rect);
}

draw_rect_bottom_center :: (position: Vector2, size: Vector2, tint := Colors.White, rotation: float = 0.0) {
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
        push_primitive(.Rect, tl);
        push_primitive(.Rect, bl);
        push_primitive(.Rect, br);
        push_primitive(.Rect, tr);
    }
    batch_end(.Rect);
}

draw_rect :: (dest: Rect, tint := Colors.White, origin := Vector2.{0, 0}, rotation: float = 0.0) {
    tl, tr, bl, br: Vector2 = ---;
    rotate_quad();

    batch_start(.Rect);
    {
        push_color(tint);
        push_primitive(.Rect, tl);
        push_primitive(.Rect, bl);
        push_primitive(.Rect, br);
        push_primitive(.Rect, tr);
    }
    batch_end(.Rect);
}

draw_rect :: (dest: Rect, tints: [4] Color, origin := Vector2.{0, 0}, rotation: float = 0.0) {
    tl, tr, bl, br: Vector2 = ---;
    rotate_quad();

    batch_start(.Rect);
    {
        push_color(tints[0]);
        push_primitive(.Rect, tl);
        push_color(tints[1]);
        push_primitive(.Rect, bl);
        push_color(tints[2]);
        push_primitive(.Rect, br);
        push_color(tints[3]);
        push_primitive(.Rect, tr);
    }
    batch_end(.Rect);
}

draw_texture :: inline (
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
    inline draw_texture(
        texture, source, dest,
        origin = origin,
        rotation = rotation,
        tint = tint
    );
}

draw_texture :: inline (
    texture: Texture,
    pos: Vector2,
    scale: float,
    tint := Colors.White,
    origin := Vector2.{0, 0},
    rotation: float = 0.0
) {
    source, dest: Rect;
    source.width  = xx texture.width;
    source.height = xx texture.height;
    dest.x        = pos.x;
    dest.y        = pos.y;
    dest.width    = source.width * scale;
    dest.height   = source.height * scale;
    inline draw_texture(
        texture, source, dest,
        origin = origin * scale,
        rotation = rotation,
        tint = tint
    );
}

draw_texture :: inline (
    texture: Texture,
    pos: Vector2,
    scale: Vector2,
    tint := Colors.White,
    origin := Vector2.{0, 0},
    rotation: float = 0.0
) {
    source, dest: Rect;
    source.width  = xx texture.width;
    source.height = xx texture.height;
    dest.x        = pos.x;
    dest.y        = pos.y;
    dest.width    = source.width * scale.x;
    dest.height   = source.height * scale.y;
    inline draw_texture(
        texture, source, dest,
        origin = origin * scale,
        rotation = rotation,
        tint = tint
    );
}

draw_texture :: inline (
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

    width:  float = 1.0 / cast(float) texture.width;
    height: float = 1.0 / cast(float) texture.height;

    tl, tr, bl, br: Vector2 = ---;
    rotate_quad();

    push_texture(texture.id);
    batch_start(.Texture);
    {
        push_color(tint);

        #if flip_x {
            push_uv((source.x + source.width) * width, source.y * height);
            push_vertex(.Texture, tl);
            push_uv((source.x + source.width) * width, (source.y + source.height) * height);
            push_vertex(.Texture, bl);
            push_uv(source.x * width, (source.y + source.height) * height);
            push_vertex(.Texture, br);
            push_uv(source.x * width, source.y * height);
            push_vertex(.Texture, tr);
        } else {
            push_uv(source.x * width, source.y * height);
            push_vertex(.Texture, tl);
            push_uv(source.x * width, (source.y + source.height) * height);
            push_vertex(.Texture, bl);
            push_uv((source.x + source.width) * width, (source.y + source.height) * height);
            push_vertex(.Texture, br);
            push_uv((source.x + source.width) * width, source.y * height);
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

draw_text :: (msdf: MSDF_Font, text: string, position: Vector2, size: float, tint := Colors.White) {
    offset := position;
    current_tint := tint;

    last_char: u8 = 0;

    for 0..text.count-1 {
        if text[it] < msdf.starting_glyph || text[it] >= (msdf.starting_glyph + msdf.glyphs.count)  continue;
        offset.x += get_kerning(msdf, text[it], last_char) * size;
        glyph := msdf.glyphs[text[it] - msdf.starting_glyph];
        dest := (glyph.plane * size) + offset;
        current_tint.a = size / dest.width;
        draw_texture(msdf.texture, glyph.atlas, dest, tint);
        offset.x += glyph.advance_x * size;
        last_char = text[it];
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
        theta_sin := tsin(`rotation);
        theta_cos := tcos(`rotation);
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

_profiler_draw_task: int;

#import "Math";
