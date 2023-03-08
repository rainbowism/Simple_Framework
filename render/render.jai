Render_Type :: enum s32 {
    Texture;
    Rect;
    Line;
    Glyph;
}

push_default_framebuffer :: inline () {
    batch_draw();
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    draw_clear();
}

push_particle_framebuffer :: inline () {
    batch_draw();
    glBindFramebuffer(GL_FRAMEBUFFER, render_ctx.target[RENDER_TARGET_PARTICLE].fbo);
    draw_clear(.{0.0, 0.0, 0.0, 0.0});
}

push_projection_identity :: inline () {
    render_ctx.state.projection = Matrix4_Identity;
}

push_projection :: inline (m: Matrix4) {
    render_ctx.state.projection *= m;
}

push_model_view_identity :: inline () {
    render_ctx.state.model_view = Matrix4_Identity;
}

push_model_view :: inline (m: Matrix4) {
    render_ctx.state.model_view *= m;
}

push_layer :: (clear: bool, one_minus_alpha := false) {
    render_ctx.layers.index += 1;
    if render_ctx.layers.index > render_ctx.layers.count {
        render_ctx.layers.count += 1;
    }
}

push_shader :: inline (shader: *Shader) {
    if render_ctx.draw_counter < 0 {
        if shader != null {
            render_ctx.default_shader = shader;
        }
        return;
    }
    if shader == null {
        render_ctx.draws[render_ctx.draw_counter].shader = render_ctx.default_shader;
    } else {
        render_ctx.draws[render_ctx.draw_counter].shader = shader;
    }
}

push_shader :: inline (id: s64) {
    shader := find_shader(id);
    push_shader(shader);
}

push_default_shader_textured :: inline () {
    push_shader(*render_ctx.shaders.data[DEFAULT_SHADER_TEXTURED]);
}

push_default_shader_framebuffer :: inline () {
    push_shader(*render_ctx.shaders.data[DEFAULT_SHADER_FRAMEBUFFER]);
}

push_texture :: (texture_id: Texture_Id) {
    if texture_id == 0  return;
    if render_ctx.draw_counter >= 0 {
        if render_ctx.draws[render_ctx.draw_counter].texture_id == texture_id  return;
        if render_ctx.draw_counter + 1 >= DEFAULT_MAX_DRAWCALLS  batch_draw();
    }
    render_ctx.draw_counter += 1;
    render_ctx.draws[render_ctx.draw_counter].texture_id = texture_id;
    render_ctx.draws[render_ctx.draw_counter].count      = 0;
    render_ctx.draws[render_ctx.draw_counter].type       = .Texture;
    render_ctx.draws[render_ctx.draw_counter].shader     = render_ctx.default_shader;
}

push_texture :: (slot: GLuint, texture_id: Texture_Id) {
    glActiveTexture(GL_TEXTURE0 + slot);
    glBindTexture(GL_TEXTURE_2D, texture_id);
}

push_texture :: (slot: GLuint, texture: Texture) {
    inline push_texture(slot, texture.id);
}

push_custom_screen_size :: inline (width: s32, height: s32) {
    render_ctx.state.projection = make_ortho_matrix(0, xx width, xx height, 0, -1, 1);
    screen_size := make_vector2(xx width, xx height);
    pixel_size  := 1.0 / screen_size;
    glBindBuffer(GL_UNIFORM_BUFFER, render_ctx.ubo);
    glBufferSubData(GL_UNIFORM_BUFFER, 0, size_of(Matrix4), render_ctx.state.projection.floats.data);
    glBufferSubData(GL_UNIFORM_BUFFER, 2 * size_of(Matrix4), size_of(Vector2), *screen_size);
    glBufferSubData(GL_UNIFORM_BUFFER, 2 * size_of(Matrix4) + size_of(Vector2), size_of(Vector2), *pixel_size);
    glBindBuffer(GL_UNIFORM_BUFFER, 0);
}

#scope_module

