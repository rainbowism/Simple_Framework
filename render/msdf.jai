MSDF_Font :: struct {
    glyph_lookup:   Table(u32, *MSDF_Glyph);
    kerning_lookup: Table(u64, MSDF_Kerning);
    texture: Texture;
    using data: MSDF_Data;
    glyphs:  [] MSDF_Glyph;
    // kerning: [] MSDF_Kerning;
}

MSDF_Data :: struct {
    pixels_per_point: float;
    pixel_range: float;
    atlas_size:  s32;
    line_height: float;
    ascender:    float;
    descender:   float;
    underline_height: float;
    underline_thickness: float;
}

MSDF_MAGIC :: 0x4644534D;

MSDF_Glyph :: struct {
    advance_x: float;
    plane: Rect;
    atlas: Rect;
}

MSDF_Kerning :: float;

load_msdf :: inline (msdf_filepath: string, texture_filepath: string) -> *MSDF_Font, bool {
    font: *MSDF_Font;
    font_texture: Texture = ---;
    success: bool = ---;
    font_texture, success = load_texture(texture_filepath, min_sampling = .Linear, mag_sampling = .Linear);
    if !success  return null, false;
    font, success = load_msdf(msdf_filepath, font_texture);
    if !success  return null, false;
    return font, true;
}

load_msdf :: (filepath: string, texture: Texture) -> *MSDF_Font, bool {
    msdf_data, success := read_entire_file(filepath);
    if !success  return null, false;
    defer free(msdf_data);

    font: *MSDF_Font;
    font, success = load_msdf_from_memory(msdf_data, texture);
    return font, success;
}

