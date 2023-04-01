// Font :: struct {
//     texture:   Texture;
//     glyphs: [] Glyph_Info;
//     size: float;
// }

// Glyph_Info :: struct {
//     src:  Vector2;
//     dst:  Vector2;
//     size: Vector2;
//     advance_x: float;
// }

// load_font :: (filepath: string, font_size: float) -> Font, bool {
//     file, success := read_entire_file(filepath);
//     if !success  return .{}, false;
//     defer free(file);

//     font_info: ttf.Fontinfo;
//     if !ttf.init_font(*font_info, file.data, 0)  return .{}, false;

//     bitmap: [] u8;
//     texture_size: s32 = 32;
//     chars: [96] ttf.Packedchar;
//     defer free(bitmap.data);
//     while true {
//         bitmap.count = texture_size * texture_size;
//         bitmap.data = alloc(bitmap.count);
//         pack_context: ttf.PackContext;
//         ttf.pack_begin(*pack_context, bitmap.data, texture_size, texture_size, 0, 1, null);
//         defer ttf.pack_end(*pack_context);
//         ttf.pack_set_oversampling(*pack_context, 1, 1);
//         if ttf.pack_font_range(*pack_context, file.data, 0, font_size, 32, 95, chars.data)  break;
//         free(bitmap.data);
//         texture_size *= 2;
//     }

//     ascent, descent, line_gap: s32;
//     ttf.get_font_v_metrics(*font_info, *ascent, *descent, *line_gap);
//     scale := ttf.scale_for_pixel_height(*font_info, font_size);
//     offset_y := cast(float) ascent * scale;

//     font: Font;
//     font.size = font_size;

//     font.glyphs = NewArray(96, Glyph_Info);
//     for 0..chars.count-1 {
//         info := chars[it];
//         font.glyphs[it].src.x  = cast(float) info.x0;
//         font.glyphs[it].src.y  = cast(float) info.y0;
//         font.glyphs[it].dst.x  = info.xoff;
//         font.glyphs[it].dst.y  = info.yoff + offset_y;
//         font.glyphs[it].size.x = cast(float) (info.x1 - info.x0);
//         font.glyphs[it].size.y = cast(float) (info.y1 - info.y0);
//         font.glyphs[it].advance_x = info.xadvance;
//     }

//     font.texture = create_grayscale_texture(bitmap, texture_size, texture_size);
//     return font, true;
// }

// // @Fix(sushi): Get a better solution for this terrible stroke effect.
// //  Maybe just bake out the assets? That feels kinda bad.
// load_font :: (filepath: string, font_size: float, stroke: s32) -> Font, bool {
//     file, success := read_entire_file(filepath);
//     if !success  return .{}, false;
//     defer free(file);

//     font_info: ttf.Fontinfo;
//     if !ttf.init_font(*font_info, file.data, 0)  return .{}, false;

//     bitmap: [] u8;
//     texture_size: s32 = 32;
//     chars: [96] ttf.Packedchar;
//     defer free(bitmap.data);
//     while true {
//         bitmap.count = texture_size * texture_size;
//         bitmap.data = alloc(bitmap.count);
//         pack_context: ttf.PackContext;
//         ttf.pack_begin(*pack_context, bitmap.data, texture_size, texture_size, 0, stroke + 3, null);
//         defer ttf.pack_end(*pack_context);
//         ttf.pack_set_oversampling(*pack_context, 1, 1);
//         if ttf.pack_font_range(*pack_context, file.data, 0, font_size, 32, 95, chars.data)  break;
//         free(bitmap.data);
//         texture_size *= 2;
//     }

//     ascent, descent, line_gap: s32;
//     ttf.get_font_v_metrics(*font_info, *ascent, *descent, *line_gap);
//     scale := ttf.scale_for_pixel_height(*font_info, font_size);
//     offset_y := cast(float) ascent * scale;

//     font: Font;
//     font.size = font_size;

//     strokef := cast(float) stroke;
//     font.glyphs = NewArray(96, Glyph_Info);
//     for 0..chars.count-1 {
//         info := chars[it];
//         font.glyphs[it].src.x  = cast(float) info.x0 - strokef + 1;
//         font.glyphs[it].src.y  = cast(float) info.y0 - strokef + 1;
//         font.glyphs[it].dst.x  = info.xoff - strokef;
//         font.glyphs[it].dst.y  = info.yoff + offset_y - strokef;
//         font.glyphs[it].size.x = cast(float) (info.x1 + strokef) - font.glyphs[it].src.x - 1;
//         font.glyphs[it].size.y = cast(float) (info.y1 + strokef) - font.glyphs[it].src.y - 1;
//         font.glyphs[it].advance_x = info.xadvance;
//     }

//     dest_bitmap: [] u8;
//     dest_bitmap.count = texture_size * texture_size * 2;
//     dest_bitmap.data = alloc(bitmap.count * 2);
//     memset(dest_bitmap.data, 0, dest_bitmap.count);
//     defer free(dest_bitmap.data);

//     stroke_circle_length := cast(s32) ceil(sqrt(strokef * strokef * 2));
//     max_value: u8 = ---;
//     index: s64 = ---;
//     for y: stroke..texture_size-stroke-1 {
//         for x: stroke..texture_size-stroke-1 {
//             max_value = 0;
//             for dy: -stroke..stroke {
//                 for dx: -stroke..stroke {
//                     if dx * dx + dy * dy > stroke_circle_length  continue;
//                     index = (y + dy) * texture_size + x + dx;
//                     if bitmap[index] > max_value  max_value = bitmap[index];
//                 }
//             }

//             dest_bitmap[(y * texture_size + x) * 2] = bitmap[y * texture_size + x];
//             dest_bitmap[(y * texture_size + x) * 2 + 1] = max_value;
//         }
//     }

//     font.texture = create_font_texture(dest_bitmap, texture_size, texture_size);
//     return font, true;
// }

// free_font :: (font: Font) {
//     free(font.glyphs.data);
//     free_texture(font.texture);
// }

// measure_text :: (font: Font, text: string) -> Vector2 {
//     size: Vector2 = ---;
//     size.x = 0;
//     size.y = font.size;
//     if text.count == 0  return size;
//     for 0..text.count-1 {
//         if text[it] < 32 || text[it] >= 128  continue;
//         size.x += font.glyphs[text[it] - 32].advance_x;
//     }
//     return size;
// }

// #scope_file

// #import "File";
// ttf :: #import "stb_truetype";