render_init :: (max_renderables := 8192) {
    success: bool = ---;
    render_ctx.target[RENDER_TARGET_MAIN], success = create_render_target();
    if !success  warn(.Render, "Failed to initialize main Render_Target");
    render_ctx.target[RENDER_TARGET_PARTICLE], success = create_render_target();
    if !success  warn(.Render, "Failed to initialize particle Render_Target");

    SHADER_GLOBALS_SIZE :: 2 * size_of(Matrix4) + 2 * size_of(Vector2) + size_of(float);
    glGenBuffers(1, *render_ctx.ubo);
    glBindBuffer(GL_UNIFORM_BUFFER, render_ctx.ubo);
    glBufferData(GL_UNIFORM_BUFFER, SHADER_GLOBALS_SIZE, null, GL_STREAM_DRAW);
    glBindBufferRange(GL_UNIFORM_BUFFER, 0, render_ctx.ubo, 0, SHADER_GLOBALS_SIZE);
    glBindBuffer(GL_UNIFORM_BUFFER, 0);

    init_vertex_buffer(*render_ctx.tex_rects, max_renderables);
    init_primitive_buffer(.Rect, *render_ctx.rects, max_renderables, 4, 6);
    init_primitive_buffer(.Line, *render_ctx.lines, max_renderables, 2, 2);

    glGetIntegerv(GL_MAX_TEXTURE_IMAGE_UNITS, *render_ctx.max_texture_slot);
    render_ctx.max_texture_slot -= 1;

    // init render quad
    glGenVertexArrays(1, *quad_vao);
    glGenBuffers(1, *quad_vbo);

    glBindVertexArray(quad_vao);
    glBindBuffer(GL_ARRAY_BUFFER, quad_vbo);
    glBufferData(GL_ARRAY_BUFFER, quad_vertices.count * size_of(float), quad_vertices.data, GL_STATIC_DRAW);

    glVertexAttribPointer(DEFAULT_SHADER_ATTRIB_POS, 3, GL_FLOAT, GL_FALSE, 5 * size_of(float), null);
    glEnableVertexAttribArray(DEFAULT_SHADER_ATTRIB_POS);

    glVertexAttribPointer(DEFAULT_SHADER_ATTRIB_UV1, 2, GL_FLOAT, GL_FALSE, 5 * size_of(float), xx (3 * size_of(float)));
    glEnableVertexAttribArray(DEFAULT_SHADER_ATTRIB_UV1);

    glBindVertexArray(0);

    render_ctx.bloom, success = init_render_bloom(BLOOM_LEVELS);
    if !success  warn(.Render, "Failed to initialize bloom renderer");

    create_default_shaders();
    render_ctx.state.current_depth = RENDER_Z_START;

    trace(.Render, "Render device initialized successfully:\n  Renderer: %\n  Version: OpenGL %\n  GLSL: %",
        to_string(glGetString(GL_RENDERER)),
        to_string(glGetString(GL_VERSION)),
        to_string(glGetString(GL_SHADING_LANGUAGE_VERSION)),
    );
}

render_begin :: inline (time: float, $use_render_target := true) {
    push_model_view_identity();
    render_ctx.state.current_depth = RENDER_Z_START;
    render_ctx.draw_calls = 0;

    glBindBuffer(GL_UNIFORM_BUFFER, render_ctx.ubo);
    glBufferSubData(GL_UNIFORM_BUFFER, size_of(Matrix4), size_of(Matrix4), render_ctx.state.model_view.floats.data);
    glBufferSubData(GL_UNIFORM_BUFFER, 2 * size_of(Matrix4) + size_of(Vector4), size_of(float), *time);
    glBindBuffer(GL_UNIFORM_BUFFER, 0);

    render_ctx.default_shader = *render_ctx.shaders.data[DEFAULT_SHADER_TEXTURED];
    #if use_render_target {
        render_ctx.state.buffer_drawn = false;
        glBindFramebuffer(GL_FRAMEBUFFER, render_ctx.target[RENDER_TARGET_MAIN].fbo);
        draw_clear(.{0.0, 0.0, 0.0, 0.0});
    } else {
        render_ctx.state.buffer_drawn = true;
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
    }
}

