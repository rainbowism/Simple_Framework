imgui_init :: () {
    ImGui_Impl_CreateContext();
    ImGui.StyleColorsDark();
    ImGui_Impl_Init(window.handle);
}

imgui_force_frame :: () {
    ui.requested_frames += 1;
}

imgui_request_frame :: () -> bool {
    using ui;
    mx, my: float;
    dx := mouse_pos.x - io.MousePos.x;
    dy := mouse_pos.y - io.MousePos.y;
    if (dx * dx + dy * dy) > 1 {
        requested_frames += 1;
        io.MousePos = mouse_pos;
    }

    if requested_frames == 0  return false;
    requested_frames -= 1;
    return true;
}

imgui_begin :: ($frame_requested := false) {
    ImGui_Impl_NewFrame(window.handle, window.size.width, window.size.height, time.delta, frame_requested);
}

imgui_end :: ($should_render := true) {
    #if should_render  ImGui.Render();
    ImGui_Impl_RenderDrawData(ImGui.GetDrawData());
}

imgui_load_font :: (filepath: string, font_size: float) -> *ImGui.ImFont {
    font := ImGui.ImFontAtlas.AddFontFromFileTTF(ui.io.Fonts, temp_c_string(filepath), font_size);
    ImGui.ImFontAtlas.Build(ui.io.Fonts);
    ImGui_Impl_CreateFontsTexture();
    ui.io.FontDefault = font;
    return font;
}

imgui_shift :: () -> bool {
    return ui.io.KeyShift;
}

imgui_ctrl :: () -> bool {
    return ui.io.KeyCtrl;
}

imgui_alt :: () -> bool {
    return ui.io.KeyAlt;
}

imgui_filename :: (filename: string) {
    if filename.count == 0 {
        ui.io.IniFilename = null;
        return;
    }
    ui.io.IniFilename = filename.data;
}

ImGui_Impl_KeyCallback :: (key: s32, scancode: s32, action: s32, mods: s32) #c_call {
    if key >= 512  return;
    ui.requested_frames += 1;
    ui.io.KeysDown[key] = action >= GLFW_PRESS;
    ui.io.KeyShift      = mods & GLFW_MOD_SHIFT   > 0;
    ui.io.KeyCtrl       = mods & GLFW_MOD_CONTROL > 0;
    ui.io.KeyAlt        = mods & GLFW_MOD_ALT     > 0;
}

ImGui_Impl_MouseCallback :: (button: s32, action: s32, mods: s32) #c_call {
    ui.requested_frames += 1;
	if button < GLFW_MOUSE_BUTTON_4 {
		ui.mouse_pressed[button] = action == GLFW_PRESS;
	}
}

ImGui_Impl_TextCallback :: (codepoint: u32) #c_call {
    ui.requested_frames += 1;
    push_context _imgui_context {
        buf := talloc(size_of(u32) + 1); // unicode rune + 0
        memcpy(buf, *codepoint, size_of(u32));
        ui.io.AddInputCharactersUTF8(ui.io, buf);
    }
}

ImGui_Impl_ScrollCallback :: (x_offset: float64, y_offset: float64) #c_call {
    ui.requested_frames += 1;
    if y_offset > 0 ui.mouse_wheel =  1;
    if y_offset < 0 ui.mouse_wheel = -1;
}

ImGui_Impl_GetClipboardText :: (data: *void) -> *u8 #c_call {
    new_context: Context;
    push_context new_context {
        return glfwGetClipboardString(null);
    }
}

ImGui_Impl_SetClipboardText :: (data: *void, text: *u8) #c_call {
    new_context: Context;
    push_context new_context {
        glfwSetClipboardString(null, text);
    }
}

ImGui_Impl_CreateContext :: ($set_default_allocators := true) {
    using ui;

    #if set_default_allocators {
        _imgui_context = context;
        ImGui.SetAllocatorFunctions(imgui_alloc, imgui_free, *_imgui_context);
    }

    ctx = ImGui.CreateContext();
    io = ImGui.GetIO();
}

