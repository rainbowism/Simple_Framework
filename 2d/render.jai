render_init :: (max_renderables := 8192) {
    success: bool = ---;
    render_ctx.target[0], success = create_render_target();
    if !success  warn(.Render, "Failed to initialize main Render_Target");
    render_ctx.target[1], success = create_render_target();
    if !success  warn(.Render, "Failed to initialize particle Render_Target");

    SHADER_GLOBALS_SIZE :: 2 * size_of(Matrix4) + 2 * size_of(Vector2) + size_of(float);
    glGenBuffers(1, *render_ctx.ubo);
    glBindBuffer(GL_UNIFORM_BUFFER, render_ctx.ubo);
    glBufferData(GL_UNIFORM_BUFFER, SHADER_GLOBALS_SIZE, null, GL_STREAM_DRAW);
    glBindBufferRange(GL_UNIFORM_BUFFER, 0, render_ctx.ubo, 0, SHADER_GLOBALS_SIZE);
    glBindBuffer(GL_UNIFORM_BUFFER, 0);

    init_vertex_buffer(.Texture, *render_ctx.tex_rects, max_renderables, 4, 6);
    init_vertex_buffer(.Rect,    *render_ctx.rects,     max_renderables, 4, 6);
    init_vertex_buffer(.Line,    *render_ctx.lines,     max_renderables, 2, 2);

    glGetIntegerv(GL_MAX_TEXTURE_IMAGE_UNITS, *render_ctx.max_texture_slot);
    render_ctx.max_texture_slot -= 1;

    // init render quad
    glGenVertexArrays(1, *quad_vao);
    glGenBuffers(1, *quad_vbo);

    glBindVertexArray(quad_vao);
    glBindBuffer(GL_ARRAY_BUFFER, quad_vbo);
    glBufferData(GL_ARRAY_BUFFER, quad_vertices.count * size_of(float), quad_vertices.data, GL_STATIC_DRAW);

    glVertexAttribPointer(DEFAULT_SHADER_VERTEX_POS, 3, GL_FLOAT, GL_FALSE, 5 * size_of(float), null);
    glEnableVertexAttribArray(DEFAULT_SHADER_VERTEX_POS);

    glVertexAttribPointer(DEFAULT_SHADER_VERTEX_UV1, 2, GL_FLOAT, GL_FALSE, 5 * size_of(float), xx (3 * size_of(float)));
    glEnableVertexAttribArray(DEFAULT_SHADER_VERTEX_UV1);

    glBindVertexArray(0);

    render_ctx.bloom, success = init_render_bloom(BLOOM_LEVELS);
    if !success  warn(.Render, "Failed to initialize bloom renderer");

    create_default_shaders();
    render_ctx.state.current_depth = RENDER_STARTING_DEPTH;
}

render_begin :: inline (time: float) {
    push_model_view_identity();
    render_ctx.state.current_depth = RENDER_STARTING_DEPTH;
    render_ctx.draw_calls = 0;

    glBindBuffer(GL_UNIFORM_BUFFER, render_ctx.ubo);
    glBufferSubData(GL_UNIFORM_BUFFER, size_of(Matrix4), size_of(Matrix4), render_ctx.state.model_view.floats.data);
    glBufferSubData(GL_UNIFORM_BUFFER, 2 * size_of(Matrix4) + size_of(Vector4), size_of(float), *time);
    glBindBuffer(GL_UNIFORM_BUFFER, 0);

    render_ctx.state.buffer_drawn = false;
    glBindFramebuffer(GL_FRAMEBUFFER, render_ctx.target[RENDER_TARGET_MAIN].fbo);
    draw_clear(.{0.0, 0.0, 0.0, 0.0});
}