render_begin :: inline (time: float, camera: Camera, $use_render_target := true) {
    push_model_view_identity();
    push_model_view(get_camera_matrix(camera));
    render_ctx.state.current_depth = RENDER_Z_START;
    render_ctx.draw_calls = 0;

    glBindBuffer(GL_UNIFORM_BUFFER, render_ctx.ubo);
    glBufferSubData(GL_UNIFORM_BUFFER, size_of(Matrix4), size_of(Matrix4), render_ctx.state.model_view.floats.data);
    glBufferSubData(GL_UNIFORM_BUFFER, 2 * size_of(Matrix4) + size_of(Vector4), size_of(float), *time);
    glBindBuffer(GL_UNIFORM_BUFFER, 0);

    render_ctx.default_shader = *render_ctx.shaders.data[DEFAULT_SHADER_TEXTURED];
    #if use_render_target {
        render_ctx.state.buffer_drawn = false;
        glBindFramebuffer(GL_FRAMEBUFFER, render_ctx.target[RENDER_TARGET_MAIN].fbo);
        draw_clear(.{0.0, 0.0, 0.0, 0.0});
    } else {
        render_ctx.state.buffer_drawn = true;
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
    }
}

render_quad :: () {
    glBindVertexArray(quad_vao);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glBindVertexArray(0);
}

batch_start :: () {
    if render_ctx.draw_counter  >= DEFAULT_MAX_DRAWCALLS  batch_draw();
}

batch_end :: () {
    render_ctx.state.current_depth += RENDER_Z_SHIFT;
    if render_ctx.draw_counter  >= DEFAULT_MAX_DRAWCALLS  batch_draw();
}

batch_draw :: () {
    if buffer_sub_data(.Texture) && render_ctx.draw_counter >= 0 {
        glBindVertexArray(render_ctx.tex_rects.vao);

        glActiveTexture(GL_TEXTURE0);

        vertex_offset: s64;
        for 0..render_ctx.draw_counter {
            if render_ctx.draws[it].type == .Texture {
                glUseProgram(render_ctx.draws[it].shader.program);
                for uniform: render_ctx.draws[it].shader.uniforms {
                    apply_uniform(uniform);

                    #if 0 {
                        if uniform.type == GLint {
                            name: string = ---;
                            name.data = uniform.name;
                            name.count = c_style_strlen(uniform.name);
                            info("%: loc=% data=%", name, uniform.location, << cast(*GLint) uniform.data);
                        }
                    }
                }
            } else {
                glUseProgram(render_ctx.shaders.data[DEFAULT_SHADER_TEXT].program);
                glUniform2fv(DEFAULT_SHADER_UNIFORM_TEXT_PARAMS, 1, cast(*GLfloat) *render_ctx.draws[it].text_params);
            }

            glBindTexture(GL_TEXTURE_2D, render_ctx.draws[it].texture_id);
            offset := render_ctx.draws[it].count / 4 * 6;
            glDrawElements(
                GL_TRIANGLES,
                xx offset,
                GL_UNSIGNED_INT,
                xx (vertex_offset * size_of(GLuint))
            );
            vertex_offset += offset;
        }

        glBindTexture(GL_TEXTURE_2D, 0);

        glBindVertexArray(0);
        glUseProgram(0);

        render_ctx.tex_rects.index = 0;
        for 0..render_ctx.draw_counter {
            render_ctx.draws[it].texture_id = 0;
        }
        render_ctx.draw_calls += render_ctx.draw_counter + 1;
        render_ctx.draw_counter = -1;
    }

    if buffer_sub_data(.Rect) {
        glUseProgram(render_ctx.shaders.data[DEFAULT_SHADER_COLORED].program);
            glBindVertexArray(render_ctx.rects.vao);
            glDrawElements(GL_TRIANGLES, xx (render_ctx.rects.index / 4 * 6), GL_UNSIGNED_INT, null);
            render_ctx.rects.index = 0;
        glBindVertexArray(0);
        glUseProgram(0);
    }

    if buffer_sub_data(.Line) {
        glUseProgram(render_ctx.shaders.data[DEFAULT_SHADER_COLORED].program);
        glBindVertexArray(render_ctx.lines.vao);
        glDrawElements(GL_LINES, xx render_ctx.lines.index, GL_UNSIGNED_INT, null);
        render_ctx.lines.index = 0;
        glBindVertexArray(0);
        glUseProgram(0);
    }
}