ImGui_Impl_Init :: (native_window_handle: *void) -> bool {
    using ui;

    assert(ctx != null, "must call create context");
    ImGui.SetCurrentContext(ctx);

    handle = xx native_window_handle;

    // Keyboard mapping. ImGui will use those indices to peek into the io.KeyDown[] array.
    io.KeyMap[ImGui.Key.Tab]        = xx GLFW_KEY_TAB;
    io.KeyMap[ImGui.Key.LeftArrow]  = xx GLFW_KEY_LEFT;
    io.KeyMap[ImGui.Key.RightArrow] = xx GLFW_KEY_RIGHT;
    io.KeyMap[ImGui.Key.UpArrow]    = xx GLFW_KEY_UP;
    io.KeyMap[ImGui.Key.DownArrow]  = xx GLFW_KEY_DOWN;
    io.KeyMap[ImGui.Key.PageUp]     = xx GLFW_KEY_PAGE_UP;
    io.KeyMap[ImGui.Key.PageDown]   = xx GLFW_KEY_PAGE_DOWN;
    io.KeyMap[ImGui.Key.Home]       = xx GLFW_KEY_HOME;
    io.KeyMap[ImGui.Key.End]        = xx GLFW_KEY_END;
    io.KeyMap[ImGui.Key.Delete]     = xx GLFW_KEY_DELETE;
    io.KeyMap[ImGui.Key.Backspace]  = xx GLFW_KEY_BACKSPACE;
    io.KeyMap[ImGui.Key.Enter]      = xx GLFW_KEY_ENTER;
    io.KeyMap[ImGui.Key.Escape]     = xx GLFW_KEY_ESCAPE;
    io.KeyMap[ImGui.Key.A]          = xx GLFW_KEY_A;
    io.KeyMap[ImGui.Key.C]          = xx GLFW_KEY_C;
    io.KeyMap[ImGui.Key.V]          = xx GLFW_KEY_V;
    io.KeyMap[ImGui.Key.X]          = xx GLFW_KEY_X;
    io.KeyMap[ImGui.Key.Y]          = xx GLFW_KEY_Y;
    io.KeyMap[ImGui.Key.Z]          = xx GLFW_KEY_Z;

    // io.RenderDrawListsFn = ImGui_Impl_RenderDrawLists;   // Alternatively you can set this to NULL and call ImGui::GetDrawData() after ImGui::Render() to get the same ImGui.ImDrawData pointer.
    io.SetClipboardTextFn = ImGui_Impl_SetClipboardText;
    io.GetClipboardTextFn = ImGui_Impl_GetClipboardText;
    io.ClipboardUserData = null;

    ImGui_Impl_CreateDeviceObjects();

    initialized = true;

    return true;
}

ImGui_Impl_Shutdown :: () {
    if ui.ctx == null {
        return;
    }
    ImGui.SetCurrentContext(ui.ctx);
    ImGui_Impl_InvalidateDeviceObjects();
    ImGui.DestroyContext();
    ui.ctx = null;
}

ImGui_Impl_CreateFontsTexture :: () -> bool {
    using ui;

    assert(io != null);
    assert(io.Fonts != null);

    // Build texture atlas
    pixels: *u8 = null;
    width, height: s32;
    assert(io.Fonts != null);
    io.Fonts.GetTexDataAsRGBA32(io.Fonts, *pixels, *width, *height);
    assert(pixels != null);
    assert(width > 0);
    assert(height > 0);

    // Upload texture to graphics system
    last_texture: GLuint;
    glGetIntegerv(GL_TEXTURE_BINDING_2D, xx *last_texture);

    if font_texture != 0  glDeleteTextures(1, *font_texture);
    glGenTextures(1, *font_texture);
    glBindTexture(GL_TEXTURE_2D, font_texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, xx width, xx height, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);

    // Store our identifier
    io.Fonts.TexID = xx font_texture;

    // Restore state
    glBindTexture(GL_TEXTURE_2D, last_texture);

    return true;
}

