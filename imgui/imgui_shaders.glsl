@module ImGui

@vs vs
layout(location=0) in vec2 vPos;
layout(location=1) in vec2 vUV;
layout(location=2) in vec4 vColor;
out vec2 fUV;
out vec4 fColor;

uniform data {
    vec2 display_size;
};

void main() {
    gl_Position = vec4(((vPos / display_size) - 0.5) * vec2(2.0, -2.0), 0.5, 1.0);
    // gl_Position = vec4(vPos / display_size, 0.5, 1.0);
    fUV = vUV;
    fColor = vColor;
}
@end

@fs fs
in vec2 fUV;
in vec4 fColor;
out vec4 COLOR;

uniform sampler2D TEXTURE;

void main() {
    COLOR = texture(TEXTURE, fUV) * fColor;
}
@end

@program default vs fs