render_begin :: inline (time: float, camera: Camera) {
    push_model_view_identity();
    push_model_view(get_camera_matrix(camera));
    render_ctx.state.current_depth = RENDER_STARTING_DEPTH;
    render_ctx.draw_calls = 0;

    glBindBuffer(GL_UNIFORM_BUFFER, render_ctx.ubo);
    glBufferSubData(GL_UNIFORM_BUFFER, size_of(Matrix4), size_of(Matrix4), render_ctx.state.model_view.floats.data);
    glBufferSubData(GL_UNIFORM_BUFFER, 2 * size_of(Matrix4) + size_of(Vector4), size_of(float), *time);
    glBindBuffer(GL_UNIFORM_BUFFER, 0);

    render_ctx.state.buffer_drawn = false;
    glBindFramebuffer(GL_FRAMEBUFFER, render_ctx.target[RENDER_TARGET_MAIN].fbo);
    draw_clear(.{0.0, 0.0, 0.0, 0.0});
}

render_quad :: inline () {
    glBindVertexArray(quad_vao);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glBindVertexArray(0);
}

push_particle_framebuffer :: inline () {
    batch_draw();
    glBindFramebuffer(GL_FRAMEBUFFER, render_ctx.target[RENDER_TARGET_PARTICLE].fbo);
    draw_clear(.{0.0, 0.0, 0.0, 0.0});
}

push_default_framebuffer :: inline () {
    batch_draw();
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    draw_clear();
}

batch_start :: ($type: Render_Type) {
    #if type == .Texture {
        if render_ctx.draw_counter >= DEFAULT_MAX_DRAWCALLS  batch_draw();
    }
}

batch_end :: ($type: Render_Type) {
    DEPTH_OFFSET :: 1.0 / 20000.0;
    render_ctx.state.current_depth += DEPTH_OFFSET;
    #if type == .Texture {
        if render_ctx.draw_counter >= DEFAULT_MAX_DRAWCALLS  batch_draw();
    }
}

