Texture_Id :: GLuint;

Pixel_Format :: enum s32 {
    None      :: 0;
    Gray      :: 1;
    GrayAlpha :: 2;
    RGB       :: 3;
    RGBA      :: 4;
}

GL_Pixel_Format :: GLuint.[
    GL_ZERO,
    GL_RED,
    GL_RG,
    GL_RGB,
    GL_RGBA,
];

Image :: struct {
    data:   *u8;
    width:  s32;
    height: s32;
    format: Pixel_Format;

#place width;
    size: Point2 = ---;
}

Texture :: struct {
    id:     Texture_Id;
    width:  float;
    height: float;
    format: Pixel_Format;

#place width;
    size: Vector2 = ---;
}

Sampling_Mode :: enum GLint {
    Nearest          :: GL_NEAREST;
    Linear           :: GL_LINEAR;
    Nearest_Mipmap   :: GL_NEAREST_MIPMAP_NEAREST;
    Linear_Mipmap    :: GL_NEAREST_MIPMAP_LINEAR;
    Bilinear_Mipmap  :: GL_LINEAR_MIPMAP_NEAREST;
    Trilinear_Mipmap :: GL_LINEAR_MIPMAP_LINEAR;
}

Wrap_Mode :: enum GLint {
    Repeat          :: GL_REPEAT;
    Mirrored_Repeat :: GL_MIRRORED_REPEAT;
    Clamp_To_Edge   :: GL_CLAMP_TO_EDGE;
    Clamp_To_Border :: GL_CLAMP_TO_BORDER;
}

SWIZZLE_RGB_MASK   :: GLint.[GL_RED, GL_RED, GL_RED, GL_ONE];
SWIZZLE_ALPHA_MASK :: GLint.[GL_ONE, GL_ONE, GL_ONE, GL_RED];

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
    min_sampling  := Sampling_Mode.Trilinear_Mipmap,
    mag_sampling  := Sampling_Mode.Linear,
    wrap_mode     := Wrap_Mode.Clamp_To_Edge,
    $pixel_format := Pixel_Format.RGBA
) -> Texture {
    path := temp_c_string(filepath);

    texture: Texture = ---;
    width, height: s32 = ---;
    image_data := stbi_load(path, *width, *height, cast,no_check(*s32) *texture.format, cast,no_check(s32) pixel_format);
    defer stbi_image_free(image_data);
    texture.width  = cast(float) width;
    texture.height = cast(float) height;

    glGenTextures(1, *texture.id);  assert(texture.id != 0);
    glBindTexture(GL_TEXTURE_2D, texture.id);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, cast,no_check(GLint) min_sampling);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, cast,no_check(GLint) mag_sampling);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S,     cast,no_check(GLint) wrap_mode);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T,     cast,no_check(GLint) wrap_mode);

         if (width * height) % 8 == 0  glPixelStorei(GL_PACK_ALIGNMENT, 8);
    else if (width * height) % 4 == 0  glPixelStorei(GL_PACK_ALIGNMENT, 4);
    else if (width * height) % 2 == 0  glPixelStorei(GL_PACK_ALIGNMENT, 2);
    else                               glPixelStorei(GL_PACK_ALIGNMENT, 1);

    if #complete texture.format == {
    case .None;      assert(false, "Failed to decode image format.");
    case .Gray;      glTexImage2D(GL_TEXTURE_2D, 0, GL_R8,    cast,no_check(GLsizei) texture.width, cast,no_check(GLsizei) texture.height, 0, GL_Pixel_Format[pixel_format], GL_UNSIGNED_BYTE, image_data);
    case .GrayAlpha; glTexImage2D(GL_TEXTURE_2D, 0, GL_RG8,   cast,no_check(GLsizei) texture.width, cast,no_check(GLsizei) texture.height, 0, GL_Pixel_Format[pixel_format], GL_UNSIGNED_BYTE, image_data);
    case .RGB;       glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB8,  cast,no_check(GLsizei) texture.width, cast,no_check(GLsizei) texture.height, 0, GL_Pixel_Format[pixel_format], GL_UNSIGNED_BYTE, image_data);
    case .RGBA;      glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, cast,no_check(GLsizei) texture.width, cast,no_check(GLsizei) texture.height, 0, GL_Pixel_Format[pixel_format], GL_UNSIGNED_BYTE, image_data);
    case;
        warn(.Render, "Parsed invalid texture format for file: %", filepath);
        return .{};
    }

    // #if pixel_format == .Gray {
    //     glTexParameteriv(GL_TEXTURE_2D, GL_TEXTURE_SWIZZLE_RGBA, SWIZZLE_ALPHA_MASK.data);
    // }

    glGenerateMipmap(GL_TEXTURE_2D);
    return texture;
}