ImGui_Impl_CreateDeviceObjects :: () -> bool {
    using ui;

    // Backup GL state
    last_texture, last_array_buffer, last_vertex_array: GLuint;
    glGetIntegerv(GL_TEXTURE_BINDING_2D, xx *last_texture);
    glGetIntegerv(GL_ARRAY_BUFFER_BINDING, xx *last_array_buffer);
    glGetIntegerv(GL_VERTEX_ARRAY_BINDING, xx *last_vertex_array);

    vertex_shader := #string ___GLSL
        #version 430 core
        uniform mat4 Projection;
        in vec2 Position;
        in vec2 UV;
        in vec4 Color;
        out vec2 FragUV;
        out vec4 FragColor;
        void main() {
           FragUV = UV;
           FragColor = Color;
           gl_Position = Projection * vec4(Position.xy, 0, 1);
        }
    ___GLSL

    fragment_shader := #string ___GLSL
        #version 430 core
        uniform sampler2D Texture;
        in vec2 FragUV;
        in vec4 FragColor;
        out vec4 OutColor;
        void main() {
           OutColor = FragColor * texture(Texture, FragUV.st);
        }
    ___GLSL

    shader_handle = glCreateProgram();
    vert_handle = glCreateShader(GL_VERTEX_SHADER);
    frag_handle = glCreateShader(GL_FRAGMENT_SHADER);
    _glShaderSource(vert_handle, vertex_shader);
    _glShaderSource(frag_handle, fragment_shader);
    glCompileShader(vert_handle);
    glCompileShader(frag_handle);
    glAttachShader(shader_handle, vert_handle);
    glAttachShader(shader_handle, frag_handle);
    glLinkProgram(shader_handle);

    attrib_location_tex = glGetUniformLocation(shader_handle, "Texture");
    attrib_location_projection = glGetUniformLocation(shader_handle, "Projection");
    attrib_location_position = xx glGetAttribLocation(shader_handle, "Position");
    attrib_location_uv = xx glGetAttribLocation(shader_handle, "UV");
    attrib_location_color = xx glGetAttribLocation(shader_handle, "Color");

    glGenBuffers(1, *vbo_handle);
    glGenBuffers(1, *elements_handle);

    glGenVertexArrays(1, *vao_handle);
    glBindVertexArray(vao_handle);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_handle);
    glEnableVertexAttribArray(attrib_location_position);
    glEnableVertexAttribArray(xx attrib_location_uv);
    glEnableVertexAttribArray(xx attrib_location_color);

    glVertexAttribPointer(attrib_location_position, 2, GL_FLOAT, GL_FALSE, size_of(ImGui.ImDrawVert), xx 0);
    glVertexAttribPointer(attrib_location_uv, 2, GL_FLOAT, GL_FALSE, size_of(ImGui.ImDrawVert), xx 8);
    glVertexAttribPointer(attrib_location_color, 4, GL_UNSIGNED_BYTE, GL_TRUE, size_of(ImGui.ImDrawVert), xx 16);

    ImGui_Impl_CreateFontsTexture();

    // Restore modified GL state
    glBindTexture(GL_TEXTURE_2D, last_texture);
    glBindBuffer(GL_ARRAY_BUFFER, last_array_buffer);
    glBindVertexArray(last_vertex_array);

    return true;
}

ImGui_Impl_InvalidateDeviceObjects :: () {
    using ui;
    if font_texture {
        glDeleteTextures(1, *font_texture);
        io.Fonts.TexID = null;
        font_texture = 0;
    }
}

ImGui_Impl_NewFrame :: (native_window_handle: *void, display_width: s32, display_height: s32, delta: float64, $frame_requested := false) {
    using ui;

    // Setup display size (every frame to accommodate for window resizing)
    io.DisplaySize = make_vector2(xx display_width, xx display_height);
    io.DisplayFramebufferScale = make_vector2(1, 1);

    #if !frame_requested {
        // Setup inputs
        dx := mouse_pos.x - io.MousePos.x;
        dy := mouse_pos.y - io.MousePos.y;
        if (dx * dx + dy * dy) > 1 {
            requested_frames += 1;
            io.MousePos = mouse_pos;
        }
    }

    // Setup time step
    io.DeltaTime = xx delta;

    io.MouseDown[0] = mouse_pressed[0];      // If a mouse press event came, always pass it as "mouse held this frame", so we don't miss click-release events that are shorter than 1 frame.
    io.MouseDown[1] = mouse_pressed[1];
    io.MouseDown[2] = mouse_pressed[2];

    io.MouseWheel = mouse_wheel;
    mouse_wheel = 0.0;

    // Start the frame. This call will update the io.WantCaptureMouse, io.WantCaptureKeyboard flag that you can use to dispatch inputs (or not) to your application.
    ImGui.NewFrame();
}