batch_draw :: () {
    should_render_primitives := buffer_sub_data(.Rect);
    should_render_primitives |= buffer_sub_data(.Line);

    if should_render_primitives {
        glUseProgram(render_ctx.shaders.data[DEFAULT_SHADER_COLORED].program);

        if render_ctx.rects.index > 0 {
            glBindVertexArray(render_ctx.rects.vao);
            glDrawElements(GL_TRIANGLES, xx (render_ctx.rects.index / 4 * 6), GL_UNSIGNED_INT, null);
            render_ctx.rects.index = 0;
        }
        if render_ctx.lines.index > 0 {
            glBindVertexArray(render_ctx.lines.vao);
            glDrawElements(GL_LINES,     xx render_ctx.lines.index,           GL_UNSIGNED_INT, null);
            render_ctx.lines.index = 0;
        }
        glBindVertexArray(0);
        glUseProgram(0);
    }

    if buffer_sub_data(.Texture) && render_ctx.draw_counter >= 0 {
        glBindVertexArray(render_ctx.tex_rects.vao);

        glActiveTexture(GL_TEXTURE0);

        vertex_offset: s64;
        for 0..render_ctx.draw_counter {
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
}

push_screen_size :: inline (width: s32, height: s32) {
    resize_render_target(render_ctx.target[RENDER_TARGET_MAIN], width, height);
    resize_render_target(render_ctx.target[RENDER_TARGET_PARTICLE], width, height);
    resize_render_bloom(render_ctx.bloom, width, height);
    render_ctx.state.projection = make_ortho_matrix(0, xx width, xx height, 0, -1, 1);
    screen_size := make_vector2(xx width, xx height);
    pixel_size  := 1.0 / screen_size;
    glBindBuffer(GL_UNIFORM_BUFFER, render_ctx.ubo);
    glBufferSubData(GL_UNIFORM_BUFFER, 0, size_of(Matrix4), render_ctx.state.projection.floats.data);
    glBufferSubData(GL_UNIFORM_BUFFER, 2 * size_of(Matrix4), size_of(Vector2), *screen_size);
    glBufferSubData(GL_UNIFORM_BUFFER, 2 * size_of(Matrix4) + size_of(Vector2), size_of(Vector2), *pixel_size);
    glBindBuffer(GL_UNIFORM_BUFFER, 0);
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
    if render_ctx.draw_counter < 0  return;
    if shader == null {
        render_ctx.draws[render_ctx.draw_counter].shader = *render_ctx.shaders.data[DEFAULT_SHADER_TEXTURED];
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
        if render_ctx.draw_counter >= DEFAULT_MAX_DRAWCALLS  batch_draw();
    }
    render_ctx.draw_counter += 1;
    render_ctx.draws[render_ctx.draw_counter].texture_id = texture_id;
    render_ctx.draws[render_ctx.draw_counter].count      = 0;
    render_ctx.draws[render_ctx.draw_counter].shader     = *render_ctx.shaders.data[DEFAULT_SHADER_TEXTURED];
}

push_texture :: (slot: GLuint, texture_id: Texture_Id) {
    glActiveTexture(GL_TEXTURE0 + slot);
    glBindTexture(GL_TEXTURE_2D, texture_id);
}

push_texture :: (slot: GLuint, texture: Texture) {
    inline push_texture(slot, texture.id);
}

push_vertex :: ($type: Render_Type, pos: Vector3) {
    #if type == .Texture  using render_ctx.tex_rects; else
    #if type == .Rect     using render_ctx.rects; else
    #if type == .Line     using render_ctx.lines;

    if index >= vertices.count {
        warn(.Render, "% vertex buffer overflow.", type);
        return;
    }

    vertices[index] = pos;
    colors[index]   = render_ctx.state.color;
    #if type == .Texture {
        uvs[index] = render_ctx.state.uv;
        render_ctx.draws[render_ctx.draw_counter].count += 1;
    }
    index += 1;
}

push_vertex :: ($type: Render_Type, pos: Vector2) {
    #if type == .Texture  using render_ctx.tex_rects; else
    #if type == .Rect     using render_ctx.rects; else
    #if type == .Line     using render_ctx.lines;

    if index >= vertices.count {
        warn(.Render, "% vertex buffer overflow.", type);
        return;
    }

    v: Vector3 = ---;
    v.x = pos.x;
    v.y = pos.y;
    v.z = render_ctx.state.current_depth;

    vertices[index] = v;
    colors[index]   = render_ctx.state.color;
    #if type == .Texture {
        uvs[index] = render_ctx.state.uv;
        render_ctx.draws[render_ctx.draw_counter].count += 1;
    }
    index += 1;
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

Render_Type :: enum {
    Texture;
    Rect;
    Line;
}

get_draw_counter :: () -> int {
    return render_ctx.draw_counter;
}

RENDER_TARGET_MAIN     :: 0;
RENDER_TARGET_PARTICLE :: 1;
RENDER_TARGET_DEFAULT  :: 2;

#scope_module

RENDER_STARTING_DEPTH :: 0;

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
    $type:           Render_Type,
    using buffer:    *Vertex_Buffer,
    max_renderables: s64,
    $vertex_count:   s64,
    $index_count:    s64
) {
    count          = max_renderables;
    vertices.count = max_renderables * vertex_count;
    uvs.count      = vertices.count;
    colors.count   = vertices.count;
    indices.count  = max_renderables * index_count;
    vertices.data  = alloc(size_of(Vector3) * vertices.count);
    #if type == .Texture {
        uvs.data = alloc(size_of(Vector2) * uvs.count);
    }
    colors.data    = alloc(size_of(Color)   * colors.count);
    indices.data   = alloc(size_of(GLuint)  * indices.count);

    #if index_count == 6 {
        i_quad:  u32;
        i_index: s64;
        while i_index < indices.count {
            indices[i_index]     = i_quad;
            indices[i_index + 1] = i_quad + 1;
            indices[i_index + 2] = i_quad + 2;
            indices[i_index + 3] = i_quad;
            indices[i_index + 4] = i_quad + 2;
            indices[i_index + 5] = i_quad + 3;
            i_quad  += xx vertex_count;
            i_index += index_count;
        }
    } else #if index_count == 2 {
        i_quad:  u32;
        i_index: s64;
        while i_index < indices.count {
            indices[i_index]     = i_quad;
            indices[i_index + 1] = i_quad + 1;
            i_quad  += xx vertex_count;
            i_index += index_count;
        }
    }

    glGenVertexArrays(1, *vao);
    glBindVertexArray(vao);

    glGenBuffers(4, vbo.data);
    // bind vertices
    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, vertices.count * size_of(Vector3), vertices.data, GL_DYNAMIC_DRAW);
    glVertexAttribPointer(DEFAULT_SHADER_VERTEX_POS, 3, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(DEFAULT_SHADER_VERTEX_POS);
    #if type == .Texture {
        // bind uvs
        glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
        glBufferData(GL_ARRAY_BUFFER, uvs.count * size_of(Vector2), uvs.data, GL_DYNAMIC_DRAW);
        glVertexAttribPointer(DEFAULT_SHADER_VERTEX_UV1, 2, GL_FLOAT, GL_FALSE, 0, null);
        glEnableVertexAttribArray(DEFAULT_SHADER_VERTEX_UV1);
    }
    // bind colors
    glBindBuffer(GL_ARRAY_BUFFER, vbo[2]);
    glBufferData(GL_ARRAY_BUFFER, colors.count * size_of(Color), colors.data, GL_DYNAMIC_DRAW);
    glVertexAttribPointer(DEFAULT_SHADER_VERTEX_COLOR, 4, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(DEFAULT_SHADER_VERTEX_COLOR);
    // bind indices
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[3]);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.count * size_of(GLuint), indices.data, GL_STATIC_DRAW);

    glBindVertexArray(0);
}