create_texture :: (
    image: Image,
    min_sampling := Sampling_Mode.Trilinear_Mipmap,
    mag_sampling := Sampling_Mode.Linear,
    wrap_mode    := Wrap_Mode.Clamp_To_Edge
) -> Texture {
    texture: Texture = ---;
    texture.width  = cast(float) image.width;
    texture.height = cast(float) image.height;
    texture.format = image.format;

    glGenTextures(1, *texture.id);  assert(texture.id != 0);
    glBindTexture(GL_TEXTURE_2D, texture.id);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, min_sampling);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, mag_sampling);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S,     wrap_mode);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T,     wrap_mode);

         if (width * height) % 8 == 0  glPixelStorei(GL_PACK_ALIGNMENT, 8);
    else if (width * height) % 4 == 0  glPixelStorei(GL_PACK_ALIGNMENT, 4);
    else if (width * height) % 2 == 0  glPixelStorei(GL_PACK_ALIGNMENT, 2);
    else                               glPixelStorei(GL_PACK_ALIGNMENT, 1);

    if #complete texture.format == {
    case .None;      assert(false, "Failed to decode image format.");
    case .Gray;      glTexImage2D(GL_TEXTURE_2D, 0, GL_R8,    cast,no_check(GLsizei) image.width, cast,no_check(GLsizei) image.height, 0, GL_Pixel_Format[pixel_format], GL_UNSIGNED_BYTE, image.data);
    case .GrayAlpha; glTexImage2D(GL_TEXTURE_2D, 0, GL_RG8,   cast,no_check(GLsizei) image.width, cast,no_check(GLsizei) image.height, 0, GL_Pixel_Format[pixel_format], GL_UNSIGNED_BYTE, image.data);
    case .RGB;       glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB8,  cast,no_check(GLsizei) image.width, cast,no_check(GLsizei) image.height, 0, GL_Pixel_Format[pixel_format], GL_UNSIGNED_BYTE, image.data);
    case .RGBA;      glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, cast,no_check(GLsizei) image.width, cast,no_check(GLsizei) image.height, 0, GL_Pixel_Format[pixel_format], GL_UNSIGNED_BYTE, image.data);
    case;
        warn(.Render, "Parsed invalid texture format for image.");
        return .{};
    }

    glGenerateMipmap(GL_TEXTURE_2D);
    return texture;
}

create_grayscale_texture :: (buffer: [] $T, width: s32, height: s32, wrap_mode := Wrap_Mode.Clamp_To_Edge, $swizzle_rgb := false) -> Texture #modify {
    if T != u8 && T != float {
        return false, "Buffer must be u8 or float.";
    }
    return true;
} {
    texture: Texture = ---;
    texture.width  = cast(float) width;
    texture.height = cast(float) height;

    glGenTextures(1, *texture.id);  assert(texture.id != 0);
    glBindTexture(GL_TEXTURE_2D, texture.id);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S,     cast,no_check(GLint) wrap_mode);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T,     cast,no_check(GLint) wrap_mode);

         if (width * height) % 8 == 0  glPixelStorei(GL_PACK_ALIGNMENT, 8);
    else if (width * height) % 4 == 0  glPixelStorei(GL_PACK_ALIGNMENT, 4);
    else if (width * height) % 2 == 0  glPixelStorei(GL_PACK_ALIGNMENT, 2);
    else                                               glPixelStorei(GL_PACK_ALIGNMENT, 1);

    #if T == u8 {
        glTexImage2D(GL_TEXTURE_2D, 0, GL_R8,   cast,no_check(GLsizei) width, cast,no_check(GLsizei) height, 0, GL_RED, GL_UNSIGNED_BYTE, buffer.data);
    } else {
        glTexImage2D(GL_TEXTURE_2D, 0, GL_R32F, cast,no_check(GLsizei) width, cast,no_check(GLsizei) height, 0, GL_RED, GL_FLOAT, buffer.data);
    }

    #if swizzle_rgb {
        glTexParameteriv(GL_TEXTURE_2D, GL_TEXTURE_SWIZZLE_RGBA, SWIZZLE_RGB_MASK.data);
    } else {
        glTexParameteriv(GL_TEXTURE_2D, GL_TEXTURE_SWIZZLE_RGBA, SWIZZLE_ALPHA_MASK.data);
    }

    glGenerateMipmap(GL_TEXTURE_2D);
    return texture;
}

