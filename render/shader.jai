Uniform :: struct {
    #if DEBUG  name: *u8;
    location: GLint;
    type:     Type;
    data:     *void;
}

Shader :: struct {
    #if DEBUG {
        vert_code: string;
        frag_code: string;
    }
    id:            s64;
    program:       GLuint;
    uniforms: [..] Uniform;
}

Binding_Flags :: enum_flags {
    Position;
    UV;
    Color;
};

Default_Binding_Flags :: Binding_Flags.Position | .UV | .Color;
Primitive_Binding_Flags :: Binding_Flags.Position | .Color;

create_shader :: (vert_code: string, frag_code: string, $use_screen_texture := false, $binding_flags := Default_Binding_Flags) -> *Shader {
    program := create_gl_program(vert_code, frag_code, binding_flags);
    if program == 0  return null;
    shader_ptr := *render_ctx.shaders.data[render_ctx.shaders.last_occupied];
    #if DEBUG {
        shader_ptr.vert_code = copy_string(vert_code);
        shader_ptr.frag_code = copy_string(frag_code);
    }
    shader_ptr.id      = last_shader_id;
    shader_ptr.program = program;
    last_shader_id += 1;
    render_ctx.shaders.last_occupied += 1;
    #if use_screen_texture {
        attach_uniform(shader_ptr, "ScreenTexture", *render_ctx.max_texture_slot);
    }

    #if 0 {
        uniform_count: s32;
        glGetProgramInterfaceiv(shader_ptr.program, GL_UNIFORM, GL_ACTIVE_RESOURCES, *uniform_count);
        uniform_size: GLint;
        uniform_type: GLenum;
        name := talloc_string(256);

        for 0..uniform_count-1 {
            glGetActiveUniform(shader_ptr.program, xx it, 256, xx *name.count, *uniform_size, *uniform_type, name.data);

            info("Uniform % Type: % Name: %", it, uniform_type, name);
        }
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
        #if DEBUG {
            uniform.name = alloc(name.count + 1);
            memcpy(uniform.name, name.data, name.count);
            uniform.name[name.count] = 0;
        }
        uniform.location = location;
        uniform.type = T;
        uniform.data = xx data;
    } else {
        uniform.location = location;
        uniform.type = T;
        uniform.data = xx data;
    }
    return true;
}

#if DEBUG {
    reattach_uniform :: (shader: *Shader) {
        for *uniform: shader.uniforms {
            location := glGetUniformLocation(shader.program, uniform.name);
            if location == -1  continue;

            uniform.location = location;
        }
    }
}

apply_uniform :: (using uniform: Uniform) {
    if type == {
    case u32;     glUniform1ui(location, << cast(*GLuint) data);
    case u64;     glUniform1ui(location, << cast(*GLuint) data);
    case s32;     glUniform1i (location, << cast(*GLint) data);
    case s64;     glUniform1i (location, << cast(*GLint) data);
    case float32; glUniform1f (location, << cast(*GLfloat) data);
    case float64; glUniform1f (location, << cast(*GLfloat) data);
    case Vector2; glUniform2fv(location, 1, cast(*GLfloat) data);
    case Vector3; glUniform3fv(location, 1, cast(*GLfloat) data);
    case Vector4; glUniform4fv(location, 1, cast(*GLfloat) data);
    case Point2;  glUniform2iv(location, 1, cast(*GLint) data);
    case Color;   glUniform4fv(location, 1, cast(*GLfloat) data);
    case Matrix2; glUniformMatrix2fv(location, 1, GL_TRUE, cast(*GLfloat) data);
    case Matrix3; glUniformMatrix3fv(location, 1, GL_TRUE, cast(*GLfloat) data);
    case Matrix4; glUniformMatrix4fv(location, 1, GL_TRUE, cast(*GLfloat) data);
    case;         warn("Unhandled uniform type: %", type);
    }
}

create_gl_program :: (vert_code: string, frag_code: string, $binding_flags := Default_Binding_Flags) -> GLuint {
    success: bool;
    vert_shader, frag_shader: GLuint;
    vert_shader, success = create_gl_shader(vert_code, .Vertex);
    if !success  return 0;
    defer glDeleteShader(vert_shader);
    frag_shader, success = create_gl_shader(frag_code, .Fragment);
    if !success  return 0;
    defer glDeleteShader(frag_shader);

    program := glCreateProgram();
    glAttachShader(program, vert_shader);
    glAttachShader(program, frag_shader);

    #if binding_flags & .Position     glBindAttribLocation(program, DEFAULT_SHADER_ATTRIB_POS,         "vPos");
    #if binding_flags & .UV           glBindAttribLocation(program, DEFAULT_SHADER_ATTRIB_UV1,         "vUV");
    #if binding_flags & .Color        glBindAttribLocation(program, DEFAULT_SHADER_ATTRIB_COLOR,       "vColor");

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

create_gl_shader :: (code: string, $type: enum { Vertex; Fragment; }) -> GLuint, bool #must {
    #if type == .Vertex {
        shader := glCreateShader(GL_VERTEX_SHADER);
    } else #if type == .Fragment {
        shader := glCreateShader(GL_FRAGMENT_SHADER);
    } else {
        assert(false, "Invalid shader type.");
    }
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

create_default_shaders :: () {
    create_shader(VERT_SHADER_RECT,      FRAG_SHADER_TEXTURED_RECT);
    create_shader(VERT_SHADER_PRIMITIVE, FRAG_SHADER_COLORED_RECT, binding_flags = Primitive_Binding_Flags);
    create_shader(VERT_SHADER_RECT,      FRAG_SHADER_TEXT);
    create_shader(VERT_SHADER_FRAMEBUFFER, FRAG_SHADER_TEXTURED_RECT);
    create_shader(VERT_SHADER_FRAMEBUFFER, FRAG_SHADER_BLOOM);
    create_shader(VERT_SHADER_FRAMEBUFFER, FRAG_SHADER_BLOOM_DOWNSAMPLE);
    create_shader(VERT_SHADER_FRAMEBUFFER, FRAG_SHADER_BLOOM_UPSAMPLE);
}

#scope_file

last_shader_id: int;

