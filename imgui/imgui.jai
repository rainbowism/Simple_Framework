imgui_init :: () {
    assert(ui.init_value != ImGui_Init_Value, "Trying to initialize ImGui module again!");
    ImGui_Impl_CreateContext();
    ImGui.StyleColorsDark();
    ImGui_Impl_Init(window.handle);
}

imgui_deinit :: () {
    ImGui_Impl_Shutdown();
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

imgui_force_frame :: () {
    ui.requested_frames += 1;
}

imgui_filename :: (filename: string) {
    if filename.count == 0 {
        ui.io.IniFilename = null;
        return;
    }
    ui.io.IniFilename = filename.data;
}

imgui_begin :: ($frame_requested := false) {
    ImGui_Impl_NewFrame(window.handle, window.size_i.x, window.size_i.y, sf_time.delta, frame_requested);
}

imgui_end :: ($should_render := true) {
    #if should_render  ImGui.Render();
    ImGui_Impl_RenderDrawData(ImGui.GetDrawData());
}

imgui_update_flags :: inline (flags: ImGui.ConfigFlags, $disable := false) {
    #if disable {
        ui.io.ConfigFlags_ &= ~flags;
    } else {
        ui.io.ConfigFlags_ |= flags;
    }
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

imgui_want_mouse :: inline () -> bool {
    return ui.io.WantCaptureMouse;
}

imgui_want_keyboard :: inline () -> bool {
    return ui.io.WantCaptureKeyboard;
}

imgui_want_text_input :: inline () -> bool {
    return ui.io.WantTextInput;
}

imgui_load_font :: (filepath: string, font_size: float, oversample_h: s32 = 2, oversample_v: s32 = 2, icons_path: *u8 = null, icon_scale := 0.75) -> *ImGui.ImFont {
    config: ImGui.ImFontConfig;
    ImGui.ImFontConfig.Constructor(*config);
    config.OversampleH = oversample_h;
    config.OversampleV = oversample_v;

    if icons_path {
        ImGui.ImFontConfig.Constructor(*config);
        config.MergeMode = true;
        config.GlyphMinAdvanceX = font_size * icon_scale;
        config.OversampleH = oversample_h;
        config.OversampleV = oversample_v;
        ImGui.ImFontAtlas.AddFontFromFileTTF(ui.io.Fonts, icons_path, font_size * icon_scale, *config, Font_Awesome_Glyphs.data);
    }

    ImGui.ImFontAtlas.Clear(ui.io.Fonts);
    font := ImGui.ImFontAtlas.AddFontFromFileTTF(ui.io.Fonts, temp_c_string(filepath), font_size, *config);
    ImGui.ImFontAtlas.Build(ui.io.Fonts);
    ImGui_Impl_CreateFontsTexture();
    ui.io.FontDefault = font;
    return font;
}

imgui_load_font_from_memory :: (font_buffer: string, font_size: float, oversample_h: s32 = 2, oversample_v: s32 = 2, icons_path: *u8 = null, icon_scale := 0.75) -> *ImGui.ImFont {
    config: ImGui.ImFontConfig;
    ImGui.ImFontConfig.Constructor(*config);
    config.OversampleH = oversample_h;
    config.OversampleV = oversample_v;

    ImGui.ImFontAtlas.Clear(ui.io.Fonts);
    font := ImGui.ImFontAtlas.AddFontFromMemoryTTF(ui.io.Fonts, font_buffer.data, xx font_buffer.count, font_size, *config);

    if icons_path {
        ImGui.ImFontConfig.Constructor(*config);
        config.MergeMode = true;
        config.GlyphMinAdvanceX = font_size * icon_scale;
        config.OversampleH = oversample_h;
        config.OversampleV = oversample_v;
        ImGui.ImFontAtlas.AddFontFromFileTTF(ui.io.Fonts, icons_path, font_size * icon_scale, *config, Font_Awesome_Glyphs.data);
    }

    ImGui.ImFontAtlas.Build(ui.io.Fonts);
    ImGui_Impl_CreateFontsTexture();
    ui.io.FontDefault = font;
    return font;
}

#scope_module


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

ImGui_Impl_CreateContext :: () {
    using ui;

    _imgui_context = context;
    ctx = ImGui.CreateContext();
    io = ImGui.GetIO();
}

ImGui_Impl_Init :: (native_window_handle: *void) -> bool {
    using ui;

    assert(ctx != null, "must call create context");
    ImGui.SetCurrentContext(ctx);

    handle = xx native_window_handle;

    // Keyboard mapping. ImGui will use those indices to peek into the io.KeyDown[] array.
    io.KeyMap[ImGui.Key.Tab]            = xx GLFW_KEY_TAB;
    io.KeyMap[ImGui.Key.LeftArrow]      = xx GLFW_KEY_LEFT;
    io.KeyMap[ImGui.Key.RightArrow]     = xx GLFW_KEY_RIGHT;
    io.KeyMap[ImGui.Key.UpArrow]        = xx GLFW_KEY_UP;
    io.KeyMap[ImGui.Key.DownArrow]      = xx GLFW_KEY_DOWN;
    io.KeyMap[ImGui.Key.PageUp]         = xx GLFW_KEY_PAGE_UP;
    io.KeyMap[ImGui.Key.PageDown]       = xx GLFW_KEY_PAGE_DOWN;
    io.KeyMap[ImGui.Key.Home]           = xx GLFW_KEY_HOME;
    io.KeyMap[ImGui.Key.End]            = xx GLFW_KEY_END;
    io.KeyMap[ImGui.Key.Insert]         = xx GLFW_KEY_INSERT;
    io.KeyMap[ImGui.Key.Delete]         = xx GLFW_KEY_DELETE;
    io.KeyMap[ImGui.Key.Backspace]      = xx GLFW_KEY_BACKSPACE;
    io.KeyMap[ImGui.Key.Space]          = xx GLFW_KEY_SPACE;
    io.KeyMap[ImGui.Key.Enter]          = xx GLFW_KEY_ENTER;
    io.KeyMap[ImGui.Key.Escape]         = xx GLFW_KEY_ESCAPE;
    io.KeyMap[ImGui.Key.LeftCtrl]       = xx GLFW_KEY_LEFT_CONTROL;
    io.KeyMap[ImGui.Key.LeftShift]      = xx GLFW_KEY_LEFT_SHIFT;
    io.KeyMap[ImGui.Key.LeftAlt]        = xx GLFW_KEY_LEFT_ALT;
    io.KeyMap[ImGui.Key.LeftSuper]      = xx GLFW_KEY_LEFT_SUPER;
    io.KeyMap[ImGui.Key.RightCtrl]      = xx GLFW_KEY_RIGHT_CONTROL;
    io.KeyMap[ImGui.Key.RightShift]     = xx GLFW_KEY_RIGHT_SHIFT;
    io.KeyMap[ImGui.Key.RightAlt]       = xx GLFW_KEY_RIGHT_ALT;
    io.KeyMap[ImGui.Key.RightSuper]     = xx GLFW_KEY_RIGHT_SUPER;
    io.KeyMap[ImGui.Key.Menu]           = xx GLFW_KEY_MENU;
    io.KeyMap[ImGui.Key.Apostrophe]     = xx GLFW_KEY_APOSTROPHE;
    io.KeyMap[ImGui.Key.Comma]          = xx GLFW_KEY_COMMA;
    io.KeyMap[ImGui.Key.Minus]          = xx GLFW_KEY_MINUS;
    io.KeyMap[ImGui.Key.Period]         = xx GLFW_KEY_PERIOD;
    io.KeyMap[ImGui.Key.Slash]          = xx GLFW_KEY_SLASH;
    io.KeyMap[ImGui.Key.Semicolon]      = xx GLFW_KEY_SEMICOLON;
    io.KeyMap[ImGui.Key.Equal]          = xx GLFW_KEY_EQUAL;
    io.KeyMap[ImGui.Key.LeftBracket]    = xx GLFW_KEY_LEFT_BRACKET;
    io.KeyMap[ImGui.Key.Backslash]      = xx GLFW_KEY_BACKSLASH;
    io.KeyMap[ImGui.Key.RightBracket]   = xx GLFW_KEY_RIGHT_BRACKET;
    io.KeyMap[ImGui.Key.GraveAccent]    = xx GLFW_KEY_GRAVE_ACCENT;
    io.KeyMap[ImGui.Key.CapsLock]       = xx GLFW_KEY_CAPS_LOCK;
    io.KeyMap[ImGui.Key.ScrollLock]     = xx GLFW_KEY_SCROLL_LOCK;
    io.KeyMap[ImGui.Key.NumLock]        = xx GLFW_KEY_NUM_LOCK;
    io.KeyMap[ImGui.Key.PrintScreen]    = xx GLFW_KEY_PRINT_SCREEN;
    io.KeyMap[ImGui.Key.Pause]          = xx GLFW_KEY_PAUSE;
    io.KeyMap[ImGui.Key.KeypadDecimal]  = xx GLFW_KEY_KP_DECIMAL;
    io.KeyMap[ImGui.Key.KeypadDivide]   = xx GLFW_KEY_KP_DIVIDE;
    io.KeyMap[ImGui.Key.KeypadMultiply] = xx GLFW_KEY_KP_MULTIPLY;
    io.KeyMap[ImGui.Key.KeypadSubtract] = xx GLFW_KEY_KP_SUBTRACT;
    io.KeyMap[ImGui.Key.KeypadAdd]      = xx GLFW_KEY_KP_ADD;
    io.KeyMap[ImGui.Key.KeypadEnter]    = xx GLFW_KEY_KP_ENTER;
    io.KeyMap[ImGui.Key.KeypadEqual]    = xx GLFW_KEY_KP_EQUAL;
    _0_Key_Offset :: ImGui.Key._0 - GLFW_KEY_0;
    for ImGui.Key._0..ImGui.Key._9-1 {
        io.KeyMap[it] = xx (it - _0_Key_Offset);
    }
    A_Key_Offset :: ImGui.Key.A - GLFW_KEY_A;
    for ImGui.Key.A..ImGui.Key.Z-1 {
        io.KeyMap[it] = xx (it - A_Key_Offset);
    }
    F1_Key_Offset :: ImGui.Key.F1 - GLFW_KEY_F1;
    for ImGui.Key.F1..ImGui.Key.F12-1 {
        io.KeyMap[it] = xx (it - F1_Key_Offset);
    }
    KP0_Key_Offset :: ImGui.Key.Keypad0 - GLFW_KEY_KP_0;
    for ImGui.Key.Keypad0..ImGui.Key.Keypad9-1 {
        io.KeyMap[it] = xx (it - KP0_Key_Offset);
    }

    // io.RenderDrawListsFn = ImGui_Impl_RenderDrawLists;   // Alternatively you can set this to NULL and call ImGui::GetDrawData() after ImGui::Render() to get the same ImGui.ImDrawData pointer.
    io.SetClipboardTextFn = ImGui_Impl_SetClipboardText;
    io.GetClipboardTextFn = ImGui_Impl_GetClipboardText;
    io.ClipboardUserData = null;

    ImGui_Impl_CreateDeviceObjects();

    init_value = 0xF8008135;

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
    io.Fonts.GetTexDataAsRGBA32(io.Fonts, *pixels, *width, *height);
    assert(pixels != null);
    assert(width > 0);
    assert(height > 0);

    if font_image != SG_INVALID_ID  sg_destroy_image(font_image);

    image_desc: sg_image_desc;
    image_desc.width  = width;
    image_desc.height = height;
    image_desc.pixel_format = .RGBA8;
    image_desc.min_filter   = .LINEAR;
    image_desc.mag_filter   = .LINEAR;
    image_desc.wrap_u       = .CLAMP_TO_EDGE;
    image_desc.wrap_v       = .CLAMP_TO_EDGE;
    image_desc.data.subimage[0][0] = sg_range.{pixels, xx,no_check (width * height * size_of(u32))};
    image_desc.label = "ImGui Font Image";
    font_image = sg_make_image(*image_desc);
    assert(font_image != SG_INVALID_ID, "Failed to generate a font for ImGui.");

    // Store our identifier
    io.Fonts.TexID = xx font_image;

    return true;
}

ImGui_Impl_CreateDeviceObjects :: () -> bool {
    using ui;

    Max_Vertices :: 65536;
    vertices.size = Max_Vertices * size_of(ImGui.ImDrawVert);
    vertices.ptr  = alloc(xx vertices.size);
    indices.size  = Max_Vertices * 3 * size_of(ImGui.ImDrawIdx);
    indices.ptr   = alloc(xx indices.size);

    vb_desc: sg_buffer_desc;
    vb_desc.usage = .STREAM;
    vb_desc.size  = vertices.size;
    vb_desc.label = "ImGui Vertices";
    vertex_buffer = sg_make_buffer(*vb_desc);

    ib_desc: sg_buffer_desc;
    ib_desc.type  = .INDEXBUFFER;
    ib_desc.usage = .STREAM;
    ib_desc.size  = indices.size;
    ib_desc.label = "ImGui Indices";
    index_buffer = sg_make_buffer(*ib_desc);

    ImGui_Impl_CreateFontsTexture();

    shader_desc: sg_shader_desc;
    shader_desc.attrs[0].name = "vPos";
    shader_desc.attrs[1].name = "vUV";
    shader_desc.attrs[2].name = "vColor";
    shader_desc.attrs[0].sem_name = "TEXCOORD";
    shader_desc.attrs[0].sem_index = 0;
    shader_desc.attrs[1].sem_name = "TEXCOORD";
    shader_desc.attrs[1].sem_index = 1;
    shader_desc.attrs[2].sem_name = "TEXCOORD";
    shader_desc.attrs[2].sem_index = 2;
    ub := *shader_desc.vs.uniform_blocks[0];
    ub.size = size_of(ImGui_VS_Params);
    ub.uniforms[0].name = "display_size";
    ub.uniforms[0].type = .FLOAT2;
    ub.uniforms[0].array_count = 1;
    shader_desc.fs.images[0].name = "TEXTURE";
    shader_desc.fs.images[0].image_type = ._2D;
    shader_desc.fs.images[0].sampler_type = .FLOAT;
    shader_desc.label = "ImGui Shader";

    // @Todo: Implement other backends.
    shader_desc.vs.source = ImGui_Vert_Shader;
    shader_desc.fs.source = ImGui_Frag_Shader;

    shader = sg_make_shader(*shader_desc);

    pipe_desc: sg_pipeline_desc;
    pipe_desc.layout.buffers[0].stride = size_of(ImGui.ImDrawVert);
    pipe_desc.layout.attrs[0].offset = 0;
    pipe_desc.layout.attrs[0].format = .FLOAT2;
    pipe_desc.layout.attrs[1].offset = size_of(Vector2);
    pipe_desc.layout.attrs[1].format = .FLOAT2;
    pipe_desc.layout.attrs[2].offset = 2 * size_of(Vector2);
    pipe_desc.layout.attrs[2].format = .UBYTE4N;
    pipe_desc.shader = shader;
    pipe_desc.index_type = .UINT16;
    pipe_desc.sample_count = 0;
    pipe_desc.depth.pixel_format = 0;
    pipe_desc.colors[0].pixel_format = 0;
    pipe_desc.colors[0].write_mask = 0;
    pipe_desc.colors[0].blend.enabled = true;
    pipe_desc.colors[0].blend.src_factor_rgb = .SRC_ALPHA;
    pipe_desc.colors[0].blend.dst_factor_rgb = .ONE_MINUS_SRC_ALPHA;
    pipe_desc.label = "ImGui Pipeline";
    pipe = sg_make_pipeline(*pipe_desc);

    return true;
}

ImGui_Impl_InvalidateDeviceObjects :: () {
    using ui;
    if font_texture {
        sg_destroy_image(font_image);
        io.Fonts.TexID = null;
        font_image = SG_INVALID_ID;
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
    if draw_data == null             return;
    if draw_data.CmdListsCount == 0  return;

    fb_width  := cast(s32) (io.DisplaySize.x * io.DisplayFramebufferScale.x);
    fb_height := cast(s32) (io.DisplaySize.y * io.DisplayFramebufferScale.y);
    if fb_width == 0 || fb_height == 0 return;

    all_vtx_size:   s32;
    all_idx_size:   s32;
    cmd_list_count: s32;

    for 0..draw_data.CmdListsCount-1 {
        cmd_list := draw_data.CmdLists[it];
        vtx_size := cmd_list.VtxBuffer.Size * size_of(ImGui.ImDrawVert);
        idx_size := cmd_list.IdxBuffer.Size * size_of(ImGui.ImDrawIdx);

        if (all_vtx_size + vtx_size) > cast(s32) vertices.size
        || (all_idx_size + idx_size) > cast(s32) indices.size {
            break;
        }

        if vtx_size > 0 {
            src_vtx := cmd_list.VtxBuffer.Data;
            dst_vtx := vertices.ptr + all_vtx_size;
            memcpy(dst_vtx, src_vtx, vtx_size);
        }
        if idx_size > 0 {
            src_idx := cmd_list.IdxBuffer.Data;
            dst_idx := indices.ptr + all_idx_size;
            memcpy(dst_idx, src_idx, idx_size);
        }
        all_vtx_size += vtx_size;
        all_idx_size += idx_size;
    }

    sg_push_debug_group("ImGui");
    if all_vtx_size > 0 {
        vtx_data := vertices;
        vtx_data.size = xx all_vtx_size;
        sg_update_buffer(vertex_buffer, *vtx_data);
    }
    if all_idx_size > 0 {
        idx_data := indices;
        idx_data.size = xx all_idx_size;
        sg_update_buffer(index_buffer, *idx_data);
    }

    draw_data.ScaleClipRects(draw_data, io.DisplayFramebufferScale);

    sg_apply_viewport(0, 0, fb_width, fb_height, true);
    sg_apply_scissor_rect(0, 0, fb_width, fb_height, true);

    sg_apply_pipeline(pipe);
    vs_params: ImGui_VS_Params;
    vs_params.display_size = io.DisplaySize;
    sg_apply_uniforms(.VS, 0, *sg_range.{*vs_params, size_of(ImGui_VS_Params)});
    bind: sg_bindings;
    bind.vertex_buffers[0] = vertex_buffer;
    bind.index_buffer      = index_buffer;
    tex_id := io.Fonts.TexID;
    bind.fs_images[0] = cast(sg_image) tex_id;
    vb_offset, ib_offset: s32;
    for cl_index: 0..draw_data.CmdListsCount-1 {
        cmd_list := draw_data.CmdLists[cl_index];
        bind.vertex_buffer_offsets[0] = vb_offset;
        bind.index_buffer_offset      = ib_offset;
        sg_apply_bindings(*bind);

        vtx_offset: u32;
        for cmd_index: 0..cmd_list.CmdBuffer.Size-1 {
            pcmd := *cmd_list.CmdBuffer.Data[cmd_index];
            if pcmd.UserCallback {
                pcmd.UserCallback(cmd_list, pcmd);
                sg_apply_viewport(0, 0, fb_width, fb_height, true);
                sg_apply_pipeline(pipe);
                sg_apply_uniforms(.VS, 0, *sg_range.{*vs_params, size_of(ImGui_VS_Params)});
                sg_apply_bindings(*bind);
            } else {
                if tex_id != pcmd.TextureId || vtx_offset != pcmd.VtxOffset {
                    tex_id     = pcmd.TextureId;
                    vtx_offset = pcmd.VtxOffset;
                    bind.fs_images[0] = cast(sg_image) tex_id;
                    bind.vertex_buffer_offsets[0] = vb_offset + (cast(s32) pcmd.VtxOffset * size_of(ImGui.ImDrawVert));
                    sg_apply_bindings(*bind);
                }
                sg_apply_scissor_rect(
                    xx pcmd.ClipRect.x,
                    xx pcmd.ClipRect.y,
                    xx (pcmd.ClipRect.z - pcmd.ClipRect.x),
                    xx (pcmd.ClipRect.w - pcmd.ClipRect.y),
                    true
                );
                sg_draw(xx pcmd.IdxOffset, xx pcmd.ElemCount, 1);
            }
        }
        vb_offset += cmd_list.VtxBuffer.Size * size_of(ImGui.ImDrawVert);
        ib_offset += cmd_list.IdxBuffer.Size * size_of(ImGui.ImDrawIdx);
    }

    sg_apply_viewport(0, 0, fb_width, fb_height, true);
    sg_apply_scissor_rect(0, 0, fb_width, fb_height, true);

    sg_pop_debug_group();
}

#scope_file

ImGui :: #import "ImGuiDocking";

ImGui_Init_Value :: 0xF8008135;

ImGui_VS_Params :: struct {
    display_size: Vector2;
    // _padding: [8] u8; // @Note: Requires padding to align to 16 bytes for some backends.
}

UI_State :: struct {
    ctx:         *ImGui.ImGuiContext;
    io:          *ImGui.IO;
    handle:      *GLFWwindow;
    requested_frames: s64 = 2;

    mouse_pressed:              [3]bool = .[false, false, false];
    mouse_wheel:                float   = 0.0;

    vertex_buffer: sg_buffer;
    index_buffer:  sg_buffer;
    font_image:    sg_image;
    shader:   sg_shader;
    pipe:     sg_pipeline;
    vertices: sg_range;
    indices:  sg_range;

    init_value: u32;
};
ui: UI_State;
_imgui_context: Context;

ImGui_Vert_Shader :: #string ___glsl
#version 330

layout(location=0) in vec2 vPos;
layout(location=1) in vec2 vUV;
layout(location=2) in vec4 vColor;
out vec2 fUV;
out vec4 fColor;

uniform vec2 display_size;

void main() {
    gl_Position = vec4(((vPos / display_size) - 0.5) * vec2(2.0, -2.0), 0.5, 1.0);
    // gl_Position = vec4(vPos / display_size, 0.5, 1.0);
    fUV = vUV;
    fColor = vColor;
}
___glsl

ImGui_Frag_Shader :: #string ___glsl
#version 330

in vec2 fUV;
in vec4 fColor;
out vec4 COLOR;

uniform sampler2D TEXTURE;

void main() {
    COLOR = texture(TEXTURE, fUV) * fColor;
    // COLOR = vec4(1.0);
}
___glsl

Font_Awesome_Glyphs :: u16.[ICON_MIN_FA, ICON_MAX_FA, 0];

#scope_export

FONT_ICON_FILE_NAME_FA :: "fontawesome-webfont.ttf";

ICON_MIN_FA :: 0xf000;
ICON_MAX_16_FA :: 0xf2e0;
ICON_MAX_FA :: 0xf2e0;
ICON_FA_GLASS :: "\xef\x80\x80";
ICON_FA_MUSIC :: "\xef\x80\x81";
ICON_FA_SEARCH :: "\xef\x80\x82";
ICON_FA_ENVELOPE_O :: "\xef\x80\x83";
ICON_FA_HEART :: "\xef\x80\x84";
ICON_FA_STAR :: "\xef\x80\x85";
ICON_FA_STAR_O :: "\xef\x80\x86";
ICON_FA_USER :: "\xef\x80\x87";
ICON_FA_FILM :: "\xef\x80\x88";
ICON_FA_TH_LARGE :: "\xef\x80\x89";
ICON_FA_TH :: "\xef\x80\x8a";
ICON_FA_TH_LIST :: "\xef\x80\x8b";
ICON_FA_CHECK :: "\xef\x80\x8c";
ICON_FA_TIMES :: "\xef\x80\x8d";
ICON_FA_SEARCH_PLUS :: "\xef\x80\x8e";
ICON_FA_SEARCH_MINUS :: "\xef\x80\x90";
ICON_FA_POWER_OFF :: "\xef\x80\x91";
ICON_FA_SIGNAL :: "\xef\x80\x92";
ICON_FA_COG :: "\xef\x80\x93";
ICON_FA_TRASH_O :: "\xef\x80\x94";
ICON_FA_HOME :: "\xef\x80\x95";
ICON_FA_FILE_O :: "\xef\x80\x96";
ICON_FA_CLOCK_O :: "\xef\x80\x97";
ICON_FA_ROAD :: "\xef\x80\x98";
ICON_FA_DOWNLOAD :: "\xef\x80\x99";
ICON_FA_ARROW_CIRCLE_O_DOWN :: "\xef\x80\x9a";
ICON_FA_ARROW_CIRCLE_O_UP :: "\xef\x80\x9b";
ICON_FA_INBOX :: "\xef\x80\x9c";
ICON_FA_PLAY_CIRCLE_O :: "\xef\x80\x9d";
ICON_FA_REPEAT :: "\xef\x80\x9e";
ICON_FA_REFRESH :: "\xef\x80\xa1";
ICON_FA_LIST_ALT :: "\xef\x80\xa2";
ICON_FA_LOCK :: "\xef\x80\xa3";
ICON_FA_FLAG :: "\xef\x80\xa4";
ICON_FA_HEADPHONES :: "\xef\x80\xa5";
ICON_FA_VOLUME_OFF :: "\xef\x80\xa6";
ICON_FA_VOLUME_DOWN :: "\xef\x80\xa7";
ICON_FA_VOLUME_UP :: "\xef\x80\xa8";
ICON_FA_QRCODE :: "\xef\x80\xa9";
ICON_FA_BARCODE :: "\xef\x80\xaa";
ICON_FA_TAG :: "\xef\x80\xab";
ICON_FA_TAGS :: "\xef\x80\xac";
ICON_FA_BOOK :: "\xef\x80\xad";
ICON_FA_BOOKMARK :: "\xef\x80\xae";
ICON_FA_PRINT :: "\xef\x80\xaf";
ICON_FA_CAMERA :: "\xef\x80\xb0";
ICON_FA_FONT :: "\xef\x80\xb1";
ICON_FA_BOLD :: "\xef\x80\xb2";
ICON_FA_ITALIC :: "\xef\x80\xb3";
ICON_FA_TEXT_HEIGHT :: "\xef\x80\xb4";
ICON_FA_TEXT_WIDTH :: "\xef\x80\xb5";
ICON_FA_ALIGN_LEFT :: "\xef\x80\xb6";
ICON_FA_ALIGN_CENTER :: "\xef\x80\xb7";
ICON_FA_ALIGN_RIGHT :: "\xef\x80\xb8";
ICON_FA_ALIGN_JUSTIFY :: "\xef\x80\xb9";
ICON_FA_LIST :: "\xef\x80\xba";
ICON_FA_OUTDENT :: "\xef\x80\xbb";
ICON_FA_INDENT :: "\xef\x80\xbc";
ICON_FA_VIDEO_CAMERA :: "\xef\x80\xbd";
ICON_FA_PICTURE_O :: "\xef\x80\xbe";
ICON_FA_PENCIL :: "\xef\x81\x80";
ICON_FA_MAP_MARKER :: "\xef\x81\x81";
ICON_FA_ADJUST :: "\xef\x81\x82";
ICON_FA_TINT :: "\xef\x81\x83";
ICON_FA_PENCIL_SQUARE_O :: "\xef\x81\x84";
ICON_FA_SHARE_SQUARE_O :: "\xef\x81\x85";
ICON_FA_CHECK_SQUARE_O :: "\xef\x81\x86";
ICON_FA_ARROWS :: "\xef\x81\x87";
ICON_FA_STEP_BACKWARD :: "\xef\x81\x88";
ICON_FA_FAST_BACKWARD :: "\xef\x81\x89";
ICON_FA_BACKWARD :: "\xef\x81\x8a";
ICON_FA_PLAY :: "\xef\x81\x8b";
ICON_FA_PAUSE :: "\xef\x81\x8c";
ICON_FA_STOP :: "\xef\x81\x8d";
ICON_FA_FORWARD :: "\xef\x81\x8e";
ICON_FA_FAST_FORWARD :: "\xef\x81\x90";
ICON_FA_STEP_FORWARD :: "\xef\x81\x91";
ICON_FA_EJECT :: "\xef\x81\x92";
ICON_FA_CHEVRON_LEFT :: "\xef\x81\x93";
ICON_FA_CHEVRON_RIGHT :: "\xef\x81\x94";
ICON_FA_PLUS_CIRCLE :: "\xef\x81\x95";
ICON_FA_MINUS_CIRCLE :: "\xef\x81\x96";
ICON_FA_TIMES_CIRCLE :: "\xef\x81\x97";
ICON_FA_CHECK_CIRCLE :: "\xef\x81\x98";
ICON_FA_QUESTION_CIRCLE :: "\xef\x81\x99";
ICON_FA_INFO_CIRCLE :: "\xef\x81\x9a";
ICON_FA_CROSSHAIRS :: "\xef\x81\x9b";
ICON_FA_TIMES_CIRCLE_O :: "\xef\x81\x9c";
ICON_FA_CHECK_CIRCLE_O :: "\xef\x81\x9d";
ICON_FA_BAN :: "\xef\x81\x9e";
ICON_FA_ARROW_LEFT :: "\xef\x81\xa0";
ICON_FA_ARROW_RIGHT :: "\xef\x81\xa1";
ICON_FA_ARROW_UP :: "\xef\x81\xa2";
ICON_FA_ARROW_DOWN :: "\xef\x81\xa3";
ICON_FA_SHARE :: "\xef\x81\xa4";
ICON_FA_EXPAND :: "\xef\x81\xa5";
ICON_FA_COMPRESS :: "\xef\x81\xa6";
ICON_FA_PLUS :: "\xef\x81\xa7";
ICON_FA_MINUS :: "\xef\x81\xa8";
ICON_FA_ASTERISK :: "\xef\x81\xa9";
ICON_FA_EXCLAMATION_CIRCLE :: "\xef\x81\xaa";
ICON_FA_GIFT :: "\xef\x81\xab";
ICON_FA_LEAF :: "\xef\x81\xac";
ICON_FA_FIRE :: "\xef\x81\xad";
ICON_FA_EYE :: "\xef\x81\xae";
ICON_FA_EYE_SLASH :: "\xef\x81\xb0";
ICON_FA_EXCLAMATION_TRIANGLE :: "\xef\x81\xb1";
ICON_FA_PLANE :: "\xef\x81\xb2";
ICON_FA_CALENDAR :: "\xef\x81\xb3";
ICON_FA_RANDOM :: "\xef\x81\xb4";
ICON_FA_COMMENT :: "\xef\x81\xb5";
ICON_FA_MAGNET :: "\xef\x81\xb6";
ICON_FA_CHEVRON_UP :: "\xef\x81\xb7";
ICON_FA_CHEVRON_DOWN :: "\xef\x81\xb8";
ICON_FA_RETWEET :: "\xef\x81\xb9";
ICON_FA_SHOPPING_CART :: "\xef\x81\xba";
ICON_FA_FOLDER :: "\xef\x81\xbb";
ICON_FA_FOLDER_OPEN :: "\xef\x81\xbc";
ICON_FA_ARROWS_V :: "\xef\x81\xbd";
ICON_FA_ARROWS_H :: "\xef\x81\xbe";
ICON_FA_BAR_CHART :: "\xef\x82\x80";
ICON_FA_TWITTER_SQUARE :: "\xef\x82\x81";
ICON_FA_FACEBOOK_SQUARE :: "\xef\x82\x82";
ICON_FA_CAMERA_RETRO :: "\xef\x82\x83";
ICON_FA_KEY :: "\xef\x82\x84";
ICON_FA_COGS :: "\xef\x82\x85";
ICON_FA_COMMENTS :: "\xef\x82\x86";
ICON_FA_THUMBS_O_UP :: "\xef\x82\x87";
ICON_FA_THUMBS_O_DOWN :: "\xef\x82\x88";
ICON_FA_STAR_HALF :: "\xef\x82\x89";
ICON_FA_HEART_O :: "\xef\x82\x8a";
ICON_FA_SIGN_OUT :: "\xef\x82\x8b";
ICON_FA_LINKEDIN_SQUARE :: "\xef\x82\x8c";
ICON_FA_THUMB_TACK :: "\xef\x82\x8d";
ICON_FA_EXTERNAL_LINK :: "\xef\x82\x8e";
ICON_FA_SIGN_IN :: "\xef\x82\x90";
ICON_FA_TROPHY :: "\xef\x82\x91";
ICON_FA_GITHUB_SQUARE :: "\xef\x82\x92";
ICON_FA_UPLOAD :: "\xef\x82\x93";
ICON_FA_LEMON_O :: "\xef\x82\x94";
ICON_FA_PHONE :: "\xef\x82\x95";
ICON_FA_SQUARE_O :: "\xef\x82\x96";
ICON_FA_BOOKMARK_O :: "\xef\x82\x97";
ICON_FA_PHONE_SQUARE :: "\xef\x82\x98";
ICON_FA_TWITTER :: "\xef\x82\x99";
ICON_FA_FACEBOOK :: "\xef\x82\x9a";
ICON_FA_GITHUB :: "\xef\x82\x9b";
ICON_FA_UNLOCK :: "\xef\x82\x9c";
ICON_FA_CREDIT_CARD :: "\xef\x82\x9d";
ICON_FA_RSS :: "\xef\x82\x9e";
ICON_FA_HDD_O :: "\xef\x82\xa0";
ICON_FA_BULLHORN :: "\xef\x82\xa1";
ICON_FA_BELL :: "\xef\x83\xb3";
ICON_FA_CERTIFICATE :: "\xef\x82\xa3";
ICON_FA_HAND_O_RIGHT :: "\xef\x82\xa4";
ICON_FA_HAND_O_LEFT :: "\xef\x82\xa5";
ICON_FA_HAND_O_UP :: "\xef\x82\xa6";
ICON_FA_HAND_O_DOWN :: "\xef\x82\xa7";
ICON_FA_ARROW_CIRCLE_LEFT :: "\xef\x82\xa8";
ICON_FA_ARROW_CIRCLE_RIGHT :: "\xef\x82\xa9";
ICON_FA_ARROW_CIRCLE_UP :: "\xef\x82\xaa";
ICON_FA_ARROW_CIRCLE_DOWN :: "\xef\x82\xab";
ICON_FA_GLOBE :: "\xef\x82\xac";
ICON_FA_WRENCH :: "\xef\x82\xad";
ICON_FA_TASKS :: "\xef\x82\xae";
ICON_FA_FILTER :: "\xef\x82\xb0";
ICON_FA_BRIEFCASE :: "\xef\x82\xb1";
ICON_FA_ARROWS_ALT :: "\xef\x82\xb2";
ICON_FA_USERS :: "\xef\x83\x80";
ICON_FA_LINK :: "\xef\x83\x81";
ICON_FA_CLOUD :: "\xef\x83\x82";
ICON_FA_FLASK :: "\xef\x83\x83";
ICON_FA_SCISSORS :: "\xef\x83\x84";
ICON_FA_FILES_O :: "\xef\x83\x85";
ICON_FA_PAPERCLIP :: "\xef\x83\x86";
ICON_FA_FLOPPY_O :: "\xef\x83\x87";
ICON_FA_SQUARE :: "\xef\x83\x88";
ICON_FA_BARS :: "\xef\x83\x89";
ICON_FA_LIST_UL :: "\xef\x83\x8a";
ICON_FA_LIST_OL :: "\xef\x83\x8b";
ICON_FA_STRIKETHROUGH :: "\xef\x83\x8c";
ICON_FA_UNDERLINE :: "\xef\x83\x8d";
ICON_FA_TABLE :: "\xef\x83\x8e";
ICON_FA_MAGIC :: "\xef\x83\x90";
ICON_FA_TRUCK :: "\xef\x83\x91";
ICON_FA_PINTEREST :: "\xef\x83\x92";
ICON_FA_PINTEREST_SQUARE :: "\xef\x83\x93";
ICON_FA_GOOGLE_PLUS_SQUARE :: "\xef\x83\x94";
ICON_FA_GOOGLE_PLUS :: "\xef\x83\x95";
ICON_FA_MONEY :: "\xef\x83\x96";
ICON_FA_CARET_DOWN :: "\xef\x83\x97";
ICON_FA_CARET_UP :: "\xef\x83\x98";
ICON_FA_CARET_LEFT :: "\xef\x83\x99";
ICON_FA_CARET_RIGHT :: "\xef\x83\x9a";
ICON_FA_COLUMNS :: "\xef\x83\x9b";
ICON_FA_SORT :: "\xef\x83\x9c";
ICON_FA_SORT_DESC :: "\xef\x83\x9d";
ICON_FA_SORT_ASC :: "\xef\x83\x9e";
ICON_FA_ENVELOPE :: "\xef\x83\xa0";
ICON_FA_LINKEDIN :: "\xef\x83\xa1";
ICON_FA_UNDO :: "\xef\x83\xa2";
ICON_FA_GAVEL :: "\xef\x83\xa3";
ICON_FA_TACHOMETER :: "\xef\x83\xa4";
ICON_FA_COMMENT_O :: "\xef\x83\xa5";
ICON_FA_COMMENTS_O :: "\xef\x83\xa6";
ICON_FA_BOLT :: "\xef\x83\xa7";
ICON_FA_SITEMAP :: "\xef\x83\xa8";
ICON_FA_UMBRELLA :: "\xef\x83\xa9";
ICON_FA_CLIPBOARD :: "\xef\x83\xaa";
ICON_FA_LIGHTBULB_O :: "\xef\x83\xab";
ICON_FA_EXCHANGE :: "\xef\x83\xac";
ICON_FA_CLOUD_DOWNLOAD :: "\xef\x83\xad";
ICON_FA_CLOUD_UPLOAD :: "\xef\x83\xae";
ICON_FA_USER_MD :: "\xef\x83\xb0";
ICON_FA_STETHOSCOPE :: "\xef\x83\xb1";
ICON_FA_SUITCASE :: "\xef\x83\xb2";
ICON_FA_BELL_O :: "\xef\x82\xa2";
ICON_FA_COFFEE :: "\xef\x83\xb4";
ICON_FA_CUTLERY :: "\xef\x83\xb5";
ICON_FA_FILE_TEXT_O :: "\xef\x83\xb6";
ICON_FA_BUILDING_O :: "\xef\x83\xb7";
ICON_FA_HOSPITAL_O :: "\xef\x83\xb8";
ICON_FA_AMBULANCE :: "\xef\x83\xb9";
ICON_FA_MEDKIT :: "\xef\x83\xba";
ICON_FA_FIGHTER_JET :: "\xef\x83\xbb";
ICON_FA_BEER :: "\xef\x83\xbc";
ICON_FA_H_SQUARE :: "\xef\x83\xbd";
ICON_FA_PLUS_SQUARE :: "\xef\x83\xbe";
ICON_FA_ANGLE_DOUBLE_LEFT :: "\xef\x84\x80";
ICON_FA_ANGLE_DOUBLE_RIGHT :: "\xef\x84\x81";
ICON_FA_ANGLE_DOUBLE_UP :: "\xef\x84\x82";
ICON_FA_ANGLE_DOUBLE_DOWN :: "\xef\x84\x83";
ICON_FA_ANGLE_LEFT :: "\xef\x84\x84";
ICON_FA_ANGLE_RIGHT :: "\xef\x84\x85";
ICON_FA_ANGLE_UP :: "\xef\x84\x86";
ICON_FA_ANGLE_DOWN :: "\xef\x84\x87";
ICON_FA_DESKTOP :: "\xef\x84\x88";
ICON_FA_LAPTOP :: "\xef\x84\x89";
ICON_FA_TABLET :: "\xef\x84\x8a";
ICON_FA_MOBILE :: "\xef\x84\x8b";
ICON_FA_CIRCLE_O :: "\xef\x84\x8c";
ICON_FA_QUOTE_LEFT :: "\xef\x84\x8d";
ICON_FA_QUOTE_RIGHT :: "\xef\x84\x8e";
ICON_FA_SPINNER :: "\xef\x84\x90";
ICON_FA_CIRCLE :: "\xef\x84\x91";
ICON_FA_REPLY :: "\xef\x84\x92";
ICON_FA_GITHUB_ALT :: "\xef\x84\x93";
ICON_FA_FOLDER_O :: "\xef\x84\x94";
ICON_FA_FOLDER_OPEN_O :: "\xef\x84\x95";
ICON_FA_SMILE_O :: "\xef\x84\x98";
ICON_FA_FROWN_O :: "\xef\x84\x99";
ICON_FA_MEH_O :: "\xef\x84\x9a";
ICON_FA_GAMEPAD :: "\xef\x84\x9b";
ICON_FA_KEYBOARD_O :: "\xef\x84\x9c";
ICON_FA_FLAG_O :: "\xef\x84\x9d";
ICON_FA_FLAG_CHECKERED :: "\xef\x84\x9e";
ICON_FA_TERMINAL :: "\xef\x84\xa0";
ICON_FA_CODE :: "\xef\x84\xa1";
ICON_FA_REPLY_ALL :: "\xef\x84\xa2";
ICON_FA_STAR_HALF_O :: "\xef\x84\xa3";
ICON_FA_LOCATION_ARROW :: "\xef\x84\xa4";
ICON_FA_CROP :: "\xef\x84\xa5";
ICON_FA_CODE_FORK :: "\xef\x84\xa6";
ICON_FA_CHAIN_BROKEN :: "\xef\x84\xa7";
ICON_FA_QUESTION :: "\xef\x84\xa8";
ICON_FA_INFO :: "\xef\x84\xa9";
ICON_FA_EXCLAMATION :: "\xef\x84\xaa";
ICON_FA_SUPERSCRIPT :: "\xef\x84\xab";
ICON_FA_SUBSCRIPT :: "\xef\x84\xac";
ICON_FA_ERASER :: "\xef\x84\xad";
ICON_FA_PUZZLE_PIECE :: "\xef\x84\xae";
ICON_FA_MICROPHONE :: "\xef\x84\xb0";
ICON_FA_MICROPHONE_SLASH :: "\xef\x84\xb1";
ICON_FA_SHIELD :: "\xef\x84\xb2";
ICON_FA_CALENDAR_O :: "\xef\x84\xb3";
ICON_FA_FIRE_EXTINGUISHER :: "\xef\x84\xb4";
ICON_FA_ROCKET :: "\xef\x84\xb5";
ICON_FA_MAXCDN :: "\xef\x84\xb6";
ICON_FA_CHEVRON_CIRCLE_LEFT :: "\xef\x84\xb7";
ICON_FA_CHEVRON_CIRCLE_RIGHT :: "\xef\x84\xb8";
ICON_FA_CHEVRON_CIRCLE_UP :: "\xef\x84\xb9";
ICON_FA_CHEVRON_CIRCLE_DOWN :: "\xef\x84\xba";
ICON_FA_HTML5 :: "\xef\x84\xbb";
ICON_FA_CSS3 :: "\xef\x84\xbc";
ICON_FA_ANCHOR :: "\xef\x84\xbd";
ICON_FA_UNLOCK_ALT :: "\xef\x84\xbe";
ICON_FA_BULLSEYE :: "\xef\x85\x80";
ICON_FA_ELLIPSIS_H :: "\xef\x85\x81";
ICON_FA_ELLIPSIS_V :: "\xef\x85\x82";
ICON_FA_RSS_SQUARE :: "\xef\x85\x83";
ICON_FA_PLAY_CIRCLE :: "\xef\x85\x84";
ICON_FA_TICKET :: "\xef\x85\x85";
ICON_FA_MINUS_SQUARE :: "\xef\x85\x86";
ICON_FA_MINUS_SQUARE_O :: "\xef\x85\x87";
ICON_FA_LEVEL_UP :: "\xef\x85\x88";
ICON_FA_LEVEL_DOWN :: "\xef\x85\x89";
ICON_FA_CHECK_SQUARE :: "\xef\x85\x8a";
ICON_FA_PENCIL_SQUARE :: "\xef\x85\x8b";
ICON_FA_EXTERNAL_LINK_SQUARE :: "\xef\x85\x8c";
ICON_FA_SHARE_SQUARE :: "\xef\x85\x8d";
ICON_FA_COMPASS :: "\xef\x85\x8e";
ICON_FA_CARET_SQUARE_O_DOWN :: "\xef\x85\x90";
ICON_FA_CARET_SQUARE_O_UP :: "\xef\x85\x91";
ICON_FA_CARET_SQUARE_O_RIGHT :: "\xef\x85\x92";
ICON_FA_EUR :: "\xef\x85\x93";
ICON_FA_GBP :: "\xef\x85\x94";
ICON_FA_USD :: "\xef\x85\x95";
ICON_FA_INR :: "\xef\x85\x96";
ICON_FA_JPY :: "\xef\x85\x97";
ICON_FA_RUB :: "\xef\x85\x98";
ICON_FA_KRW :: "\xef\x85\x99";
ICON_FA_BTC :: "\xef\x85\x9a";
ICON_FA_FILE :: "\xef\x85\x9b";
ICON_FA_FILE_TEXT :: "\xef\x85\x9c";
ICON_FA_SORT_ALPHA_ASC :: "\xef\x85\x9d";
ICON_FA_SORT_ALPHA_DESC :: "\xef\x85\x9e";
ICON_FA_SORT_AMOUNT_ASC :: "\xef\x85\xa0";
ICON_FA_SORT_AMOUNT_DESC :: "\xef\x85\xa1";
ICON_FA_SORT_NUMERIC_ASC :: "\xef\x85\xa2";
ICON_FA_SORT_NUMERIC_DESC :: "\xef\x85\xa3";
ICON_FA_THUMBS_UP :: "\xef\x85\xa4";
ICON_FA_THUMBS_DOWN :: "\xef\x85\xa5";
ICON_FA_YOUTUBE_SQUARE :: "\xef\x85\xa6";
ICON_FA_YOUTUBE :: "\xef\x85\xa7";
ICON_FA_XING :: "\xef\x85\xa8";
ICON_FA_XING_SQUARE :: "\xef\x85\xa9";
ICON_FA_YOUTUBE_PLAY :: "\xef\x85\xaa";
ICON_FA_DROPBOX :: "\xef\x85\xab";
ICON_FA_STACK_OVERFLOW :: "\xef\x85\xac";
ICON_FA_INSTAGRAM :: "\xef\x85\xad";
ICON_FA_FLICKR :: "\xef\x85\xae";
ICON_FA_ADN :: "\xef\x85\xb0";
ICON_FA_BITBUCKET :: "\xef\x85\xb1";
ICON_FA_BITBUCKET_SQUARE :: "\xef\x85\xb2";
ICON_FA_TUMBLR :: "\xef\x85\xb3";
ICON_FA_TUMBLR_SQUARE :: "\xef\x85\xb4";
ICON_FA_LONG_ARROW_DOWN :: "\xef\x85\xb5";
ICON_FA_LONG_ARROW_UP :: "\xef\x85\xb6";
ICON_FA_LONG_ARROW_LEFT :: "\xef\x85\xb7";
ICON_FA_LONG_ARROW_RIGHT :: "\xef\x85\xb8";
ICON_FA_APPLE :: "\xef\x85\xb9";
ICON_FA_WINDOWS :: "\xef\x85\xba";
ICON_FA_ANDROID :: "\xef\x85\xbb";
ICON_FA_LINUX :: "\xef\x85\xbc";
ICON_FA_DRIBBBLE :: "\xef\x85\xbd";
ICON_FA_SKYPE :: "\xef\x85\xbe";
ICON_FA_FOURSQUARE :: "\xef\x86\x80";
ICON_FA_TRELLO :: "\xef\x86\x81";
ICON_FA_FEMALE :: "\xef\x86\x82";
ICON_FA_MALE :: "\xef\x86\x83";
ICON_FA_GRATIPAY :: "\xef\x86\x84";
ICON_FA_SUN_O :: "\xef\x86\x85";
ICON_FA_MOON_O :: "\xef\x86\x86";
ICON_FA_ARCHIVE :: "\xef\x86\x87";
ICON_FA_BUG :: "\xef\x86\x88";
ICON_FA_VK :: "\xef\x86\x89";
ICON_FA_WEIBO :: "\xef\x86\x8a";
ICON_FA_RENREN :: "\xef\x86\x8b";
ICON_FA_PAGELINES :: "\xef\x86\x8c";
ICON_FA_STACK_EXCHANGE :: "\xef\x86\x8d";
ICON_FA_ARROW_CIRCLE_O_RIGHT :: "\xef\x86\x8e";
ICON_FA_ARROW_CIRCLE_O_LEFT :: "\xef\x86\x90";
ICON_FA_CARET_SQUARE_O_LEFT :: "\xef\x86\x91";
ICON_FA_DOT_CIRCLE_O :: "\xef\x86\x92";
ICON_FA_WHEELCHAIR :: "\xef\x86\x93";
ICON_FA_VIMEO_SQUARE :: "\xef\x86\x94";
ICON_FA_TRY :: "\xef\x86\x95";
ICON_FA_PLUS_SQUARE_O :: "\xef\x86\x96";
ICON_FA_SPACE_SHUTTLE :: "\xef\x86\x97";
ICON_FA_SLACK :: "\xef\x86\x98";
ICON_FA_ENVELOPE_SQUARE :: "\xef\x86\x99";
ICON_FA_WORDPRESS :: "\xef\x86\x9a";
ICON_FA_OPENID :: "\xef\x86\x9b";
ICON_FA_UNIVERSITY :: "\xef\x86\x9c";
ICON_FA_GRADUATION_CAP :: "\xef\x86\x9d";
ICON_FA_YAHOO :: "\xef\x86\x9e";
ICON_FA_GOOGLE :: "\xef\x86\xa0";
ICON_FA_REDDIT :: "\xef\x86\xa1";
ICON_FA_REDDIT_SQUARE :: "\xef\x86\xa2";
ICON_FA_STUMBLEUPON_CIRCLE :: "\xef\x86\xa3";
ICON_FA_STUMBLEUPON :: "\xef\x86\xa4";
ICON_FA_DELICIOUS :: "\xef\x86\xa5";
ICON_FA_DIGG :: "\xef\x86\xa6";
ICON_FA_PIED_PIPER_PP :: "\xef\x86\xa7";
ICON_FA_PIED_PIPER_ALT :: "\xef\x86\xa8";
ICON_FA_DRUPAL :: "\xef\x86\xa9";
ICON_FA_JOOMLA :: "\xef\x86\xaa";
ICON_FA_LANGUAGE :: "\xef\x86\xab";
ICON_FA_FAX :: "\xef\x86\xac";
ICON_FA_BUILDING :: "\xef\x86\xad";
ICON_FA_CHILD :: "\xef\x86\xae";
ICON_FA_PAW :: "\xef\x86\xb0";
ICON_FA_SPOON :: "\xef\x86\xb1";
ICON_FA_CUBE :: "\xef\x86\xb2";
ICON_FA_CUBES :: "\xef\x86\xb3";
ICON_FA_BEHANCE :: "\xef\x86\xb4";
ICON_FA_BEHANCE_SQUARE :: "\xef\x86\xb5";
ICON_FA_STEAM :: "\xef\x86\xb6";
ICON_FA_STEAM_SQUARE :: "\xef\x86\xb7";
ICON_FA_RECYCLE :: "\xef\x86\xb8";
ICON_FA_CAR :: "\xef\x86\xb9";
ICON_FA_TAXI :: "\xef\x86\xba";
ICON_FA_TREE :: "\xef\x86\xbb";
ICON_FA_SPOTIFY :: "\xef\x86\xbc";
ICON_FA_DEVIANTART :: "\xef\x86\xbd";
ICON_FA_SOUNDCLOUD :: "\xef\x86\xbe";
ICON_FA_DATABASE :: "\xef\x87\x80";
ICON_FA_FILE_PDF_O :: "\xef\x87\x81";
ICON_FA_FILE_WORD_O :: "\xef\x87\x82";
ICON_FA_FILE_EXCEL_O :: "\xef\x87\x83";
ICON_FA_FILE_POWERPOINT_O :: "\xef\x87\x84";
ICON_FA_FILE_IMAGE_O :: "\xef\x87\x85";
ICON_FA_FILE_ARCHIVE_O :: "\xef\x87\x86";
ICON_FA_FILE_AUDIO_O :: "\xef\x87\x87";
ICON_FA_FILE_VIDEO_O :: "\xef\x87\x88";
ICON_FA_FILE_CODE_O :: "\xef\x87\x89";
ICON_FA_VINE :: "\xef\x87\x8a";
ICON_FA_CODEPEN :: "\xef\x87\x8b";
ICON_FA_JSFIDDLE :: "\xef\x87\x8c";
ICON_FA_LIFE_RING :: "\xef\x87\x8d";
ICON_FA_CIRCLE_O_NOTCH :: "\xef\x87\x8e";
ICON_FA_REBEL :: "\xef\x87\x90";
ICON_FA_EMPIRE :: "\xef\x87\x91";
ICON_FA_GIT_SQUARE :: "\xef\x87\x92";
ICON_FA_GIT :: "\xef\x87\x93";
ICON_FA_HACKER_NEWS :: "\xef\x87\x94";
ICON_FA_TENCENT_WEIBO :: "\xef\x87\x95";
ICON_FA_QQ :: "\xef\x87\x96";
ICON_FA_WEIXIN :: "\xef\x87\x97";
ICON_FA_PAPER_PLANE :: "\xef\x87\x98";
ICON_FA_PAPER_PLANE_O :: "\xef\x87\x99";
ICON_FA_HISTORY :: "\xef\x87\x9a";
ICON_FA_CIRCLE_THIN :: "\xef\x87\x9b";
ICON_FA_HEADER :: "\xef\x87\x9c";
ICON_FA_PARAGRAPH :: "\xef\x87\x9d";
ICON_FA_SLIDERS :: "\xef\x87\x9e";
ICON_FA_SHARE_ALT :: "\xef\x87\xa0";
ICON_FA_SHARE_ALT_SQUARE :: "\xef\x87\xa1";
ICON_FA_BOMB :: "\xef\x87\xa2";
ICON_FA_FUTBOL_O :: "\xef\x87\xa3";
ICON_FA_TTY :: "\xef\x87\xa4";
ICON_FA_BINOCULARS :: "\xef\x87\xa5";
ICON_FA_PLUG :: "\xef\x87\xa6";
ICON_FA_SLIDESHARE :: "\xef\x87\xa7";
ICON_FA_TWITCH :: "\xef\x87\xa8";
ICON_FA_YELP :: "\xef\x87\xa9";
ICON_FA_NEWSPAPER_O :: "\xef\x87\xaa";
ICON_FA_WIFI :: "\xef\x87\xab";
ICON_FA_CALCULATOR :: "\xef\x87\xac";
ICON_FA_PAYPAL :: "\xef\x87\xad";
ICON_FA_GOOGLE_WALLET :: "\xef\x87\xae";
ICON_FA_CC_VISA :: "\xef\x87\xb0";
ICON_FA_CC_MASTERCARD :: "\xef\x87\xb1";
ICON_FA_CC_DISCOVER :: "\xef\x87\xb2";
ICON_FA_CC_AMEX :: "\xef\x87\xb3";
ICON_FA_CC_PAYPAL :: "\xef\x87\xb4";
ICON_FA_CC_STRIPE :: "\xef\x87\xb5";
ICON_FA_BELL_SLASH :: "\xef\x87\xb6";
ICON_FA_BELL_SLASH_O :: "\xef\x87\xb7";
ICON_FA_TRASH :: "\xef\x87\xb8";
ICON_FA_COPYRIGHT :: "\xef\x87\xb9";
ICON_FA_AT :: "\xef\x87\xba";
ICON_FA_EYEDROPPER :: "\xef\x87\xbb";
ICON_FA_PAINT_BRUSH :: "\xef\x87\xbc";
ICON_FA_BIRTHDAY_CAKE :: "\xef\x87\xbd";
ICON_FA_AREA_CHART :: "\xef\x87\xbe";
ICON_FA_PIE_CHART :: "\xef\x88\x80";
ICON_FA_LINE_CHART :: "\xef\x88\x81";
ICON_FA_LASTFM :: "\xef\x88\x82";
ICON_FA_LASTFM_SQUARE :: "\xef\x88\x83";
ICON_FA_TOGGLE_OFF :: "\xef\x88\x84";
ICON_FA_TOGGLE_ON :: "\xef\x88\x85";
ICON_FA_BICYCLE :: "\xef\x88\x86";
ICON_FA_BUS :: "\xef\x88\x87";
ICON_FA_IOXHOST :: "\xef\x88\x88";
ICON_FA_ANGELLIST :: "\xef\x88\x89";
ICON_FA_CC :: "\xef\x88\x8a";
ICON_FA_ILS :: "\xef\x88\x8b";
ICON_FA_MEANPATH :: "\xef\x88\x8c";
ICON_FA_BUYSELLADS :: "\xef\x88\x8d";
ICON_FA_CONNECTDEVELOP :: "\xef\x88\x8e";
ICON_FA_DASHCUBE :: "\xef\x88\x90";
ICON_FA_FORUMBEE :: "\xef\x88\x91";
ICON_FA_LEANPUB :: "\xef\x88\x92";
ICON_FA_SELLSY :: "\xef\x88\x93";
ICON_FA_SHIRTSINBULK :: "\xef\x88\x94";
ICON_FA_SIMPLYBUILT :: "\xef\x88\x95";
ICON_FA_SKYATLAS :: "\xef\x88\x96";
ICON_FA_CART_PLUS :: "\xef\x88\x97";
ICON_FA_CART_ARROW_DOWN :: "\xef\x88\x98";
ICON_FA_DIAMOND :: "\xef\x88\x99";
ICON_FA_SHIP :: "\xef\x88\x9a";
ICON_FA_USER_SECRET :: "\xef\x88\x9b";
ICON_FA_MOTORCYCLE :: "\xef\x88\x9c";
ICON_FA_STREET_VIEW :: "\xef\x88\x9d";
ICON_FA_HEARTBEAT :: "\xef\x88\x9e";
ICON_FA_VENUS :: "\xef\x88\xa1";
ICON_FA_MARS :: "\xef\x88\xa2";
ICON_FA_MERCURY :: "\xef\x88\xa3";
ICON_FA_TRANSGENDER :: "\xef\x88\xa4";
ICON_FA_TRANSGENDER_ALT :: "\xef\x88\xa5";
ICON_FA_VENUS_DOUBLE :: "\xef\x88\xa6";
ICON_FA_MARS_DOUBLE :: "\xef\x88\xa7";
ICON_FA_VENUS_MARS :: "\xef\x88\xa8";
ICON_FA_MARS_STROKE :: "\xef\x88\xa9";
ICON_FA_MARS_STROKE_V :: "\xef\x88\xaa";
ICON_FA_MARS_STROKE_H :: "\xef\x88\xab";
ICON_FA_NEUTER :: "\xef\x88\xac";
ICON_FA_GENDERLESS :: "\xef\x88\xad";
ICON_FA_FACEBOOK_OFFICIAL :: "\xef\x88\xb0";
ICON_FA_PINTEREST_P :: "\xef\x88\xb1";
ICON_FA_WHATSAPP :: "\xef\x88\xb2";
ICON_FA_SERVER :: "\xef\x88\xb3";
ICON_FA_USER_PLUS :: "\xef\x88\xb4";
ICON_FA_USER_TIMES :: "\xef\x88\xb5";
ICON_FA_BED :: "\xef\x88\xb6";
ICON_FA_VIACOIN :: "\xef\x88\xb7";
ICON_FA_TRAIN :: "\xef\x88\xb8";
ICON_FA_SUBWAY :: "\xef\x88\xb9";
ICON_FA_MEDIUM :: "\xef\x88\xba";
ICON_FA_Y_COMBINATOR :: "\xef\x88\xbb";
ICON_FA_OPTIN_MONSTER :: "\xef\x88\xbc";
ICON_FA_OPENCART :: "\xef\x88\xbd";
ICON_FA_EXPEDITEDSSL :: "\xef\x88\xbe";
ICON_FA_BATTERY_FULL :: "\xef\x89\x80";
ICON_FA_BATTERY_THREE_QUARTERS :: "\xef\x89\x81";
ICON_FA_BATTERY_HALF :: "\xef\x89\x82";
ICON_FA_BATTERY_QUARTER :: "\xef\x89\x83";
ICON_FA_BATTERY_EMPTY :: "\xef\x89\x84";
ICON_FA_MOUSE_POINTER :: "\xef\x89\x85";
ICON_FA_I_CURSOR :: "\xef\x89\x86";
ICON_FA_OBJECT_GROUP :: "\xef\x89\x87";
ICON_FA_OBJECT_UNGROUP :: "\xef\x89\x88";
ICON_FA_STICKY_NOTE :: "\xef\x89\x89";
ICON_FA_STICKY_NOTE_O :: "\xef\x89\x8a";
ICON_FA_CC_JCB :: "\xef\x89\x8b";
ICON_FA_CC_DINERS_CLUB :: "\xef\x89\x8c";
ICON_FA_CLONE :: "\xef\x89\x8d";
ICON_FA_BALANCE_SCALE :: "\xef\x89\x8e";
ICON_FA_HOURGLASS_O :: "\xef\x89\x90";
ICON_FA_HOURGLASS_START :: "\xef\x89\x91";
ICON_FA_HOURGLASS_HALF :: "\xef\x89\x92";
ICON_FA_HOURGLASS_END :: "\xef\x89\x93";
ICON_FA_HOURGLASS :: "\xef\x89\x94";
ICON_FA_HAND_ROCK_O :: "\xef\x89\x95";
ICON_FA_HAND_PAPER_O :: "\xef\x89\x96";
ICON_FA_HAND_SCISSORS_O :: "\xef\x89\x97";
ICON_FA_HAND_LIZARD_O :: "\xef\x89\x98";
ICON_FA_HAND_SPOCK_O :: "\xef\x89\x99";
ICON_FA_HAND_POINTER_O :: "\xef\x89\x9a";
ICON_FA_HAND_PEACE_O :: "\xef\x89\x9b";
ICON_FA_TRADEMARK :: "\xef\x89\x9c";
ICON_FA_REGISTERED :: "\xef\x89\x9d";
ICON_FA_CREATIVE_COMMONS :: "\xef\x89\x9e";
ICON_FA_GG :: "\xef\x89\xa0";
ICON_FA_GG_CIRCLE :: "\xef\x89\xa1";
ICON_FA_TRIPADVISOR :: "\xef\x89\xa2";
ICON_FA_ODNOKLASSNIKI :: "\xef\x89\xa3";
ICON_FA_ODNOKLASSNIKI_SQUARE :: "\xef\x89\xa4";
ICON_FA_GET_POCKET :: "\xef\x89\xa5";
ICON_FA_WIKIPEDIA_W :: "\xef\x89\xa6";
ICON_FA_SAFARI :: "\xef\x89\xa7";
ICON_FA_CHROME :: "\xef\x89\xa8";
ICON_FA_FIREFOX :: "\xef\x89\xa9";
ICON_FA_OPERA :: "\xef\x89\xaa";
ICON_FA_INTERNET_EXPLORER :: "\xef\x89\xab";
ICON_FA_TELEVISION :: "\xef\x89\xac";
ICON_FA_CONTAO :: "\xef\x89\xad";
ICON_FA_500PX :: "\xef\x89\xae";
ICON_FA_AMAZON :: "\xef\x89\xb0";
ICON_FA_CALENDAR_PLUS_O :: "\xef\x89\xb1";
ICON_FA_CALENDAR_MINUS_O :: "\xef\x89\xb2";
ICON_FA_CALENDAR_TIMES_O :: "\xef\x89\xb3";
ICON_FA_CALENDAR_CHECK_O :: "\xef\x89\xb4";
ICON_FA_INDUSTRY :: "\xef\x89\xb5";
ICON_FA_MAP_PIN :: "\xef\x89\xb6";
ICON_FA_MAP_SIGNS :: "\xef\x89\xb7";
ICON_FA_MAP_O :: "\xef\x89\xb8";
ICON_FA_MAP :: "\xef\x89\xb9";
ICON_FA_COMMENTING :: "\xef\x89\xba";
ICON_FA_COMMENTING_O :: "\xef\x89\xbb";
ICON_FA_HOUZZ :: "\xef\x89\xbc";
ICON_FA_VIMEO :: "\xef\x89\xbd";
ICON_FA_BLACK_TIE :: "\xef\x89\xbe";
ICON_FA_FONTICONS :: "\xef\x8a\x80";
ICON_FA_REDDIT_ALIEN :: "\xef\x8a\x81";
ICON_FA_EDGE :: "\xef\x8a\x82";
ICON_FA_CREDIT_CARD_ALT :: "\xef\x8a\x83";
ICON_FA_CODIEPIE :: "\xef\x8a\x84";
ICON_FA_MODX :: "\xef\x8a\x85";
ICON_FA_FORT_AWESOME :: "\xef\x8a\x86";
ICON_FA_USB :: "\xef\x8a\x87";
ICON_FA_PRODUCT_HUNT :: "\xef\x8a\x88";
ICON_FA_MIXCLOUD :: "\xef\x8a\x89";
ICON_FA_SCRIBD :: "\xef\x8a\x8a";
ICON_FA_PAUSE_CIRCLE :: "\xef\x8a\x8b";
ICON_FA_PAUSE_CIRCLE_O :: "\xef\x8a\x8c";
ICON_FA_STOP_CIRCLE :: "\xef\x8a\x8d";
ICON_FA_STOP_CIRCLE_O :: "\xef\x8a\x8e";
ICON_FA_SHOPPING_BAG :: "\xef\x8a\x90";
ICON_FA_SHOPPING_BASKET :: "\xef\x8a\x91";
ICON_FA_HASHTAG :: "\xef\x8a\x92";
ICON_FA_BLUETOOTH :: "\xef\x8a\x93";
ICON_FA_BLUETOOTH_B :: "\xef\x8a\x94";
ICON_FA_PERCENT :: "\xef\x8a\x95";
ICON_FA_GITLAB :: "\xef\x8a\x96";
ICON_FA_WPBEGINNER :: "\xef\x8a\x97";
ICON_FA_WPFORMS :: "\xef\x8a\x98";
ICON_FA_ENVIRA :: "\xef\x8a\x99";
ICON_FA_UNIVERSAL_ACCESS :: "\xef\x8a\x9a";
ICON_FA_WHEELCHAIR_ALT :: "\xef\x8a\x9b";
ICON_FA_QUESTION_CIRCLE_O :: "\xef\x8a\x9c";
ICON_FA_BLIND :: "\xef\x8a\x9d";
ICON_FA_AUDIO_DESCRIPTION :: "\xef\x8a\x9e";
ICON_FA_VOLUME_CONTROL_PHONE :: "\xef\x8a\xa0";
ICON_FA_BRAILLE :: "\xef\x8a\xa1";
ICON_FA_ASSISTIVE_LISTENING_SYSTEMS :: "\xef\x8a\xa2";
ICON_FA_AMERICAN_SIGN_LANGUAGE_INTERPRETING :: "\xef\x8a\xa3";
ICON_FA_DEAF :: "\xef\x8a\xa4";
ICON_FA_GLIDE :: "\xef\x8a\xa5";
ICON_FA_GLIDE_G :: "\xef\x8a\xa6";
ICON_FA_SIGN_LANGUAGE :: "\xef\x8a\xa7";
ICON_FA_LOW_VISION :: "\xef\x8a\xa8";
ICON_FA_VIADEO :: "\xef\x8a\xa9";
ICON_FA_VIADEO_SQUARE :: "\xef\x8a\xaa";
ICON_FA_SNAPCHAT :: "\xef\x8a\xab";
ICON_FA_SNAPCHAT_GHOST :: "\xef\x8a\xac";
ICON_FA_SNAPCHAT_SQUARE :: "\xef\x8a\xad";
ICON_FA_PIED_PIPER :: "\xef\x8a\xae";
ICON_FA_FIRST_ORDER :: "\xef\x8a\xb0";
ICON_FA_YOAST :: "\xef\x8a\xb1";
ICON_FA_THEMEISLE :: "\xef\x8a\xb2";
ICON_FA_GOOGLE_PLUS_OFFICIAL :: "\xef\x8a\xb3";
ICON_FA_FONT_AWESOME :: "\xef\x8a\xb4";
ICON_FA_HANDSHAKE_O :: "\xef\x8a\xb5";
ICON_FA_ENVELOPE_OPEN :: "\xef\x8a\xb6";
ICON_FA_ENVELOPE_OPEN_O :: "\xef\x8a\xb7";
ICON_FA_LINODE :: "\xef\x8a\xb8";
ICON_FA_ADDRESS_BOOK :: "\xef\x8a\xb9";
ICON_FA_ADDRESS_BOOK_O :: "\xef\x8a\xba";
ICON_FA_ADDRESS_CARD :: "\xef\x8a\xbb";
ICON_FA_ADDRESS_CARD_O :: "\xef\x8a\xbc";
ICON_FA_USER_CIRCLE :: "\xef\x8a\xbd";
ICON_FA_USER_CIRCLE_O :: "\xef\x8a\xbe";
ICON_FA_USER_O :: "\xef\x8b\x80";
ICON_FA_ID_BADGE :: "\xef\x8b\x81";
ICON_FA_ID_CARD :: "\xef\x8b\x82";
ICON_FA_ID_CARD_O :: "\xef\x8b\x83";
ICON_FA_QUORA :: "\xef\x8b\x84";
ICON_FA_FREE_CODE_CAMP :: "\xef\x8b\x85";
ICON_FA_TELEGRAM :: "\xef\x8b\x86";
ICON_FA_THERMOMETER_FULL :: "\xef\x8b\x87";
ICON_FA_THERMOMETER_THREE_QUARTERS :: "\xef\x8b\x88";
ICON_FA_THERMOMETER_HALF :: "\xef\x8b\x89";
ICON_FA_THERMOMETER_QUARTER :: "\xef\x8b\x8a";
ICON_FA_THERMOMETER_EMPTY :: "\xef\x8b\x8b";
ICON_FA_SHOWER :: "\xef\x8b\x8c";
ICON_FA_BATH :: "\xef\x8b\x8d";
ICON_FA_PODCAST :: "\xef\x8b\x8e";
ICON_FA_WINDOW_MAXIMIZE :: "\xef\x8b\x90";
ICON_FA_WINDOW_MINIMIZE :: "\xef\x8b\x91";
ICON_FA_WINDOW_RESTORE :: "\xef\x8b\x92";
ICON_FA_WINDOW_CLOSE :: "\xef\x8b\x93";
ICON_FA_WINDOW_CLOSE_O :: "\xef\x8b\x94";
ICON_FA_BANDCAMP :: "\xef\x8b\x95";
ICON_FA_GRAV :: "\xef\x8b\x96";
ICON_FA_ETSY :: "\xef\x8b\x97";
ICON_FA_IMDB :: "\xef\x8b\x98";
ICON_FA_RAVELRY :: "\xef\x8b\x99";
ICON_FA_EERCAST :: "\xef\x8b\x9a";
ICON_FA_MICROCHIP :: "\xef\x8b\x9b";
ICON_FA_SNOWFLAKE_O :: "\xef\x8b\x9c";
ICON_FA_SUPERPOWERS :: "\xef\x8b\x9d";
ICON_FA_WPEXPLORER :: "\xef\x8b\x9e";
ICON_FA_MEETUP :: "\xef\x8b\xa0";