load_msdf_from_memory :: (buffer: string, texture: Texture) -> *MSDF_Font, bool {
    magic_number: u32 = << cast(*u32) buffer.data;
    if magic_number != MSDF_MAGIC  return null, false;

    offset := buffer.data + size_of(u32);

    msdf := New(MSDF_Font);
    memcpy(*msdf.data, offset, size_of(MSDF_Data));

    offset += size_of(MSDF_Data);

    glyph_count := << cast(*s32) offset;
    offset += size_of(s32);

    texture_uv: Vector2 = .{1.0 / texture.width, 1.0 / texture.height};

    msdf.glyphs = NewArray(glyph_count, MSDF_Glyph);

    for 0..glyph_count-1 {
        codepoint := << cast(*u32) offset;
        offset += size_of(u32);
        memcpy(*msdf.glyphs[it], offset, size_of(MSDF_Glyph));
        // @Note(sushi): This is converting the pixel coordinates into UVs.
        //  We probably don't ever need the pixel coordinates?
        msdf.glyphs[it].atlas.tl = msdf.glyphs[it].atlas.tl * texture_uv;
        msdf.glyphs[it].atlas.br = msdf.glyphs[it].atlas.tl + msdf.glyphs[it].atlas.br * texture_uv;
        table_add(*msdf.glyph_lookup, codepoint, *msdf.glyphs[it]);
        offset += size_of(MSDF_Glyph);
    }

    kerning_count := << cast(*s32) offset;
    offset += size_of(s32);

    for 0..kerning_count-1 {
        codepoint1 := << cast(*u32) offset;
        offset += size_of(u32);
        codepoint2 := << cast(*u32) offset;
        offset += size_of(u32);
        advance_x := << cast(*float) offset;
        offset += size_of(float);
        codepoint_hash := (cast(u64) codepoint1 << 32) | cast(u64) codepoint2;
        // msdf.kerning[it] = advance_x;
        // table_add(*msdf.kerning_lookup, codepoint_hash, msdf.kerning[it]);
        table_add(*msdf.kerning_lookup, codepoint_hash, advance_x);
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

get_kerning :: (msdf: *MSDF_Font, codepoint1: u32, codepoint2: u32) -> float #expand {
    codepoint_hash := (cast(u64) codepoint1 << 32) | cast(u64) codepoint2;
    kerning, success := table_find(*msdf.kerning_lookup, codepoint_hash);
    if success  return kerning;
    return 0.0;
    // return msdf.kerning[((cast,no_check(s32) codepoint1) - msdf.starting_glyph) * msdf.glyphs.count + ((cast,no_check(s32) codepoint2) - msdf.starting_glyph)];
}

measure_width :: (msdf: *MSDF_Font, text: string, size: float) -> float {
    if text.count == 0  return 0.0;
    text_width: float;
    last_codepoint: u32;
    head := text.data;
    while head < text.data + text.count {
        codepoint, continuation := one_utf32_codepoint(head);
        glyph, success := find_glyph(msdf, codepoint);
        if success {
            text_width += get_kerning(msdf, codepoint, last_codepoint);
            text_width += glyph.advance_x;
            last_codepoint = codepoint;
        }
        head += continuation;
    }
    text_width *= size;
    return text_width;
}

measure_text :: inline (msdf: *MSDF_Font, text: string, size: float) -> Vector2 {
    text_size: Vector2 = ---;
    text_size.x = measure_width(msdf, text, size);
    text_size.y = msdf.line_height * size;
    return text_size;
}

split_line_em :: (msdf: *MSDF_Font, text: string, size: float, starting_width: float, max_width: float) -> string, string, bool {
    if text.count == 0  return "", "", false;
    wrap_width: float;
    wrap_index: s64;
    text_width := starting_width;
    last_codepoint: u32;
    head := text.data;
    while head < text.data + text.count {
        codepoint, continuation := one_utf32_codepoint(head);
        glyph, success := find_glyph(msdf, codepoint);
        if success {
            advance_x := get_kerning(msdf, codepoint, last_codepoint);
            advance_x += glyph.advance_x;
            advance_x *= size;
            if codepoint == Unicode_Space {
                wrap_width = text_width;
                wrap_index = head - text.data;
            }
            text_width += advance_x;
            if text_width > max_width {
                line := text;
                advance(*text, wrap_index + 1);
                line.count = wrap_index;
                return line, text, true;
            }
            last_codepoint = codepoint;
        }
        head += continuation;
    }

    return text, "", false;
}

measure_text_wrapped :: (msdf: *MSDF_Font, text: string, size: float, max_width: float) -> Vector2, s64, float, float {
    // @Incomplete(sushi): This doesn't support wrapping more than 1 line.
    text_size := Vector2.{0, msdf.line_height * size};
    if text.count == 0  return text_size, -1, 0.0, 0.0;
    wrap_width: float;
    wrap_margin: float;
    wrap_index: s64;
    text_width: float;
    last_codepoint: u32;
    has_wrapped: bool;
    head := text.data;
    while head < text.data + text.count {
        codepoint, continuation := one_utf32_codepoint(head);
        glyph, success := find_glyph(msdf, codepoint);
        if success {
            advance_x := get_kerning(msdf, codepoint, last_codepoint);
            advance_x += glyph.advance_x;
            advance_x *= size;
            if codepoint == Unicode_Space && !has_wrapped {
                wrap_width  = text_width;
                wrap_index  = head - text.data;
                wrap_margin = advance_x;
            }
            text_width += advance_x;
            if text_width > max_width {
                text_size.x = wrap_width;
                text_width -= wrap_width + wrap_margin;
                has_wrapped = true;
            }
            last_codepoint = codepoint;
        }
        head += continuation;
    }
    if text_width > text_size.x  text_size.x = text_width;
    if !has_wrapped  wrap_index = -1;

    return text_size, wrap_index, wrap_width, text_width;
}

one_utf32_codepoint :: (head: *u8) -> u32, s64 #expand {
    codepoint, continuation := character_utf8_to_utf32(head, 8);
    return codepoint, continuation;
}

find_glyph :: (msdf: *MSDF_Font, codepoint: u32) -> *MSDF_Glyph, bool #expand {
    glyph, success := table_find(*msdf.glyph_lookup, codepoint);
    return glyph, success;
}

#scope_file

Unicode_Space :: 0x00000020;