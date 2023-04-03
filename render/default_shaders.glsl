@vs vs
@hlsl_options flip_vert_y
in vec4 vPosUV;
out vec2 fUV;

void main() {
    gl_Position = vec4(vPosUV.xy, 0.0, 1.0);
    fUV = vPosUV.zw;
}
@end

@fs default_fs
in vec2 fUV;
out vec4 COLOR;

uniform sampler2D TEXTURE;

layout(binding=0) uniform default_data {
    vec4 color;
};

void main() {
    COLOR = texture(TEXTURE, fUV) * color;
}
@end

@fs circle_fs
in vec2 fUV;
out vec4 COLOR;

uniform sampler2D TEXTURE;

layout(binding=0) uniform circle_data {
    vec4 color;
    vec2 radius;
};

float circle(vec2 _position, float _inner_radius, float _outer_radius) {
    vec2 distance = _position - vec2(0.5);
    return (1.0 - smoothstep(
        _outer_radius - (_outer_radius * 0.01),
        _outer_radius + (_outer_radius * 0.01),
        dot(distance, distance) * 4.0
    )) - (1.0 - smoothstep(
        _inner_radius - (_inner_radius * 0.01),
        _inner_radius + (_inner_radius * 0.01),
        dot(distance, distance) * 4.0
    ));
}

void main() {
    COLOR = texture(TEXTURE, fUV);
    COLOR *= vec4(color.rgb, circle(fUV, radius.x, radius.y) * color.a);
}
@end

@fs text_fs
in vec2 fUV;
out vec4 COLOR;

uniform sampler2D TEXTURE;

layout(binding=0) uniform text_data {
    vec4 color;
    vec2 text_params;
};

float msdf_median(float r, float g, float b, float a) {
    return min(max(min(r, g), min(max(r, g), b)), a);
}

void main() {
    float pixel_range  = text_params.x;
    float outline_size = text_params.y;

    vec4 msd = texture(TEXTURE, fUV);
    vec2 msdf_size = vec2(textureSize(TEXTURE, 0));
    vec2 dest_size = vec2(1.0) / fwidth(fUV);
    float pixel_size = max(0.5 * dot((vec2(pixel_range) / msdf_size), dest_size), 1.0);
    float signed_dist = msdf_median(msd.r, msd.g, msd.b, msd.a) - 0.5;

    COLOR = color;

    if (outline_size > 0.0) {
        float outline_range = clamp(outline_size, 0.0, pixel_range / 2.0) / pixel_range;
        COLOR.a *= clamp((signed_dist + outline_range) * pixel_size, 0.0, 1.0);
    } else {
        COLOR.a *= clamp(signed_dist * pixel_size + 0.5, 0.0, 1.0);
    }
}
@end

@program default vs default_fs
@program circle  vs circle_fs
@program text    vs text_fs