ImGui_Impl_RenderDrawData :: (draw_data: *ImGui.ImDrawData) {
    using ui;

    // @@ Watch out, we don't have a context here!

    // Avoid rendering when minimized, scale coordinates for retina displays (screen coordinates != framebuffer coordinates)
    fb_width := (io.DisplaySize.x * io.DisplayFramebufferScale.x);
    fb_height := (io.DisplaySize.y * io.DisplayFramebufferScale.y);
    if fb_width == 0 || fb_height == 0 return;
    draw_data.ScaleClipRects(draw_data, io.DisplayFramebufferScale);

    // Backup GL state
    last_active_texture: GLenum;        glGetIntegerv(GL_ACTIVE_TEXTURE, xx *last_active_texture);
    last_program: GLuint;               glGetIntegerv(GL_CURRENT_PROGRAM, xx *last_program);
    last_texture: GLuint;               glGetIntegerv(GL_TEXTURE_BINDING_2D, xx *last_texture);
    last_sampler: GLuint;               glGetIntegerv(GL_SAMPLER_BINDING, xx *last_sampler);
    last_array_buffer: GLuint;          glGetIntegerv(GL_ARRAY_BUFFER_BINDING, xx *last_array_buffer);
    last_element_array_buffer: GLuint;  glGetIntegerv(GL_ELEMENT_ARRAY_BUFFER_BINDING, xx *last_element_array_buffer);
    last_vertex_array: GLuint;          glGetIntegerv(GL_VERTEX_ARRAY_BINDING, xx *last_vertex_array);
    last_polygon_mode: [2]GLuint;       glGetIntegerv(GL_POLYGON_MODE, xx last_polygon_mode.data);
    last_viewport: [4]GLint;            glGetIntegerv(GL_VIEWPORT, last_viewport.data);
    last_scissor_box : [4]GLint;        glGetIntegerv(GL_SCISSOR_BOX, last_scissor_box.data);
    last_blend_src_rgb: GLenum;         glGetIntegerv(GL_BLEND_SRC_RGB, xx *last_blend_src_rgb);
    last_blend_dst_rgb: GLenum;         glGetIntegerv(GL_BLEND_DST_RGB, xx *last_blend_dst_rgb);
    last_blend_src_alpha: GLenum;       glGetIntegerv(GL_BLEND_SRC_ALPHA, xx *last_blend_src_alpha);
    last_blend_dst_alpha: GLenum;       glGetIntegerv(GL_BLEND_DST_ALPHA, xx *last_blend_dst_alpha);
    last_blend_equation_rgb: GLenum;    glGetIntegerv(GL_BLEND_EQUATION_RGB, xx *last_blend_equation_rgb);
    last_blend_equation_alpha: GLenum;  glGetIntegerv(GL_BLEND_EQUATION_ALPHA, xx *last_blend_equation_alpha);
    last_enable_blend :=                glIsEnabled(GL_BLEND);
    last_enable_cull_face :=            glIsEnabled(GL_CULL_FACE);
    last_enable_depth_test :=           glIsEnabled(GL_DEPTH_TEST);
    last_enable_scissor_test :=         glIsEnabled(GL_SCISSOR_TEST);

    // Setup render state: alpha-blending enabled, no face culling, no depth testing, scissor enabled, polygon fill
    glActiveTexture(GL_TEXTURE0);
    glEnable(GL_BLEND);
    glBlendEquation(GL_FUNC_ADD);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glDisable(GL_CULL_FACE);
    glDisable(GL_DEPTH_TEST);
    glEnable(GL_SCISSOR_TEST);
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

    // Setup viewport, orthographic projection matrix
    glViewport(0, 0, xx fb_width, xx fb_height);

    new_context: Context;
    push_context new_context {
        ortho_projection := orthographic_projection_matrix(0, io.DisplaySize.x, io.DisplaySize.y, 0, 0, 1);
        ortho_projection = transpose(ortho_projection);

        glUseProgram(shader_handle);
        glUniform1i(attrib_location_tex, 0);
        glUniformMatrix4fv(attrib_location_projection, 1, GL_FALSE, xx *ortho_projection);
        glBindVertexArray(vao_handle);
        glBindSampler(0, 0); // Rely on combined texture/sampler state.

        // Render command lists
        for n: 0..draw_data.CmdListsCount-1 {
            cmd_list := draw_data.CmdLists[n];
            idx_buffer_offset : *ImGui.ImDrawIdx;

            glBindBuffer(GL_ARRAY_BUFFER, vbo_handle);
            glBufferData(GL_ARRAY_BUFFER, cmd_list.VtxBuffer.Size * size_of(ImGui.ImDrawVert), cmd_list.VtxBuffer.Data, GL_STREAM_DRAW);

            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, elements_handle);
            glBufferData(GL_ELEMENT_ARRAY_BUFFER, cmd_list.IdxBuffer.Size * size_of(ImGui.ImDrawIdx), cmd_list.IdxBuffer.Data, GL_STREAM_DRAW);

            for cmd_i: 0..cmd_list.CmdBuffer.Size-1 {
                pcmd := *cmd_list.CmdBuffer.Data[cmd_i];
                if pcmd.UserCallback {
                    pcmd.UserCallback(cmd_list, pcmd);
                }
                else {
                    glBindTexture(GL_TEXTURE_2D, xx pcmd.TextureId);
                    glScissor(xx pcmd.ClipRect.x, xx (fb_height - pcmd.ClipRect.w), xx (pcmd.ClipRect.z - pcmd.ClipRect.x), xx (pcmd.ClipRect.w - pcmd.ClipRect.y));

                    glDrawElements(GL_TRIANGLES, pcmd.ElemCount, GL_UNSIGNED_SHORT, idx_buffer_offset);
                }
                idx_buffer_offset += pcmd.ElemCount;
            }
        }

        // Restore modified GL state
        glUseProgram(last_program);
        glBindTexture(GL_TEXTURE_2D, last_texture);
        glBindSampler(0, last_sampler);
        glActiveTexture(last_active_texture);
        glBindVertexArray(last_vertex_array);
        glBindBuffer(GL_ARRAY_BUFFER, last_array_buffer);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, last_element_array_buffer);
        glBlendEquationSeparate(last_blend_equation_rgb, last_blend_equation_alpha);
        glBlendFuncSeparate(last_blend_src_rgb, last_blend_dst_rgb, last_blend_src_alpha, last_blend_dst_alpha);
        if last_enable_blend        glEnable(GL_BLEND);         else glDisable(GL_BLEND);
        if last_enable_cull_face    glEnable(GL_CULL_FACE);     else glDisable(GL_CULL_FACE);
        if last_enable_depth_test   glEnable(GL_DEPTH_TEST);    else glDisable(GL_DEPTH_TEST);
        if last_enable_scissor_test glEnable(GL_SCISSOR_TEST);  else glDisable(GL_SCISSOR_TEST);
        glPolygonMode(GL_FRONT_AND_BACK, last_polygon_mode[0]);
        glViewport(last_viewport[0], last_viewport[1], xx last_viewport[2], xx last_viewport[3]);
        glScissor(last_scissor_box[0], last_scissor_box[1], xx last_scissor_box[2], xx last_scissor_box[3]);
    }
}

