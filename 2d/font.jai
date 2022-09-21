Font :: struct {
    texture:   Texture;
    glyphs: [] Glyph_Info;
}

Glyph_Info :: struct {
    src:  Vector2;
    dst:  Vector2;
    size: Vector2;
    advance_x: float;
}

load_font :: (filepath: string, font_size: float, padding: s32 = 0) -> Font, bool {
    file, success := read_entire_file(filepath);
    if !success  return .{}, false;
    defer free(file);

    font_info: ttf.Fontinfo;
    if !ttf.init_font(*font_info, file.data, 0)  return .{}, false;

    bitmap: [] u8;
    texture_size: s32 = 32;
    chars: [96] ttf.Packedchar;
    defer free(bitmap.data);
    while true {
        bitmap.count = texture_size * texture_size;
        bitmap.data = alloc(bitmap.count);
        pack_context: ttf.PackContext;
        ttf.pack_begin(*pack_context, bitmap.data, texture_size, texture_size, 0, padding + 1, null);
        defer ttf.pack_end(*pack_context);
        ttf.pack_set_oversampling(*pack_context, 1, 1);
        if ttf.pack_font_range(*pack_context, file.data, 0, font_size, 32, 95, chars.data)  break;
        free(bitmap.data);
        texture_size *= 2;
    }

    ascent, descent, line_gap: s32;
    ttf.get_font_v_metrics(*font_info, *ascent, *descent, *line_gap);
    scale := ttf.scale_for_pixel_height(*font_info, font_size);
    offset_y := cast(float) ascent * scale;

    font: Font;
    font.glyphs.data  = alloc(96 * size_of(Glyph_Info));
    font.glyphs.count = 96;
    for 0..chars.count-1 {
        info := chars[it];
<<<<<<< HEAD
        font.glyphs[it].src.x  = cast(float) info.x0;
        font.glyphs[it].src.y  = cast(float) info.y0;
        font.glyphs[it].dst.x  = info.xoff;
        font.glyphs[it].dst.y  = info.yoff + offset_y;
        font.glyphs[it].size.x = cast(float) (info.x1 - info.x0);
        font.glyphs[it].size.y = cast(float) (info.y1 - info.y0);
=======
        font.glyphs[it].src.x  = cast(float) info.x0 - 1;
        font.glyphs[it].src.y  = cast(float) info.y0;
        font.glyphs[it].dst.x  = info.xoff;
        font.glyphs[it].dst.y  = info.yoff + offset_y;
        font.glyphs[it].size.x = cast(float) (info.x1 - info.x0 + 1);
        font.glyphs[it].size.y = cast(float) (info.y1 - info.y0 + 1);
>>>>>>> 7e364352463d4e9950642ef447c25984d29abca8
        font.glyphs[it].advance_x = info.xadvance;
    }

    font.texture = create_font_texture(bitmap, texture_size, texture_size);
    return font, true;
}

free_font :: (font: Font) {
    free(font.glyphs.data);
    free_texture(font.texture);
}

#scope_file

#import "File";
ttf :: #import "stb_truetype";
