render_init :: (max_renderables := 8192) {
    init_render_buffers(max_renderables);
    create_default_shaders();
}

create_program :: (vert_code: string, frag_code: string) -> GLuint {
    create_shader :: (code: string, type: GLenum) -> GLuint, bool #must {
        shader := glCreateShader(type);
        glShaderSource(shader, 1, *code.data, *(cast(GLint) code.count));
        glCompileShader(shader);

        gl_success: GLint;
        glGetShaderiv(shader, GL_COMPILE_STATUS, *gl_success);
        if gl_success == 0 /* GL_FALSE */ {
            buffer_length: GLuint;
            buffer:        [1024] u8;
            glGetShaderInfoLog(shader, 1024, *buffer_length, buffer.data);
            if buffer_length > 0 {
                warn(.Render, "Shader compile(%) error: %", type, to_string(buffer.data, buffer_length));
            }
            return 0, false;
        }
        return shader, true;
    }

    success: bool;
    vert_shader, frag_shader: GLuint;
    vert_shader, success = create_shader(vert_code, GL_VERTEX_SHADER);
    if !success  return 0;
    defer glDeleteShader(vert_shader);
    frag_shader, success = create_shader(frag_code, GL_FRAGMENT_SHADER);
    if !success  return 0;
    defer glDeleteShader(frag_shader);

    program := glCreateProgram();
    glAttachShader(program, vert_shader);
    glAttachShader(program, frag_shader);
    glLinkProgram(program);

    gl_success: GLint;
    glGetProgramiv(program, GL_LINK_STATUS, *gl_success);
    if gl_success == 0 /* GL_FALSE */ {
        buffer_length: GLuint;
        buffer:        [1024] u8;
        glGetProgramInfoLog(program, 1024, *buffer_length, buffer.data);
        if buffer_length > 0 {
            warn(.Render, "Shader linking error: %\n", to_string(buffer.data, buffer_length));
        }
        glDeleteProgram(program);
        program = 0;
    }
    return program;
}

create_default_shaders :: () {
    sprite_shader := create_program(VERT_SHADER_RECT, FRAG_SHADER_TEXTURED_RECT);
    rect_shader   := create_program(VERT_SHADER_RECT, FRAG_SHADER_COLORED_RECT);
    glBindAttribLocation(sprite_shader, DEFAULT_SHADER_VERTEX_POS,   "vPos");
    glBindAttribLocation(sprite_shader, DEFAULT_SHADER_VERTEX_UV1,   "vUV");
    glBindAttribLocation(sprite_shader, DEFAULT_SHADER_VERTEX_COLOR, "vColor");
    glBindAttribLocation(rect_shader,   DEFAULT_SHADER_VERTEX_POS,   "vPos");
    glBindAttribLocation(rect_shader,   DEFAULT_SHADER_VERTEX_UV1,   "vUV");
    glBindAttribLocation(rect_shader,   DEFAULT_SHADER_VERTEX_COLOR, "vColor");

}

#scope_file

init_render_buffers :: (max_renderables: s64) #expand {
    init_vertex_buffer(*render_ctx.tex_rects, max_renderables, 4, 6);
    init_vertex_buffer(*render_ctx.rects,     max_renderables, 4, 6);
    init_vertex_buffer(*render_ctx.lines,     max_renderables, 2, 2);
}

init_vertex_buffer :: inline (
    using buffer: *GLVertexBuffer,
    max_renderables: s64,
    $vertex_count: s64,
    $index_count: s64
) {
    count          = max_renderables;
    vertices.count = max_renderables * vertex_count;
    uvs.count      = vertices.count;
    colors.count   = vertices.count;
    indices.count  = max_renderables * index_count;
    vertices.data  = alloc(size_of(Vector3) * vertices.count);
    uvs.data       = alloc(size_of(Vector2) * uvs.count);
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
    glBufferData(GL_ARRAY_BUFFER, vertices.count, vertices.data, GL_DYNAMIC_DRAW);
    glVertexAttribPointer(DEFAULT_SHADER_VERTEX_POS, 3, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(DEFAULT_SHADER_VERTEX_POS);
    // bind uvs
    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glBufferData(GL_ARRAY_BUFFER, uvs.count, uvs.data, GL_DYNAMIC_DRAW);
    glVertexAttribPointer(DEFAULT_SHADER_VERTEX_UV1, 2, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(DEFAULT_SHADER_VERTEX_UV1);
    // bind colors
    glBindBuffer(GL_ARRAY_BUFFER, vbo[2]);
    glBufferData(GL_ARRAY_BUFFER, colors.count, colors.data, GL_DYNAMIC_DRAW);
    glVertexAttribPointer(DEFAULT_SHADER_VERTEX_COLOR, 4, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(DEFAULT_SHADER_VERTEX_COLOR);
    // bind indices
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[3]);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.count, indices.data, GL_STATIC_DRAW);

    glBindVertexArray(0);
}

// @Todo(sushi): are SoAs in yet? can i convert this?
GLVertexBuffer :: struct {
    count:    s64;
    vertices: []  Vector3;
    uvs:      []  Vector2;
    colors:   []  Color;
    indices:  []  GLuint;
    vao:      GLuint;
    vbo:      [4] GLuint;
}

render_ctx: struct {
    layers: struct {
        index: int;
        count: int;
    }

    tex_rects: GLVertexBuffer = ---;
    rects:     GLVertexBuffer = ---;
    lines:     GLVertexBuffer = ---;
}
