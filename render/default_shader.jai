DEFAULT_SHADER_TEXTURED         :: 0;
DEFAULT_SHADER_COLORED          :: 1;
DEFAULT_SHADER_TEXT             :: 2;
DEFAULT_SHADER_FRAMEBUFFER      :: 3;
DEFAULT_SHADER_BLOOM            :: 4;
DEFAULT_SHADER_BLOOM_DOWNSAMPLE :: 5;
DEFAULT_SHADER_BLOOM_UPSAMPLE   :: 6;

DEFAULT_SHADER_ATTRIB_POS         :: 0;
DEFAULT_SHADER_ATTRIB_UV1         :: 1;
DEFAULT_SHADER_ATTRIB_COLOR       :: 2;

DEFAULT_SHADER_UNIFORM_TEXT_PARAMS :: 6;

VERT_SHADER_RECT :: #string ___glsl
#version 450 core

layout(std140, binding = 0) uniform ShaderGlobals {
    mat4 Projection;
    mat4 ModelView;
    vec2 ScreenSize;
    vec2 ScreenPixelSize;
    float Time;
};

in vec3 vPosition;
in vec2 vUV;
in vec4 vColor;

out vec2 fUV;
out vec4 fColor;
out vec2 fScreenSize;
out vec2 fScreenPixelSize;
out float fTime;

void main() {
    gl_Position      = transpose(ModelView * Projection) * vec4(vPosition, 1.0);
    fUV              = vUV;
    fColor           = vColor;
    fScreenSize      = ScreenSize;
    fScreenPixelSize = ScreenPixelSize;
    fTime            = Time;
}

___glsl

VERT_SHADER_PRIMITIVE :: #string ___glsl
#version 450 core

layout(std140, binding = 0) uniform ShaderGlobals {
    mat4 Projection;
    mat4 ModelView;
    vec2 ScreenSize;
    vec2 ScreenPixelSize;
    float Time;
};

in vec3 vPosition;
in vec4 vColor;

out vec4 fColor;
out vec2 fScreenSize;
out vec2 fScreenPixelSize;
out float fTime;

void main() {
    gl_Position      = transpose(ModelView * Projection) * vec4(vPosition, 1.0);
    fColor           = vColor;
    fScreenSize      = ScreenSize;
    fScreenPixelSize = ScreenPixelSize;
    fTime            = Time;
}

___glsl

VERT_SHADER_FRAMEBUFFER :: #string ___glsl
#version 450 core

layout(std140, binding = 0) uniform ShaderGlobals {
    mat4 Projection;
    mat4 ModelView;
    vec2 ScreenSize;
    vec2 ScreenPixelSize;
    float Time;
};

in vec3 vPosition;
in vec2 vUV;

out vec2 fUV;
out vec4 fColor;
out vec2 fScreenSize;
out vec2 fScreenPixelSize;
out float fTime;

void main() {
    gl_Position      = vec4(vPosition.xy, 0.0, 1.0);
    fUV              = vUV;
    fColor           = vec4(1.0);
    fScreenSize      = ScreenSize;
    fScreenPixelSize = ScreenPixelSize;
    fTime            = Time;
}

___glsl

FRAG_SHADER_TEXTURED_RECT :: #string ___glsl
#version 450 core

in vec4 fColor;
in vec2 fUV;

out vec4 glFragColor;

uniform sampler2D Texture;

void main() {
    glFragColor = texture(Texture, fUV) * fColor;
}

___glsl

FRAG_SHADER_COLORED_RECT :: #string ___glsl
#version 450 core

in vec4 fColor;

out vec4 glFragColor;

void main() {
    glFragColor = fColor;
}

___glsl

FRAG_SHADER_TEXT :: #string ___glsl
#version 450 core

in vec2 fUV;
in vec4 fColor;

out vec4 glFragColor;

uniform sampler2D Texture;

layout(location = 6) uniform vec2 fTextParams;

float msdf_median(float r, float g, float b, float a) {
	return min(max(min(r, g), min(max(r, g), b)), a);
}

void main() {
    float pixel_range  = fTextParams.x;
    float outline_size = fTextParams.y;

    vec4 msd = texture(Texture, fUV);
    vec2 msdf_size = vec2(textureSize(Texture, 0));
    vec2 dest_size = vec2(1.0) / fwidth(fUV);
    float pixel_size = max(0.5 * dot((vec2(pixel_range) / msdf_size), dest_size), 1.0);
    float signed_dist = msdf_median(msd.r, msd.g, msd.b, msd.a) - 0.5;

    glFragColor = fColor;

    if (outline_size > 0.0) {
        float outline_range = clamp(outline_size, 0.0, pixel_range / 2.0) / pixel_range;
        glFragColor.a *= clamp((signed_dist + outline_range) * pixel_size, 0.0, 1.0);
    } else {
        glFragColor.a *= clamp(signed_dist * pixel_size + 0.5, 0.0, 1.0);
    }
}
___glsl
