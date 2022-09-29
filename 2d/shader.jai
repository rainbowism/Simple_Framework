Uniform :: struct {
    location: GLint;
    type:     Type;
    data:     *void;
    // count:    s64;
}

Shader :: struct {
    id:            s64;
    program:       GLuint;
    uniforms: [..] Uniform;
}

SCREEN_TEXTURE_SLOT: s32 = 1;

create_shader :: (vert_code: string, frag_code: string, $use_screen_texture := false) -> *Shader {
    program := create_program(vert_code, frag_code);
    if program == 0  return null;
    shader_ptr := *render_ctx.shaders.data[render_ctx.shaders.last_occupied];
    shader_ptr.id      = last_shader_id;
    shader_ptr.program = program;
    last_shader_id += 1;
    render_ctx.shaders.last_occupied += 1;
    glBindAttribLocation(program, DEFAULT_SHADER_VERTEX_POS,   "vPos");
    glBindAttribLocation(program, DEFAULT_SHADER_VERTEX_UV1,   "vUV");
    glBindAttribLocation(program, DEFAULT_SHADER_VERTEX_COLOR, "vColor");
    #if use_screen_texture {
        attach_uniform(shader_ptr, "ScreenTexture", *SCREEN_TEXTURE_SLOT);
    }
    return shader_ptr;
}

find_shader :: (id: s64) -> *Shader {
    for *render_ctx.shaders.data {
        if it.id == id  return it;
    }
    return null;
}

destroy :: (id: s64) {
    for *render_ctx.shaders {
        if it.id != id      continue;
        if it.program == 0  return false;

        render_ctx.shaders.last_occupied -= 1;
        glDeleteProgram(it.program);
        array_reset(it.uniforms);
        render_ctx.shaders[it_index] = render_ctx.shaders[render_ctx.shaders.last_occupied];
        break;
    }
}

destroy :: (shader: *Shader) {
    inline destroy(shader.id);
}

find_uniform :: (shader: *Shader, location: GLint) -> *Uniform {
    for *shader.uniforms {
        if it.location == location  return it;
    }
    return null;
}

attach_uniform :: (id: s64, name: string, data: *$T) -> bool {
    for *render_ctx.shaders {
        if it.id != id  continue;
        return inline attach_uniform(it);
    }
    return false;
}

attach_uniform :: (shader: *Shader, name: string, data: *$T) -> bool {
    if shader == null       return false;
    if shader.program == 0  return false;

    location := glGetUniformLocation(shader.program, temp_c_string(name));
    if location == -1  return false;

    uniform := find_uniform(shader, location);
    if uniform == null {
        uniform := array_add(*shader.uniforms);
        uniform.location = location;
        uniform.type = T;
        uniform.data = xx data;
    }
    return true;
}

apply_uniform :: (using uniform: Uniform) {
    if type == {
    case u32;     glUniform1ui(location, << cast(*GLuint) data);
    case u64;     glUniform1ui(location, << cast(*GLuint) data);
    case s32;     glUniform1i(location, << cast(*GLint) data);
    case s64;     glUniform1i(location, << cast(*GLint) data);
    case float32; glUniform1f(location, << cast(*GLfloat) data);
    case float64; glUniform1f(location, << cast(*GLfloat) data);
    case Vector2; glUniform2fv(location, 1, cast(*GLfloat) data);
    case Vector3; glUniform3fv(location, 1, cast(*GLfloat) data);
    case Vector4; glUniform4fv(location, 1, cast(*GLfloat) data);
    case Point2;  glUniform2iv(location, 1, cast(*GLint) data);
    // case Point3;  glUniform3iv(location, 1, cast(*GLint) data);
    // case Point4;  glUniform4iv(location, 1, cast(*GLint) data);
    case Color;   glUniform4fv(location, 1, cast(*GLfloat) data);
    case Matrix2; glUniformMatrix2fv(location, 1, GL_TRUE, cast(*GLfloat) data);
    case Matrix3; glUniformMatrix3fv(location, 1, GL_TRUE, cast(*GLfloat) data);
    case Matrix4; glUniformMatrix4fv(location, 1, GL_TRUE, cast(*GLfloat) data);
    case;         warn("Unhandled uniform type: %", type);
    }
}

create_program :: (vert_code: string, frag_code: string) -> GLuint {
    create_shader :: (code: string, $type: GLenum) -> GLuint, bool #must {
        shader := glCreateShader(type);
        glShaderSource(shader, 1, *code.data, *(cast(GLint) code.count));
        glCompileShader(shader);

        gl_success: GLint;
        glGetShaderiv(shader, GL_COMPILE_STATUS, *gl_success);
        if gl_success == 0 /* GL_FALSE */ {
            buffer_length: GLuint;
            buffer: [1024] u8;
            glGetShaderInfoLog(shader, 1024, *buffer_length, buffer.data);
            if buffer_length > 0 {
                #if type == GL_VERTEX_SHADER
                    warn(.Render, "Vertex shader compile error:\n%\n%", insert_line_numbers(code), to_string(buffer.data, buffer_length));
                else #if type == GL_FRAGMENT_SHADER
                    warn(.Render, "Fragment shader compile error:\n%\n%", insert_line_numbers(code), to_string(buffer.data, buffer_length));
                else
                    warn(.Render, "Shader(type:%) compile(%) error:\n%\n%", type, insert_line_numbers(code), to_string(buffer.data, buffer_length));
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
            warn(
                .Render,
                "Shader linking error:\n== VERTEX ==\n%\n== FRAGMENT ==\n%\n%\n",
                insert_line_numbers(vert_code),
                insert_line_numbers(frag_code),
                to_string(buffer.data, buffer_length)
            );
        }
        glDeleteProgram(program);
        program = 0;
    }
    return program;
}

create_default_shaders :: () {
    create_shader(VERT_SHADER_RECT, FRAG_SHADER_TEXTURED_RECT);
    create_shader(VERT_SHADER_RECT, FRAG_SHADER_COLORED_RECT);
    create_shader(VERT_SHADER_FRAMEBUFFER, FRAG_SHADER_TEXTURED_RECT);
}

#scope_file

last_shader_id: int;

