DEFAULT_SHADER_TEXTURED    :: 0;
DEFAULT_SHADER_COLORED     :: 1;
DEFAULT_SHADER_FRAMEBUFFER :: 2;

DEFAULT_SHADER_VERTEX_POS   :: 0;
DEFAULT_SHADER_VERTEX_UV1   :: 1;
DEFAULT_SHADER_VERTEX_COLOR :: 2;

VERT_SHADER_RECT :: #string ___glsl
#version 430 core

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

VERT_SHADER_FRAMEBUFFER :: #string ___glsl
#version 430 core

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
    gl_Position      = vec4(vPosition.xy, 0.0, 1.0);
    fUV              = vUV;
    fColor           = vColor;
    fScreenSize      = ScreenSize;
    fScreenPixelSize = ScreenPixelSize;
    fTime            = Time;
}

___glsl

FRAG_SHADER_TEXTURED_RECT :: #string ___glsl
#version 430 core

in vec2 fUV;
in vec4 fColor;
in vec2 fScreenPixelSize;

out vec4 glFragColor;

uniform sampler2D Texture;

void main() {
    glFragColor = texture(Texture, fUV) * fColor;
}

___glsl

FRAG_SHADER_COLORED_RECT :: #string ___glsl
#version 430 core

in vec4 fColor;

out vec4 glFragColor;

void main() {
    glFragColor = fColor;
}

___glsl
