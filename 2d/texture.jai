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
    id:     TextureId;
    width:  s32;
    height: s32;
    format: Pixel_Format;
}

Sampling_Mode :: enum GLenum {
    Nearest         :: GL_NEAREST;
    Linear          :: GL_LINEAR;
    NearestMipmap   :: GL_NEAREST_MIPMAP_NEAREST;
    LinearMipmap    :: GL_NEAREST_MIPMAP_LINEAR;
    BilinearMipmap  :: GL_LINEAR_MIPMAP_NEAREST;
    TrilinearMipmap :: GL_LINEAR_MIPMAP_LINEAR;
}

Wrap_Mode :: enum GLenum {
    Repeat         :: GL_REPEAT;
    MirroredRepeat :: GL_MIRRORED_REPEAT;
    ClampToEdge    :: GL_CLAMP_TO_EDGE;
    ClampToBorder  :: GL_CLAMP_TO_BORDER;
}

// create_image_from_file :: (filepath: string) -> Image {
//     path := temp_c_string(filepath);
//     image: Image = ---;
//     image.data = stbi_load(path, *image.width, *image.height, *image.format, PixelFormat.RGBA);
//     return image;
// }

load_texture :: (
    filepath: string,
    min_sampling := SamplingMode.TrilinearMipmap,
    mag_sampling := SamplingMode.Nearest,
    wrap_mode    := WrapMode.ClampToEdge
) -> Texture {
    path := temp_c_string(filepath);

    texture: Texture;
    image_data := stbi_load(path, *texture.width, *texture.height, xx *texture.format, xx PixelFormat.RGBA);
    defer stbi_image_free(image_data);

    glGenTextures(1, *texture.id);  assert(texture.id != 0);
    glBindTexture(GL_TEXTURE_2D, texture.id);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    if (texture.width * texture.height) % 8 == 0  glPixelStorei(GL_PACK_ALIGNMENT, 8); else
    if (texture.width * texture.height) % 4 == 0  glPixelStorei(GL_PACK_ALIGNMENT, 4); else
    if (texture.width * texture.height) % 2 == 0  glPixelStorei(GL_PACK_ALIGNMENT, 2);
    else glPixelStorei(GL_PACK_ALIGNMENT, 1);

    gl_format: GLenum;
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

free :: (image: Image) {
    if image.data == null  return;
    stbi_image_free(image.data);
}

free :: (texture: Texture) {
    if texture.id == 0  return;
    glDeleteTextures(1, *texture.id);
}

#scope_file

#import "stb_image";
