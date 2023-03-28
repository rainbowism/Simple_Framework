Render_Bloom :: struct(chain_length: int) {
    fbo:  GLuint;
    strength: float = 0.35;
    mip_chain: [chain_length] Bloom_Mip;
}

Bloom_Mip :: struct {
    size:    Vector2;
    isize:   Point2;
    texture: GLuint;
}

init_render_bloom :: ($chain_length: int) -> *Render_Bloom(chain_length), bool {
    render_bloom := New(Render_Bloom(chain_length));

    glGenFramebuffers(1, *render_bloom.fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, render_bloom.fbo);
    defer glBindFramebuffer(GL_FRAMEBUFFER, 0);

    size: Vector2 = window.size;
    isize: Point2 = window.size_i;
    for 0..chain_length-1 {
        size  *= 0.5;
        isize /= 2;
        mip: Bloom_Mip = ---;
        mip.size  = size;
        mip.isize = isize;
        glGenTextures(1, *mip.texture);
        glBindTexture(GL_TEXTURE_2D, mip.texture);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_R11F_G11F_B10F, xx mip.isize.x, xx mip.isize.y, 0, GL_RGB, GL_FLOAT, null);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glBindTexture(GL_TEXTURE_2D, 0);

        render_bloom.mip_chain[it] = mip;
    }
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, render_bloom.mip_chain[0].texture, 0);
    glBindTexture(GL_TEXTURE_2D, 0);

    if glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE {
        return render_bloom, true;
    }

    destroy(render_bloom);
    return null, false;
}

destroy :: (render_bloom: *Render_Bloom) {
    for 0..render_bloom.chain_length-1{
        glDeleteTextures(1, *render_bloom.mip_chain[it].texture);
    }
    glDeleteFramebuffers(1, *render_bloom.fbo);
    free(render_bloom);
}

resize_render_bloom :: (render_bloom: *Render_Bloom, width: s32, height: s32) {
    glBindFramebuffer(GL_FRAMEBUFFER, render_bloom.fbo);
    size: Vector2 = ---;
    size.x = xx width;
    size.y = xx height;
    isize: Point2 = ---;
    isize.x = width;
    isize.y = height;
    for *mip: render_bloom.mip_chain {
        size *= 0.5;
        isize /= 2;
        mip.size = size;
        mip.size  = size;
        mip.isize = isize;
        glBindTexture(GL_TEXTURE_2D, mip.texture);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_R11F_G11F_B10F, xx mip.isize.x, xx mip.isize.y, 0, GL_RGB, GL_FLOAT, null);
    }
    glBindTexture(GL_TEXTURE_2D, 0);
}

render_bloom :: inline (render_bloom: *Render_Bloom, fbo: GLuint, source_texture: GLuint, filter_radius: float) {
    glBindFramebuffer(GL_FRAMEBUFFER, render_bloom.fbo);
    render_downsamples(render_bloom, source_texture);
    render_upsamples(render_bloom, filter_radius);

    glBindFramebuffer(GL_FRAMEBUFFER, fbo);

    glUseProgram(render_ctx.shaders.data[DEFAULT_SHADER_BLOOM].program);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE);
    defer glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    glViewport(0, 0, xx window.size_i.x, xx window.size_i.y);
    glUniform1f(0, render_bloom.strength);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, render_bloom.mip_chain[0].texture);
    render_quad();
}

render_downsamples :: (render_bloom: *Render_Bloom, source_texture: GLuint) {
    glUseProgram(render_ctx.shaders.data[DEFAULT_SHADER_BLOOM_DOWNSAMPLE].program);
    defer glUseProgram(0);

    glDisable(GL_BLEND);
    defer glEnable(GL_BLEND);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, source_texture);

    glUniform2fv(0, 1, *window.size.x);
    glUniform1i(1, 0); // enable Karis average
    for *mip: render_bloom.mip_chain {
        glViewport(0, 0, xx mip.isize.x, xx mip.isize.y);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, mip.texture, 0);

        render_quad();

        glUniform2fv(0, 1, *mip.size.x);
        glBindTexture(GL_TEXTURE_2D, mip.texture);
        if it_index == 0  glUniform1i(1, 1); // disable Karis average
    }
}

