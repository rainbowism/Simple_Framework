Texture_Id :: sg_image;

Pixel_Format :: enum s32 {
    None      :: 0;
    Gray      :: 1;
    GrayAlpha :: 2;
    RGBA      :: 4;
    RGB       :: RGBA;
}

Image :: struct {
    data:   *u8;
    width:  s32;
    height: s32;
    format: Pixel_Format;

#place width;
    size: Point2 = ---;
}

Texture :: struct {
    id: Texture_Id;
    width:  float;
    height: float;
    format: Pixel_Format;

#place width;
    size: Vector2 = ---;
}

Sampling_Mode :: enum s32 {
    Nearest          :: sg_filter.NEAREST;
    Linear           :: sg_filter.LINEAR;
    Nearest_Mipmap   :: sg_filter.NEAREST_MIPMAP_NEAREST;
    Linear_Mipmap    :: sg_filter.NEAREST_MIPMAP_LINEAR;
    Bilinear_Mipmap  :: sg_filter.LINEAR_MIPMAP_NEAREST;
    Trilinear_Mipmap :: sg_filter.LINEAR_MIPMAP_LINEAR;
}

Wrap_Mode :: enum s32 {
    Repeat          :: sg_wrap.REPEAT;
    Mirrored_Repeat :: sg_wrap.MIRRORED_REPEAT;
    Clamp_To_Edge   :: sg_wrap.CLAMP_TO_EDGE;
    Clamp_To_Border :: sg_wrap.CLAMP_TO_BORDER;
}

load_image :: (filepath: string) -> Image {
    path := temp_c_string(filepath);
    image: Image = ---;
    image.data = stbi_load(path, *image.width, *image.height, cast,no_check(*s32) *image.format, 0);
    return image;
}

load_from_memory :: (buffer: string) -> Image {
    image: Image = ---;
    image.data = stbi_load_from_memory(buffer.data, cast,no_check(s32) buffer.count, *image.width, *image.height, cast,no_check(*s32) *image.format, 0);
    return image;
}

load_texture :: (
    filepath: string,
    min_sampling  := Sampling_Mode.Linear,
    mag_sampling  := Sampling_Mode.Linear,
    wrap_mode     := Wrap_Mode.Clamp_To_Edge,
    $pixel_format := Pixel_Format.RGBA
) -> Texture, bool {
    path := temp_c_string(filepath);

    texture: Texture = ---;
    width, height: s32 = ---;
    image_data := stbi_load(path, *width, *height, xx,no_check *texture.format, xx,no_check pixel_format);
    defer stbi_image_free(image_data);
    texture.width  = cast(float) width;
    texture.height = cast(float) height;

    target_format: sg_pixel_format = ---;
    if #complete pixel_format == {
    case .Gray;       target_format = .R8;
    case .GrayAlpha;  target_format = .RG8;
    case .RGBA;       target_format = .RGBA8;
    case .None;
        warn(.Render, "Failed to load image file: %", filepath);
        return .{}, false;
    case;
        warn(.Render, "Parsed invalid texture format for file: %", filepath);
        return .{}, false;
    }

    // @Todo: Generate mipmaps
    image_desc: sg_image_desc;
    image_desc.width  = width;
    image_desc.height = height;
    image_desc.pixel_format = target_format;
    image_desc.min_filter   = cast(sg_filter) min_sampling;
    image_desc.mag_filter   = cast(sg_filter) mag_sampling;
    image_desc.wrap_u       = xx,no_check wrap_mode;
    image_desc.wrap_v       = xx,no_check wrap_mode;
    image_desc.data.subimage[0][0] = sg_range.{image_data, xx,no_check (width * height * xx texture.format)};
#if Debug_Render {
    label := sprint("%\0", filepath);
    image_desc.label = label.data;
}
    texture.id = sg_make_image(*image_desc);
    return texture, sg_query_image_state(texture.id) == .VALID;
}

load_texture_from_memory :: (
    buffer: string,
    min_sampling  := Sampling_Mode.Linear,
    mag_sampling  := Sampling_Mode.Linear,
    wrap_mode     := Wrap_Mode.Clamp_To_Edge,
    $pixel_format := Pixel_Format.RGBA
) -> Texture, bool {
    texture: Texture = ---;
    width, height: s32 = ---;
    image_data := stbi_load_from_memory(buffer.data, xx,no_check buffer.count, *width, *height, xx,no_check *texture.format, xx,no_check pixel_format);
    defer stbi_image_free(image_data);
    texture.width  = cast(float) width;
    texture.height = cast(float) height;

    target_format: sg_pixel_format = ---;
    if #complete pixel_format == {
    case .Gray;       target_format = .R8;
    case .GrayAlpha;  target_format = .RG8;
    case .RGBA;       target_format = .RGBA8;
    case .None;
        warn(.Render, "Failed to load image file.");
        return .{}, false;
    case;
        warn(.Render, "Parsed invalid texture format for file.");
        return .{}, false;
    }

    // @Todo: Generate mipmaps
    image_desc: sg_image_desc;
    image_desc.width  = width;
    image_desc.height = height;
    image_desc.pixel_format = target_format;
    image_desc.min_filter   = cast(sg_filter) min_sampling;
    image_desc.mag_filter   = cast(sg_filter) mag_sampling;
    image_desc.wrap_u       = xx,no_check wrap_mode;
    image_desc.wrap_v       = xx,no_check wrap_mode;
    image_desc.data.subimage[0][0] = sg_range.{image_data, xx,no_check (width * height * xx texture.format)};
#if Debug_Render {
    label := sprint("%\0", filepath);
    image_desc.label = label.data;
}
    texture.id = sg_make_image(*image_desc);
    return texture, sg_query_image_state(texture.id) == .VALID;
}

free_image :: (image: Image) {
    if image.data == null  return;
    free(image.data);
}

free_stbi_image :: (image: Image) {
    if image.data == null  return;
    stbi_image_free(image.data);
}

free_texture :: (texture: Texture) {
    if texture.id == SG_INVALID_ID  return;
    sg_destroy_image(texture.id);
}

#scope_file

#import "stb_image";
