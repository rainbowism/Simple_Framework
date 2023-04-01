MSDF_Font :: struct {
    using data: MSDF_Data;
    texture: Texture;
    glyphs: [] MSDF_Glyph;
    kerning: [] float;
}

MSDF_Data :: struct {
    pixels_per_point: float;
    pixel_range: float;
    atlas_size: s32;
    line_height: float;
    underline_height: float;
    underline_thickness: float;
    starting_glyph: s32;
}

MSDF_MAGIC :: 0x4644534D;

MSDF_Glyph :: struct {
    advance_x: float;
    plane: Rect;
    atlas: Rect;
}

MSDF_Kerning :: struct {
    codepoint1: s32;
    codepoint2: s32;
    advance_x: float;
}

load_msdf :: inline (msdf_filename: string, texture_filename: string) -> *MSDF_Font, bool {
    font: *MSDF_Font;
    font_texture: Texture = ---;
    success: bool = ---;
    font_texture, success = load_texture(texture_filename, min_sampling = .Linear, mag_sampling = .Linear);
    if !success  return null, false;
    font, success = load_msdf(msdf_filename, font_texture);
    if !success  return null, false;
    return font, true;
}

load_msdf :: (msdf_filename: string, texture: Texture) -> *MSDF_Font, bool {
    msdf_data, success := read_entire_file(msdf_filename);
    if !success  return null, false;

    magic_number: u32 = << cast(*u32) msdf_data.data;

    if magic_number != MSDF_MAGIC  return null, false;

    offset := msdf_data.data + 4;

    msdf := New(MSDF_Font);
    memcpy(*msdf.data, offset, size_of(MSDF_Data));

    offset += size_of(MSDF_Data);

    glyph_count: s32 = << cast(*s32) offset;
    offset += size_of(s32);

    texture_uv: Vector2 = .{1.0 / texture.width, 1.0 / texture.height};

    msdf.glyphs.count  = glyph_count;
    msdf.kerning.count = glyph_count * glyph_count;
    msdf.glyphs.data   = alloc(size_of(MSDF_Glyph) * glyph_count + size_of(float) * msdf.kerning.count);
    msdf.kerning.data  = cast,no_check(*float) msdf.glyphs.data + size_of(MSDF_Glyph) * glyph_count;

    for 0..glyph_count-1 {
        codepoint: s32 = << cast(*s32) offset;
        offset += size_of(s32);
        memcpy(*msdf.glyphs[codepoint - msdf.starting_glyph], offset, size_of(MSDF_Glyph));
        // @Note(sushi): This is converting the pixel coordinates into UVs.
        //  We probably don't ever need the pixel coordinates?
        msdf.glyphs[codepoint - msdf.starting_glyph].atlas.tl = msdf.glyphs[codepoint - msdf.starting_glyph].atlas.tl * texture_uv;
        msdf.glyphs[codepoint - msdf.starting_glyph].atlas.br = msdf.glyphs[codepoint - msdf.starting_glyph].atlas.tl + msdf.glyphs[codepoint - msdf.starting_glyph].atlas.br * texture_uv;
        offset += size_of(MSDF_Glyph);
    }

    kerning_count: s32 = << cast(*s32) offset;
    offset += size_of(s32);

    // @Cleanup(sushi): This is using more memory than it needs to, maybe? But who cares.
    for 0..kerning_count-1 {
        codepoint1: s32 = (<< cast(*s32) offset);
        offset += size_of(s32);
        codepoint2: s32 = (<< cast(*s32) offset);
        offset += size_of(s32);
        advance_x: float = << cast(*float) offset;
        offset += size_of(float);
        msdf.kerning[codepoint1 * glyph_count + codepoint2] = advance_x;
    }

    msdf.texture = texture;

    return msdf, true;
}

free_msdf :: (msdf: *MSDF_Font) {
    free_texture(msdf.texture);
    free(msdf.glyphs.data);
    free(msdf.kerning.data);
    free(msdf);
}

measure_text :: (msdf: *MSDF_Font, text: string, size: float) -> Vector2 {
    text_size := Vector2.{0, msdf.line_height * size};
    if text.count == 0  return text_size;
    last_char: u8 = 0;
    for 0..text.count-1 {
        if text[it] < msdf.starting_glyph || text[it] >= (msdf.starting_glyph + msdf.glyphs.count)  continue;
        text_size.x += get_kerning(msdf, text[it], last_char);
        text_size.x += msdf.glyphs[text[it] - msdf.starting_glyph].advance_x;
        last_char = text[it];
    }
    text_size.x *= size;

    return text_size;
}

measure_text_wrapped_em :: (msdf: *MSDF_Font, text: string, size: float, max_width: float) -> Vector2, s64, float, float {
    // @Incomplete(sushi): This doesn't support wrapping more than 1 line.
    text_size := Vector2.{0, msdf.line_height * size};
    if text.count == 0  return text_size, -1, 0.0, 0.0;
    wrap_width: float;
    wrap_margin: float;
    wrap_index: s64;
    text_width: float;
    last_char: u8 = 0;
    has_wrapped: bool;
    for 0..text.count-1 {
        if text[it] < msdf.starting_glyph || text[it] >= (msdf.starting_glyph + msdf.glyphs.count)  continue;
        advance_x := get_kerning(msdf, text[it], last_char);
        advance_x += msdf.glyphs[text[it] - msdf.starting_glyph].advance_x;
        advance_x *= size;
        if text[it] == 0x20 && !has_wrapped {
            wrap_width  = text_width;
            wrap_index  = it;
            wrap_margin = advance_x;
        }
        text_width += advance_x;
        last_char = text[it];
        if text_width > max_width {
            text_size.x = wrap_width;
            text_width -= wrap_width + wrap_margin;
            has_wrapped = true;
        }
    }
    if text_width > text_size.x  text_size.x = text_width;
    if !has_wrapped  wrap_index= -1;

    return text_size, wrap_index, wrap_width, text_width;
}

get_kerning :: inline (msdf: MSDF_Font, codepoint1: u8, codepoint2: u8) -> float {
    return msdf.kerning[((cast,no_check(s32) codepoint1) - msdf.starting_glyph) * msdf.glyphs.count + ((cast,no_check(s32) codepoint2) - msdf.starting_glyph)];
}
