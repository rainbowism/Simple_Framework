render_init :: (max_renderables := 8192) {
    init_render_buffers(max_renderables);
    create_default_shaders();
    render_ctx.state.current_depth = RENDER_STARTING_DEPTH;
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
    buffer_sub_data(.Texture);
    buffer_sub_data(.Rect);
    buffer_sub_data(.Line);

    render_ctx.state.mvp = render_ctx.state.projection * render_ctx.state.model_view;
    {
        glUseProgram(render_ctx.shaders.data[DEFAULT_SHADER_COLORED].program);

        glUniformMatrix4fv(0, 1, GL_TRUE, render_ctx.state.mvp.floats.data);
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
    if render_ctx.draw_counter >= 0 {
        glBindVertexArray(render_ctx.tex_rects.vao);
        glActiveTexture(GL_TEXTURE0);

        vertex_offset: s64;
        for 0..render_ctx.draw_counter {
            glUseProgram(render_ctx.draws[it].shader.program);
            for render_ctx.draws[it].shader.uniforms  apply_uniform(it);

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
        render_ctx.draw_counter = -1;
    }
}

push_model_view_identity :: () {
    render_ctx.state.model_view = Matrix4_Identity;
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

push_default_shader :: inline () {
    push_shader(*render_ctx.shaders.data[DEFAULT_SHADER_TEXTURED]);
}

set_texture :: (texture_id: Texture_Id) {
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

set_texture :: (slot: GLuint, texture_id: Texture_Id) {
    glActiveTexture(GL_TEXTURE0 + slot);
    glBindTexture(GL_TEXTURE_2D, texture_id);
}

set_texture :: (slot: GLuint, texture: Texture) {
    inline set_texture(slot, texture.id);
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

push_model_view :: inline (m: Matrix4) {
    render_ctx.state.model_view *= m;
}

Render_Type :: enum {
    Texture;
    Rect;
    Line;
}

get_draw_counter :: () -> int {
    return render_ctx.draw_counter;
}

#scope_module

RENDER_STARTING_DEPTH :: 0;

render_ctx: Render_Context;

#scope_file

init_render_buffers :: (max_renderables: s64) #expand {
    init_vertex_buffer(.Texture, *render_ctx.tex_rects, max_renderables, 4, 6);
    init_vertex_buffer(.Rect,    *render_ctx.rects,     max_renderables, 4, 6);
    init_vertex_buffer(.Line,    *render_ctx.lines,     max_renderables, 2, 2);
}

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

buffer_sub_data :: inline ($type: Render_Type) {
    #if type == .Texture  using render_ctx.tex_rects; else
    #if type == .Rect     using render_ctx.rects; else
    #if type == .Line     using render_ctx.lines;

    if index == 0 {
        return;
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
}

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
        mvp:        Matrix4;
    }

    draw_counter: s64 = -1;
    draws:        [DEFAULT_MAX_DRAWCALLS] Draw_Call;
    tex_rects:    Vertex_Buffer = ---;
    rects:        Vertex_Buffer = ---;
    lines:        Vertex_Buffer = ---;
}