#scope_file

UI_State :: struct {
    ctx:         *ImGui.Context;
    io:          *ImGui.IO;
    handle:      *GLFWwindow;
    initialized: bool;
    requested_frames: s64 = 2;

    mouse_pressed:              [3]bool = .[false, false, false];
    mouse_wheel:                float   = 0.0;
    font_texture:               GLuint  = 0;
    shader_handle:              GLuint  = 0;
    vert_handle:                GLuint  = 0;
    frag_handle:                GLuint  = 0;
    attrib_location_tex:        GLint   = 0;
    attrib_location_projection: GLint   = 0;
    attrib_location_position:   GLuint  = 0;
    attrib_location_uv:         GLuint  = 0;
    attrib_location_color:      GLuint  = 0;
    vbo_handle:                 GLuint  = 0;
    vao_handle:                 GLuint  = 0;
    elements_handle:            GLuint  = 0;
};
ui: UI_State;

_imgui_context: Context;

imgui_alloc :: (sz: u64, userdata: *void) -> *void #c_call {
    push_context << cast(*Context)userdata { return alloc(cast(s64)sz); }
}

imgui_free :: (ptr: *void, userdata: *void) #c_call {
    push_context << cast(*Context)userdata { free(ptr); }
}

#import "Basic";
#import "Math";
#import "glfw";
#import "GL";
ImGui :: #import "ImGui";