push_screen_size :: inline (width: s32, height: s32) {
    resize_render_target(render_ctx.target[RENDER_TARGET_MAIN], width, height);
    resize_render_target(render_ctx.target[RENDER_TARGET_PARTICLE], width, height);
    resize_render_bloom(render_ctx.bloom, width, height);
    push_custom_screen_size(width, height);
}

push_vertex :: (pos: Vector2) {
    using render_ctx.tex_rects;

    if index >= vertices.count {
        // warn(.Render, "% vertex buffer overflow.", type);
        // return;
        current_draw := render_ctx.draws[render_ctx.draw_counter];
        batch_draw();
        render_ctx.draw_counter += 1;
        render_ctx.draws[render_ctx.draw_counter] = current_draw;
    }

    vertices[index] = pos;
    colors[index]   = render_ctx.state.color;
    uvs[index]      = render_ctx.state.uv;
    render_ctx.draws[render_ctx.draw_counter].count += 1;
    index += 1;
}

push_primitive :: ($type: Render_Type, pos: Vector2) {
    #if type == .Texture  #assert("Can't use Render_Type.Texture for `push_primitive`."); else
    #if type == .Rect     using render_ctx.rects; else
    #if type == .Line     using render_ctx.lines;

    if index >= vertices.count {
        // warn(.Render, "% vertex buffer overflow.", type);
        // return;
        current_draw := render_ctx.draws[render_ctx.draw_counter+1];
        batch_draw();
        render_ctx.draw_counter += 1;
        render_ctx.draws[render_ctx.draw_counter] = current_draw;
    }

    vertices[index] = pos;
    colors[index]   = render_ctx.state.color;
    index += 1;
}

push_depth :: () {
    render_ctx.state.current_depth += RENDER_Z_SHIFT;
}

push_uv :: (uv: Vector2) {
    render_ctx.state.uv = uv;
}

push_uv :: (u: float, v: float) {
    render_ctx.state.uv.x = u;
    render_ctx.state.uv.y = v;
}

push_color :: (color: Color) {
    render_ctx.state.color = color;
}

push_glyph_call :: (texture_id: Texture_Id, color: Color, text_params: Vector2) {
    if render_ctx.draw_counter + 1 >= DEFAULT_MAX_DRAWCALLS  batch_draw();
    render_ctx.draw_counter += 1;
    render_ctx.draws[render_ctx.draw_counter].texture_id  = texture_id;
    render_ctx.draws[render_ctx.draw_counter].count       = 0;
    render_ctx.draws[render_ctx.draw_counter].type        = .Glyph;
    render_ctx.draws[render_ctx.draw_counter].text_params = text_params;
}

get_draw_calls :: () -> int {
    return render_ctx.draw_calls;
}

RENDER_TARGET_MAIN     :: 0;
RENDER_TARGET_PARTICLE :: 1;
RENDER_TARGET_DEFAULT  :: 2;

RENDER_Z_START :: 0.0;
RENDER_Z_SHIFT :: 1.0 / 20000.0;

render_ctx: Render_Context;

quad_vertices :: float.[
    -1.0,  1.0, 0.0, 0.0, 1.0,
    -1.0, -1.0, 0.0, 0.0, 0.0,
     1.0,  1.0, 0.0, 1.0, 1.0,
     1.0, -1.0, 0.0, 1.0, 0.0,
];
quad_vao, quad_vbo: GLuint = ---;