create_font_texture :: (buffer: [] u8, width: s32, height: s32, wrap_mode := Wrap_Mode.Clamp_To_Edge) -> Texture {
    texture: Texture = ---;
    texture.width  = cast(float) width;
    texture.height = cast(float) height;

    glGenTextures(1, *texture.id);  assert(texture.id != 0);
    glBindTexture(GL_TEXTURE_2D, texture.id);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S,     cast,no_check(GLint) wrap_mode);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T,     cast,no_check(GLint) wrap_mode);

         if (width * height) % 8 == 0  glPixelStorei(GL_PACK_ALIGNMENT, 8);
    else if (width * height) % 4 == 0  glPixelStorei(GL_PACK_ALIGNMENT, 4);
    else if (width * height) % 2 == 0  glPixelStorei(GL_PACK_ALIGNMENT, 2);
    else                                               glPixelStorei(GL_PACK_ALIGNMENT, 1);

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RG8, cast,no_check(GLsizei) width, cast,no_check(GLsizei) height, 0, GL_RG, GL_UNSIGNED_BYTE, buffer.data);

    swizzle_mask :: GLint.[GL_RED, GL_RED, GL_RED, GL_GREEN];
    glTexParameteriv(GL_TEXTURE_2D, GL_TEXTURE_SWIZZLE_RGBA, swizzle_mask.data);

    glGenerateMipmap(GL_TEXTURE_2D);
    return texture;
}

get_sampling :: (texture_id: Texture_Id) -> Sampling_Mode, Sampling_Mode {
    min_sampling, mag_sampling: Sampling_Mode = ---;
    glBindTexture(GL_TEXTURE_2D, texture_id);
    glGetTexParameteriv(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, cast,no_check(*GLint) *min_sampling);
    glGetTexParameteriv(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, cast,no_check(*GLint) *mag_sampling);
    return min_sampling, mag_sampling;
}

get_wrapping :: (texture_id: Texture_Id) -> Wrap_Mode, Wrap_Mode {
    wrap_mode_u, wrap_mode_v: Wrap_Mode = ---;
    glBindTexture(GL_TEXTURE_2D, texture_id);
    glGetTexParameteriv(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, cast,no_check(*GLint) *wrap_mode_u);
    glGetTexParameteriv(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, cast,no_check(*GLint) *wrap_mode_v);
    return wrap_mode_u, wrap_mode_v;
}

set_sampling :: (texture_id: Texture_Id, min_sampling: Sampling_Mode, mag_sampling: Sampling_Mode) {
    glBindTexture(GL_TEXTURE_2D, texture_id);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, cast,no_check(GLint) min_sampling);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, cast,no_check(GLint) mag_sampling);
    glGenerateMipmap(GL_TEXTURE_2D);
}

set_wrapping :: (texture_id: Texture_Id, wrap_mode_u: Wrap_Mode, wrap_mode_v: Wrap_Mode) {
    glBindTexture(GL_TEXTURE_2D, texture_id);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, cast,no_check(GLint) wrap_mode_u);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, cast,no_check(GLint) wrap_mode_v);
    glGenerateMipmap(GL_TEXTURE_2D);
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
    if texture.id == 0  return;
    glDeleteTextures(1, *texture.id);
}

#scope_file

#import "stb_image";