render_upsamples :: (render_bloom: *Render_Bloom, filter_radius: float) {
    glUseProgram(render_ctx.shaders.data[DEFAULT_SHADER_BLOOM_UPSAMPLE].program);
    defer glUseProgram(0);

    glBlendFunc(GL_ONE, GL_ONE);
    defer glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    glUniform1f(0, filter_radius);
    for < render_bloom.chain_length-1..1 {
        mip      := render_bloom.mip_chain[it];
        next_mip := render_bloom.mip_chain[it-1];

        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, mip.texture);
        glViewport(0, 0, xx next_mip.isize.x, xx next_mip.isize.y);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, next_mip.texture, 0);

        render_quad();
    }
}

FRAG_SHADER_BLOOM :: #string ___glsl
#version 330 core
#extension GL_ARB_explicit_uniform_location : require

in vec2 fUV;

out vec4 glFragColor;

uniform sampler2D Texture;
layout(location = 0) uniform float BloomStrength;

void main() {
    glFragColor = texture(Texture, fUV);
    glFragColor.rgb *= BloomStrength;
}

___glsl

FRAG_SHADER_BLOOM_DOWNSAMPLE :: #string ___glsl
#version 330 core
#extension GL_ARB_explicit_uniform_location : require

in vec2 fUV;

out vec3 glFragColor;

uniform sampler2D Texture;
layout(location = 0) uniform vec2 SourceSize;
layout(location = 1) uniform int MipLevel;

vec3 PowVec3(vec3 v, float p)
{
    return vec3(pow(v.x, p), pow(v.y, p), pow(v.z, p));
}

const float invGamma = 1.0 / 2.2;
vec3 ToSRGB(vec3 v)   { return PowVec3(v, invGamma); }

float sRGBToLuma(vec3 col)
{
	return dot(col, vec3(0.299, 0.587, 0.114));
}

float KarisAverage(vec3 col)
{
	// Formula is 1 / (1 + luma)
	float luma = sRGBToLuma(ToSRGB(col)) * 0.25;
	return 1.0 / (1.0 + luma);
}