#scope_file

init_vertex_buffer :: inline (
    using buffer:    *Vertex_Buffer,
    max_renderables: s64
) {
    count          = max_renderables;
    vertices.count = max_renderables * 4;
    uvs.count      = vertices.count;
    colors.count   = vertices.count;
    indices.count  = max_renderables * 6;
    vertices.data  = alloc(size_of(Vector2) * vertices.count);
    uvs.data       = alloc(size_of(Vector2) * uvs.count);
    colors.data    = alloc(size_of(Color)   * colors.count);
    indices.data   = alloc(size_of(GLuint)  * indices.count);

    it_quad:  u32;
    it_index: s64;
    while it_index < indices.count {
        defer it_quad  += 4;
        defer it_index += 6;
        indices[it_index]     = it_quad;
        indices[it_index + 1] = it_quad + 1;
        indices[it_index + 2] = it_quad + 2;
        indices[it_index + 3] = it_quad;
        indices[it_index + 4] = it_quad + 2;
        indices[it_index + 5] = it_quad + 3;
    }

    glGenVertexArrays(1, *vao);
    glBindVertexArray(vao);

    glGenBuffers(4, vbo.data);
    // bind vertices
    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, vertices.count * size_of(Vector2), vertices.data, GL_DYNAMIC_DRAW);
    glVertexAttribPointer(DEFAULT_SHADER_ATTRIB_POS, 2, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(DEFAULT_SHADER_ATTRIB_POS);
    // bind uvs
    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glBufferData(GL_ARRAY_BUFFER, uvs.count * size_of(Vector2), uvs.data, GL_DYNAMIC_DRAW);
    glVertexAttribPointer(DEFAULT_SHADER_ATTRIB_UV1, 2, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(DEFAULT_SHADER_ATTRIB_UV1);
    // bind colors
    glBindBuffer(GL_ARRAY_BUFFER, vbo[2]);
    glBufferData(GL_ARRAY_BUFFER, colors.count * size_of(Color), colors.data, GL_DYNAMIC_DRAW);
    glVertexAttribPointer(DEFAULT_SHADER_ATTRIB_COLOR, 4, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(DEFAULT_SHADER_ATTRIB_COLOR);
    // bind indices
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[3]);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.count * size_of(GLuint), indices.data, GL_STATIC_DRAW);

    glBindVertexArray(0);
}

init_primitive_buffer :: inline (
    $type:           Render_Type,
    using buffer:    *Primitive_Buffer,
    max_renderables: s64,
    $vertex_count:   s64,
    $index_count:    s64
) {
    count          = max_renderables;
    vertices.count = max_renderables * vertex_count;
    colors.count   = vertices.count;
    indices.count  = max_renderables * index_count;
    vertices.data  = alloc(size_of(Vector2) * vertices.count);
    colors.data    = alloc(size_of(Color)   * colors.count);
    indices.data   = alloc(size_of(GLuint)  * indices.count);

    #if index_count == 6 {
        it_quad:  u32;
        it_index: s64;
        while it_index < indices.count {
            defer it_quad  += xx vertex_count;
            defer it_index += index_count;
            indices[it_index]     = it_quad;
            indices[it_index + 1] = it_quad + 1;
            indices[it_index + 2] = it_quad + 2;
            indices[it_index + 3] = it_quad;
            indices[it_index + 4] = it_quad + 2;
            indices[it_index + 5] = it_quad + 3;
        }
    } else #if index_count == 2 {
        it_quad:  u32;
        it_index: s64;
        while it_index < indices.count {
            defer it_quad  += xx vertex_count;
            defer it_index += index_count;
            indices[it_index]     = it_quad;
            indices[it_index + 1] = it_quad + 1;
        }
    }

    glGenVertexArrays(1, *vao);
    glBindVertexArray(vao);

    glGenBuffers(3, vbo.data);
    // bind vertices
    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, vertices.count * size_of(Vector2), vertices.data, GL_DYNAMIC_DRAW);
    glVertexAttribPointer(DEFAULT_SHADER_ATTRIB_POS, 2, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(DEFAULT_SHADER_ATTRIB_POS);
    // bind colors
    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glBufferData(GL_ARRAY_BUFFER, colors.count * size_of(Color), colors.data, GL_DYNAMIC_DRAW);
    glVertexAttribPointer(DEFAULT_SHADER_ATTRIB_COLOR, 4, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(DEFAULT_SHADER_ATTRIB_COLOR);
    // bind indices
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[2]);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.count * size_of(GLuint), indices.data, GL_STATIC_DRAW);

    glBindVertexArray(0);
}