buffer_sub_data :: inline ($type: Render_Type) -> bool {
    #if type == .Texture  using render_ctx.tex_rects; else
    #if type == .Rect     using render_ctx.rects; else
    #if type == .Line     using render_ctx.lines;

    if index == 0 {
        return false;
    }

    glBindVertexArray(vao);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferSubData(GL_ARRAY_BUFFER, 0, index * size_of(Vector3), vertices.data);
    glVertexAttribPointer(DEFAULT_SHADER_VERTEX_POS, 3, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(DEFAULT_SHADER_VERTEX_POS);

    #if type == .Texture {
        glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
        glBufferSubData(GL_ARRAY_BUFFER, 0, index * size_of(Vector2), uvs.data);
        glVertexAttribPointer(DEFAULT_SHADER_VERTEX_UV1, 2, GL_FLOAT, GL_FALSE, 0, null);
        glEnableVertexAttribArray(DEFAULT_SHADER_VERTEX_UV1);
    }

    glBindBuffer(GL_ARRAY_BUFFER, vbo[2]);
    glBufferSubData(GL_ARRAY_BUFFER, 0, index * size_of(Color), colors.data);
    glVertexAttribPointer(DEFAULT_SHADER_VERTEX_COLOR, 4, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(DEFAULT_SHADER_VERTEX_COLOR);

    glBindVertexArray(0);

    return true;
}

BLOOM_LEVELS :: 6;
DEFAULT_MAX_DRAWCALLS :: 256;
DEFAULT_MAX_SHADERS   :: 64;

Vertex_Buffer :: struct {
    index:    s64;
    count:    s64;
    vertices: [] Vector3;
    uvs:      [] Vector2;
    colors:   [] Color;
    indices:  [] GLuint;
    vao:      GLuint;
    vbo:      [4] GLuint;
}

Draw_Call :: struct {
    texture_id: Texture_Id;
    count:      s32;
    shader:     *Shader;
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
    draws:        [DEFAULT_MAX_DRAWCALLS] Draw_Call;
    tex_rects:    Vertex_Buffer = ---;
    rects:        Vertex_Buffer = ---;
    lines:        Vertex_Buffer = ---;
}
