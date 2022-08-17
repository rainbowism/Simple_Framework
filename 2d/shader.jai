Uniform :: struct {
    id:       s64;
    data:     *void;
    count:    s64;
    location: GLint;
}

Shader :: struct {
    id:          s64;
    gl_id:       GLuint;
    uniforms: [] Uniform;
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
            buffer:        [1024] u8;
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