buffer_sub_data :: inline ($type: Render_Type) -> bool {
    #if type == .Texture  using render_ctx.tex_rects; else
    #if type == .Glyph    using render_ctx.text_glyphs; else
    #if type == .Rect     using render_ctx.rects; else
    #if type == .Line     using render_ctx.lines;

    if index == 0  return false;

    glBindVertexArray(vao);

    #if type == .Texture {
        glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
        glBufferSubData(GL_ARRAY_BUFFER, 0, index * size_of(Vector3), vertices.data);
        glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
        glBufferSubData(GL_ARRAY_BUFFER, 0, index * size_of(Vector2), uvs.data);
        glBindBuffer(GL_ARRAY_BUFFER, vbo[2]);
        glBufferSubData(GL_ARRAY_BUFFER, 0, index * size_of(Color), colors.data);
    } else #if type == .Glyph {
        glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
        glBufferSubData(GL_ARRAY_BUFFER, 0, index * size_of(Vector3), vertices.data);
        glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
        glBufferSubData(GL_ARRAY_BUFFER, 0, index * size_of(Vector2), uvs.data);
    } else {
        glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
        glBufferSubData(GL_ARRAY_BUFFER, 0, index * size_of(Vector3), vertices.data);
        glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
        glBufferSubData(GL_ARRAY_BUFFER, 0, index * size_of(Color), colors.data);
    }

    glBindVertexArray(0);

    return true;
}

BLOOM_LEVELS :: 6;
DEFAULT_MAX_DRAWCALLS :: 256;
DEFAULT_MAX_SHADERS   :: 64;

Vertex_Buffer :: struct {
    index:    s64;
    count:    s64;
    vertices: [] Vector2;
    uvs:      [] Vector2;
    colors:   [] Color;
    indices:  [] GLuint;
    vao:      GLuint;
    vbo:      [4] GLuint;
}

Primitive_Buffer :: struct {
    index:    s64;
    count:    s64;
    vertices: [] Vector2;
    colors:   [] Color;
    indices:  [] GLuint;
    vao:      GLuint;
    vbo:      [3] GLuint;
}

Draw_Call :: struct {
    texture_id: Texture_Id;
    count:      s32;
    type:       Render_Type;

    union {
        text_params: Vector2;
        shader:     *Shader;
    }
}

Render_Context :: struct {
    shaders: struct {
        data:  [DEFAULT_MAX_SHADERS] Shader;
        last_occupied: s64;
    }

    layers: struct {
        index: int;
        count: int;
    }

    state: struct {
        current_depth: float;
        uv:            Vector2;
        color:         Color;

        projection: Matrix4;
        model_view: Matrix4;
        buffer_drawn: bool;
    }

    target:           [2] Render_Target;
    bloom:            *Render_Bloom(BLOOM_LEVELS);
    ubo:              GLuint;
    max_texture_slot: GLint;

    draw_calls:   s64;
    draw_counter: s64 = -1;
    default_shader: *Shader;
    draws:     [DEFAULT_MAX_DRAWCALLS] Draw_Call;
    tex_rects: Vertex_Buffer = ---;
    rects:     Primitive_Buffer = ---;
    lines:     Primitive_Buffer = ---;
}