void main() {
    float x = 1.0 / SourceSize.x;
    float y = 1.0 / SourceSize.y;

	// Take 13 samples around current texel:
	// a - b - c
	// - j - k -
	// d - e - f
	// - l - m -
	// g - h - i
	// === ('e' is the current texel) ===
	vec3 a = texture(Texture, vec2(fUV.x - 2*x, fUV.y + 2*y)).rgb;
	vec3 b = texture(Texture, vec2(fUV.x,       fUV.y + 2*y)).rgb;
	vec3 c = texture(Texture, vec2(fUV.x + 2*x, fUV.y + 2*y)).rgb;

	vec3 d = texture(Texture, vec2(fUV.x - 2*x, fUV.y)).rgb;
	vec3 e = texture(Texture, vec2(fUV.x,       fUV.y)).rgb;
	vec3 f = texture(Texture, vec2(fUV.x + 2*x, fUV.y)).rgb;

	vec3 g = texture(Texture, vec2(fUV.x - 2*x, fUV.y - 2*y)).rgb;
	vec3 h = texture(Texture, vec2(fUV.x,       fUV.y - 2*y)).rgb;
	vec3 i = texture(Texture, vec2(fUV.x + 2*x, fUV.y - 2*y)).rgb;

	vec3 j = texture(Texture, vec2(fUV.x - x, fUV.y + y)).rgb;
	vec3 k = texture(Texture, vec2(fUV.x + x, fUV.y + y)).rgb;
	vec3 l = texture(Texture, vec2(fUV.x - x, fUV.y - y)).rgb;
	vec3 m = texture(Texture, vec2(fUV.x + x, fUV.y - y)).rgb;

	// Apply weighted distribution:
	// 0.5 + 0.125 + 0.125 + 0.125 + 0.125 = 1
	// a,b,d,e * 0.125
	// b,c,e,f * 0.125
	// d,e,g,h * 0.125
	// e,f,h,i * 0.125
	// j,k,l,m * 0.5
	// This shows 5 square areas that are being sampled. But some of them overlap,
	// so to have an energy preserving downsample we need to make some adjustments.
	// The weights are the distributed, so that the sum of j,k,l,m (e.g.)
	// contribute 0.5 to the final color output. The code below is written
	// to effectively yield this sum. We get:
	// 0.125*5 + 0.03125*4 + 0.0625*4 = 1

	// Check if we need to perform Karis average on each block of 4 samples
	vec3 groups[5];
	if (MipLevel == 0) {
        // We are writing to mip 0, so we need to apply Karis average to each block
        // of 4 samples to prevent fireflies (very bright subpixels, leads to pulsating
        // artifacts).
        groups[0] = (a+b+d+e) * (0.125/4.0);
        groups[1] = (b+c+e+f) * (0.125/4.0);
        groups[2] = (d+e+g+h) * (0.125/4.0);
        groups[3] = (e+f+h+i) * (0.125/4.0);
        groups[4] = (j+k+l+m) * (0.5/4.0);
        groups[0] *= KarisAverage(groups[0]);
        groups[1] *= KarisAverage(groups[1]);
        groups[2] *= KarisAverage(groups[2]);
        groups[3] *= KarisAverage(groups[3]);
        groups[4] *= KarisAverage(groups[4]);
        glFragColor = groups[0]+groups[1]+groups[2]+groups[3]+groups[4];
        glFragColor = max(glFragColor, 0.0001);
    } else {
        glFragColor = e*0.125;                // ok
        glFragColor += (a+c+g+i)*0.03125;     // ok
        glFragColor += (b+d+f+h)*0.0625;      // ok
        glFragColor += (j+k+l+m)*0.125;       // ok
	}
}

___glsl

FRAG_SHADER_BLOOM_UPSAMPLE :: #string ___glsl
#version 330 core
#extension GL_ARB_explicit_uniform_location : require

in vec2 fUV;

out vec3 glFragColor;

uniform sampler2D Texture;
layout(location = 0) uniform float FilterRadius;

void main() {
    // The filter kernel is applied with a radius, specified in texture
    // coordinates, so that the radius will vary across mip resolutions.
    float x = FilterRadius;
    float y = FilterRadius;

    // Take 9 samples around current texel:
    // a - b - c
    // d - e - f
    // g - h - i
    // === ('e' is the current texel) ===
    vec3 a = texture(Texture, vec2(fUV.x - x, fUV.y + y)).rgb;
    vec3 b = texture(Texture, vec2(fUV.x,     fUV.y + y)).rgb;
    vec3 c = texture(Texture, vec2(fUV.x + x, fUV.y + y)).rgb;

    vec3 d = texture(Texture, vec2(fUV.x - x, fUV.y)).rgb;
    vec3 e = texture(Texture, vec2(fUV.x,     fUV.y)).rgb;
    vec3 f = texture(Texture, vec2(fUV.x + x, fUV.y)).rgb;

    vec3 g = texture(Texture, vec2(fUV.x - x, fUV.y - y)).rgb;
    vec3 h = texture(Texture, vec2(fUV.x,     fUV.y - y)).rgb;
    vec3 i = texture(Texture, vec2(fUV.x + x, fUV.y - y)).rgb;

    // Apply weighted distribution, by using a 3x3 tent filter:
    //  1   | 1 2 1 |
    // -- * | 2 4 2 |
    // 16   | 1 2 1 |
    glFragColor = e*4.0;
    glFragColor += (b+d+f+h)*2.0;
    glFragColor += (a+c+g+i);
    glFragColor *= 1.0 / 16.0;
}

___glsl
