Texture_Id :: GLuint;

Pixel_Format :: enum s32 {
    None      :: 0;
    Gray      :: 1;
    GrayAlpha :: 2;
    RGB       :: 3;
    RGBA      :: 4;
}

Image :: struct {
    pixels: *u8;
    width:  s32;
    height: s32;
    format: Pixel_Format;
}

Texture :: struct {
    id:     Texture_Id;
    width:  s32;
    height: s32;
    format: Pixel_Format;
}

Sampling_Mode :: enum GLenum {
    Nearest          :: GL_NEAREST;
    Linear           :: GL_LINEAR;
    Nearest_Mipmap   :: GL_NEAREST_MIPMAP_NEAREST;
    Linear_Mipmap    :: GL_NEAREST_MIPMAP_LINEAR;
    Bilinear_Mipmap  :: GL_LINEAR_MIPMAP_NEAREST;
    Trilinear_Mipmap :: GL_LINEAR_MIPMAP_LINEAR;
}

Wrap_Mode :: enum GLenum {
    Repeat          :: GL_REPEAT;
    Mirrored_Repeat :: GL_MIRRORED_REPEAT;
    Clamp_To_Edge   :: GL_CLAMP_TO_EDGE;
    Clamp_To_Border :: GL_CLAMP_TO_BORDER;
}

// create_image_from_file :: (filepath: string) -> Image {
//     path := temp_c_string(filepath);
//     image: Image = ---;
//     image.data = stbi_load(path, *image.width, *image.height, *image.format, PixelFormat.RGBA);
//     return image;
// }

load_texture :: (
    filepath: string,
    min_sampling := Sampling_Mode.Trilinear_Mipmap,
    mag_sampling := Sampling_Mode.Nearest,
    wrap_mode    := Wrap_Mode.Clamp_To_Edge
) -> Texture {
    path := temp_c_string(filepath);

    texture: Texture = ---;
    image_data := stbi_load(path, *texture.width, *texture.height, xx *texture.format, xx Pixel_Format.RGBA);
    defer stbi_image_free(image_data);

    glGenTextures(1, *texture.id);  assert(texture.id != 0);
    glBindTexture(GL_TEXTURE_2D, texture.id);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

         if (texture.width * texture.height) % 8 == 0  glPixelStorei(GL_PACK_ALIGNMENT, 8);
    else if (texture.width * texture.height) % 4 == 0  glPixelStorei(GL_PACK_ALIGNMENT, 4);
    else if (texture.width * texture.height) % 2 == 0  glPixelStorei(GL_PACK_ALIGNMENT, 2);
    else                                               glPixelStorei(GL_PACK_ALIGNMENT, 1);

    if texture.format == {
    case .Gray;      glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, xx texture.width, xx texture.height, 0, GL_RED , GL_UNSIGNED_BYTE, image_data);
    case .GrayAlpha; glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, xx texture.width, xx texture.height, 0, GL_RG  , GL_UNSIGNED_BYTE, image_data);
    case .RGB;       glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, xx texture.width, xx texture.height, 0, GL_RGB , GL_UNSIGNED_BYTE, image_data);
    case .RGBA;      glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, xx texture.width, xx texture.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, image_data);
    case;
        warn(.Render, "Parsed invalid texture format for file: %", filepath);
        return .{};
    }

    glGenerateMipmap(GL_TEXTURE_2D);
    return texture;
}

create_font_texture :: (buffer: [] u8, width: s32, height: s32) -> Texture {
    texture: Texture = ---;
    texture.width  = width;
    texture.height = height;

    glGenTextures(1, *texture.id);  assert(texture.id != 0);
    glBindTexture(GL_TEXTURE_2D, texture.id);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

         if (texture.width * texture.height) % 8 == 0  glPixelStorei(GL_PACK_ALIGNMENT, 8);
    else if (texture.width * texture.height) % 4 == 0  glPixelStorei(GL_PACK_ALIGNMENT, 4);
    else if (texture.width * texture.height) % 2 == 0  glPixelStorei(GL_PACK_ALIGNMENT, 2);
    else                                               glPixelStorei(GL_PACK_ALIGNMENT, 1);

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, xx texture.width, xx texture.height, 0, GL_RED, GL_UNSIGNED_BYTE, buffer.data);

    swizzle_mask :: GLint.[GL_ONE, GL_ONE, GL_ONE, GL_RED];
    glTexParameteriv(GL_TEXTURE_2D, GL_TEXTURE_SWIZZLE_RGBA, swizzle_mask.data);

    glGenerateMipmap(GL_TEXTURE_2D);
    return texture;
}

free_image :: (image: Image) {
    if image.data == null  return;
    stbi_image_free(image.data);
}

free_texture :: (texture: Texture) {
    if texture.id == 0  return;
    glDeleteTextures(1, *texture.id);
}

#scope_file

#import "stb_image";
