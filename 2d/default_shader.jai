DEFAULT_SHADER_TEXTURED :: 0;
DEFAULT_SHADER_COLORED  :: 1;

DEFAULT_SHADER_VERTEX_POS   :: 0;
DEFAULT_SHADER_VERTEX_UV1   :: 1;
DEFAULT_SHADER_VERTEX_COLOR :: 2;

VERT_SHADER_RECT :: #string ___glsl
#version 430 core

in vec3 vPos;
in vec2 vUV;
in vec4 vColor;

out vec2 fUV;
out vec4 fColor;

uniform mat4 mvpMatrix;

void main() {
    gl_Position = mvpMatrix * vec4(vPos, 1.0);
    fUV         = vUV;
    fColor      = vColor;
}

___glsl

FRAG_SHADER_TEXTURED_RECT :: #string ___glsl
#version 430 core

in vec2 fUV;
in vec4 fColor;

out vec4 glFragColor;

uniform sampler2D Tex;

void main() {
    glFragColor = texture(Tex, fUV) * fColor;
}

___glsl

FRAG_SHADER_COLORED_RECT :: #string ___glsl
#version 430 core

in vec2 fUV;
in vec4 fColor;

out vec4 glFragColor;

void main() {
    glFragColor = fColor;
}

___glsl
