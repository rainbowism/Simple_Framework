Module_Flags :: enum_flags {
    Render;
    Audio;
    ImGui;

    All :: Module_Flags.Render | .Audio | .ImGui;
}

Window_Flags :: enum_flags {
    None;
    Maximized;
    Resizable;
    Fullscreen;
    Centered;
    VSync;
    MSAA;
}

sf_init :: () -> SF_Result {
    glfwSetErrorCallback(glfw_error_callback);
    if !glfwInit()  return .Failed_To_Init_GLFW;
    // #if OS == .WINDOWS {
    //     Win32 :: #import "Windows";
    //     Win32.SetProcessDPIAware();
    //     Win32.timeBeginPeriod(1);
    // }
    window.ctx = context;
    initialized = true;
    return .Ok;
}

create_window :: (title: string, width: s32, height: s32, flags := Window_Flags.None, modules_to_init: Module_Flags) -> SF_Result {
    glfwDefaultWindowHints();
    #if Render_Backend == .GLCore33 {
        glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
        glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
        glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
        glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GLFW_TRUE);
    } else {
        glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    }
    glfwWindowHint(GLFW_VISIBLE,   0);
    glfwWindowHint(GLFW_RESIZABLE, xx (ifx flags & .Resizable));
    if flags & .MSAA glfwWindowHint(GLFW_SAMPLES, 4);

    window.size.x = xx width;
    window.size.y = xx height;
    window.size_i.x = width;
    window.size_i.y = height;
    window.name = title;

    // @Todo(sushi): do settings file stuff so i can get fullscreen mode
    window.handle = glfwCreateWindow(width, height, temp_c_string(title), null, null);
    if window.handle == null {
        return .Failed_To_Create_Window;
    }
    #if Render_Backend == .GLCore33 {
        glfwMakeContextCurrent(window.handle);
    } else #if Render_Backend == .D3D11 {
        init_d3d11_device(width, height, flags & .MSAA != 0);
    }
    #if !Disable_Render { if modules_to_init & .Render  render_init(flags & .MSAA != 0); }
    #if !Disable_Audio  { if modules_to_init & .Audio   audio_init();  }
    #if !Disable_ImGui  { if modules_to_init & .ImGui   imgui_init();  }

    if flags & .Fullscreen {
        set_fullscreen(true);
    } else {
        if flags & .Centered {
            center_window();
        }
        if flags & .Maximized {
            glfwMaximizeWindow(window.handle);
        }
    }

    glfwSetInputMode(window.handle, GLFW_STICKY_MOUSE_BUTTONS, GLFW_TRUE);
    glfwSetInputMode(window.handle, GLFW_STICKY_KEYS, GLFW_TRUE);
    glfwSetCursorPosCallback  (window.handle, glfw_cursor_position_callback);
    glfwSetWindowSizeCallback (window.handle, glfw_window_size_callback);
    glfwSetWindowFocusCallback(window.handle, glfw_window_focus_callback);
    glfwSetKeyCallback        (window.handle, glfw_key_callback);
    glfwSetMouseButtonCallback(window.handle, glfw_mouse_callback);
    glfwSetCharCallback       (window.handle, glfw_text_callback);
    glfwSetScrollCallback     (window.handle, glfw_scroll_callback);
    glfwSetDropCallback       (window.handle, glfw_drop_callback);

    create_cursors(window.handle);

    set_vsync(flags & .VSync > 0);

    glfwShowWindow(window.handle);
    init_time();

    update_viewport(width, height);

    sf_time.last = get_time();

    profiler_init(*_cpu_profiler);
    profiler_init(*_gpu_profiler);
    return .Ok;
}

destroy_window :: () {
    profiler_deinit(*_cpu_profiler);
    profiler_deinit(*_gpu_profiler);
    #if !Disable_ImGui  { imgui_deinit();  }
    #if !Disable_Audio  { audio_deinit();  }
    #if !Disable_Render { render_deinit(); }
    glfwDestroyWindow(window.handle);
    glfwTerminate();
}

sf_exit :: inline () {
    glfwSetWindowShouldClose(window.handle, GLFW_TRUE);
}

should_exit :: () -> bool {
    reset_temporary_storage();

    gpu_end_frame();

    #if !Manually_Swap_Buffer {
        {
            // gpu_scoped_task("Present", Colors8.Red);
            if get_window_minimized() {
                glfwWaitEventsTimeout(Max_Delta_Time * 0.5);
            } else {
                #if Render_Backend == .GLCore33 {
                    glfwSwapBuffers(window.handle);
                } else #if Render_Backend == .D3D11 {
                    d3d11_present(xx,no_check window.time.vsync);
                }
            }
        }
    }
    glfwPollEvents();

    exit := glfwWindowShouldClose(window.handle) == GLFW_TRUE;

    {
        new_time := get_time();
        sf_time.delta64 = new_time - sf_time.last;
        #if Max_Delta_Time < FLOAT64_MAX {
            if sf_time.delta64 > Max_Delta_Time  sf_time.delta64 = Max_Delta_Time;
        }

        if !window.time.vsync && window.time.target_fps > 0 && sf_time.delta64 > 0 {
            // gpu_scoped_task("WaitForFence", Colors8.Light_Salmon);

            remaining_time := window.time.target_fps_inv - sf_time.delta64;
            if remaining_time > 0 {
                usleep(cast(s64) (1_000_000.0 * remaining_time), new_time + remaining_time);
                sf_time.delta64 = get_time() - sf_time.last;
                sf_time.last = get_time();
            } else {
                sf_time.last = new_time;
            }
        } else {
            sf_time.last = new_time;
        }

        sf_time.delta = cast(float) sf_time.delta64;
        sf_time.total += sf_time.delta64;

        using window.time;
        if (new_time - fps_last) > TRACK_FPS_STEP {
            fps_last = new_time;
            fps_average -= fps_buffer[fps_index];
            fps_buffer[fps_index] = sf_time.delta64 * (1.0 / TRACK_FPS_SAMPLES);
            fps_average += fps_buffer[fps_index];
            fps_index = (fps_index + 1) % TRACK_FPS_SAMPLES;
        }
    }

    return exit;
}

swap_buffers :: () #expand {
    glfwSwapBuffers(window.handle);
}

center_window :: () {
    window_pos: Point2 = ---;
    glfwGetWindowPos(window.handle, *window_pos.x, *window_pos.y);
    window_pos.x += window.size_i.x / 2;
    window_pos.y += window.size_i.y / 2;
    monitor_count: s32;
    monitors := glfwGetMonitors(*monitor_count);
    monitor_rect: Recti = ---;
    for 0..monitor_count-1 {
        video_mode := glfwGetVideoMode(monitors[it]);
        if !video_mode  continue;

        glfwGetMonitorPos(monitors[it], *monitor_rect.x, *monitor_rect.y);
        monitor_rect.width = video_mode.width;
        monitor_rect.height = video_mode.height;

        if !intersect(window_pos, monitor_rect)  continue;
        glfwSetWindowPos(
            window.handle,
            monitor_rect.x + ((monitor_rect.width  - window.size_i.x) / 2),
            monitor_rect.y + ((monitor_rect.height - window.size_i.y) / 2)
        );
        return;
    }
}

get_window_size :: inline () -> Vector2 {
    return window.size;
}

get_window_size_i :: inline () -> Point2 {
    return window.size_i;
}

get_vsync :: () -> bool {
    return window.time.vsync;
}

set_vsync :: (enable: bool) {
    window.time.vsync = enable;
    #if Render_Backend == .GLCore33 {
        if enable {
            glfwSwapInterval(1);
        } else {
            glfwSwapInterval(0);
        }
    }
}

get_target_fps :: () -> float {
    return window.time.target_fps;
}

set_target_fps :: (value: float) {
    window.time.target_fps     = value;
    window.time.target_fps_inv = 1.0 / xx value;
}

get_window_mode :: () -> Window_Flags {
    if get_fullscreen()  return .Fullscreen;
    return .None;
}

get_fullscreen :: () -> bool {
    return glfwGetWindowMonitor(window.handle) != null;
}

set_fullscreen :: (value: bool) {
    monitor   := glfwGetPrimaryMonitor();
    if !monitor  return;
    mode      := glfwGetVideoMode(monitor);
    if !mode     return;

    glfwWindowHint(GLFW_RED_BITS,     mode.redBits);
    glfwWindowHint(GLFW_GREEN_BITS,   mode.greenBits);
    glfwWindowHint(GLFW_BLUE_BITS,    mode.blueBits);
    glfwWindowHint(GLFW_REFRESH_RATE, mode.refreshRate);

    glfwSetWindowMonitor(window.handle, monitor, 0, 0, mode.width, mode.height, mode.refreshRate);
}

get_cull_face :: () -> bool {
    enabled: GLboolean;
    glGetBooleanv(GL_CULL_FACE, *enabled);
    return enabled;
}

set_cull_face :: (enable: bool) {
    if enable {
        glEnable(GL_CULL_FACE);
    } else {
        glDisable(GL_CULL_FACE);
    }
}

get_front_face_ccw :: () -> bool {
    front_face: GLint;
    glGetIntegerv(GL_FRONT_FACE, *front_face);
    return front_face == GL_CCW;
}

set_front_face_ccw :: (enable: bool) {
    if enable {
        glFrontFace(GL_CCW);
    } else {
        glFrontFace(GL_CW);
    }
}

get_depth_test :: () -> bool {
    enabled: GLboolean;
    glGetBooleanv(GL_DEPTH_TEST, *enabled);
    return enabled;
}

set_depth_test :: (enable: bool) {
    if enable {
        glEnable(GL_DEPTH_TEST);
    } else {
        glDisable(GL_DEPTH_TEST);
    }
}

get_window_focused :: inline () -> bool {
    return window.focused;
}

set_window_focused :: ($clear_input := false) {
    glfwFocusWindow(window.handle);
    #if clear_input  clear_input_buffers();
}

get_window_minimized :: inline () -> bool {
    return xx glfwGetWindowAttrib(window.handle, GLFW_ICONIFIED);
}

get_window_resolutions :: () -> [] Point2 {
    monitor := glfwGetPrimaryMonitor();
    video_modes: [] GLFWvidmode;
    video_modes.data = glfwGetVideoModes(monitor, xx *video_modes.count);
    resolutions: [..] Point2;
    for video_mode: video_modes {
        if video_mode.width < video_mode.height / 10 * 16  continue video_mode;
        for res: resolutions {
            if res.x == video_mode.width && res.y == video_mode.height  continue video_mode;
        }
        array_add(*resolutions, .{video_mode.width, video_mode.height});
    }
    return resolutions;
}

set_window_size :: inline (width: s32, height: s32) {
    glfwSetWindowSize(window.handle, width, height);
}

set_window_size_limits :: inline (min_width: s32, min_height: s32, max_width: s32, max_height: s32) {
    glfwSetWindowSizeLimits(window.handle, min_width, min_height, max_width, max_height);
}

set_window_aspect_ratio :: inline (numerator: s32, denominator: s32) {
    glfwSetWindowAspectRatio(window.handle, numerator, denominator);
}

#if !Disable_Render {
    set_window_icons :: (images: [] Image) {
        glfw_images := NewArray(images.count, GLFWimage, allocator = temp);
        for image: images {
            memcpy(*glfw_image[it_index], *image, size_of(GLFWimage));
        }
        glfwSetWindowIcon(window.handle, xx images.count, glfw_images.data);
    }

    create_mouse_cursor :: (cursor: Mouse_Cursor, image: Image, offset: Point2) {
        if cursors[cursor]  glfwDestroyCursor(cursors[cursor]);
        glfw_image: GLFWimage = ---;
        glfw_image.width  = image.width;
        glfw_image.height = image.height;
        glfw_image.pixels = image.data;
        cursors[cursor]   = glfwCreateCursor(*glfw_image, offset.x, offset.y);
    }
}

set_mouse_cursor :: (cursor := Mouse_Cursor.Arrow) {
    glfwSetCursor(window.handle, cursors[cursor]);
}

set_cursor_position_callback :: (callback: Cursor_Position_Callback) {
    window.callbacks.cursor_position = callback;
}

set_focus_callback :: (callback: Focus_Callback) {
    window.callbacks.focus = callback;
}

set_key_callback :: (callback: Key_Callback) {
    window.callbacks.key = callback;
}

set_mouse_callback :: (callback: Mouse_Callback) {
    window.callbacks.mouse = callback;
}

set_text_callback :: (callback: Text_Callback) {
    window.callbacks.text = callback;
}

set_scroll_callback :: (callback: Scroll_Callback) {
    window.callbacks.scroll = callback;
}

set_resize_callback :: (callback: Resize_Callback) {
    window.callbacks.resize = callback;
}

set_drop_callback :: (callback: Drop_Callback) {
    window.callbacks.drop = callback;
}

set_clear_color :: inline (color: Color) {
    default_pass_action.colors[0].value = color;
}

wait_for_events  :: glfwWaitEvents;
wait_for_events  :: glfwWaitEventsTimeout;
post_empty_event :: glfwPostEmptyEvent;

get_mouse_pos :: ($cached := false) -> Vector2 {
    #if cached {
        return mouse_pos;
    } else {
        x, y: float64;
        glfwGetCursorPos(window.handle, *x, *y);
        return .{cast(float) x, cast(float) y};
    }
}

get_clipboard :: () -> string {
    return to_string(glfwGetClipboardString(window.handle));
}

set_clipboard :: (s: string) {
    glfwSetClipboardString(window.handle, temp_c_string(s));
}

set_clipboard :: (s: *u8) {
    glfwSetClipboardString(window.handle, s);
}

#if OS == .WINDOWS {
    get_hwnd :: () -> HWND {
        return glfwGetWin32Window(window.handle);
    }
}

sf_time: struct {
    total:   float64;
    last:    float64;
    delta64: float64;
    delta:   float;
}

Mouse_Cursor :: enum {
    Arrow;
    IBeam;
    Crosshair;
    Hand;
    Resize_NS;
    Resize_EW;
    Resize_NESW;
    Resize_NWSE;
    Resize_All;
    Not_Allowed;

    Max_Cursors;
}

#scope_module

update_viewport :: (width: s32, height: s32) {
    if width == 0 && height == 0  return;
    window.size.x = xx width;
    window.size.y = xx height;
    window.size_i.x = width;
    window.size_i.y = height;
    // #if !Disable_Render  push_screen_size(width, height);
    #if Render_Backend == .D3D11  d3d11_resize_targets(width, height);
    if window.callbacks.resize != null  window.callbacks.resize(width, height);
}

initialized: bool;

TRACK_FPS_SAMPLES         :: 120;
TRACK_FPS_SAMPLE_DURATION :: 4.0;
TRACK_FPS_STEP            :: TRACK_FPS_SAMPLE_DURATION / TRACK_FPS_SAMPLES;

Cursor_Position_Callback :: #type (x: float64, y: float64);
Focus_Callback  :: #type (focused: bool);
Key_Callback    :: #type (key: Key, scancode: s32, action: Event_Action_Type, mods: Modifier);
Mouse_Callback  :: #type (button: Mouse, action: Event_Action_Type, mods: Modifier);
Text_Callback   :: #type (codepoint: u32);
Scroll_Callback :: #type (x_offset: float64, y_offset: float64);
Resize_Callback :: #type (width: s32, height: s32);
Drop_Callback   :: #type (count: s32, paths: **u8);

Window_Context :: struct {
    ctx:    Context;
    handle: *GLFWwindow;
    name:   string;

    focused: bool;
    size: Vector2;
    size_i: Point2;

    time: struct {
        vsync:          bool;
        target_fps:     float;
        target_fps_inv: float64;

        fps_buffer:   [TRACK_FPS_SAMPLES] float64;
        fps_last:     float64;
        fps_index:    int;
        fps_average:  float64;
    }

    callbacks: struct {
        cursor_position: Cursor_Position_Callback;
        focus:  Focus_Callback;
        key:    Key_Callback;
        mouse:  Mouse_Callback;
        text:   Text_Callback;
        scroll: Scroll_Callback;
        resize: Resize_Callback;
        drop:   Drop_Callback;
    }

    clear_color: Color = Colors.Black;
}
window: Window_Context;

#scope_file

cursors: [Mouse_Cursor.Max_Cursors] *GLFWcursor;

create_cursors :: (glfw_win: *GLFWwindow) {
    cursors[Mouse_Cursor.Arrow]       = glfwCreateStandardCursor(GLFW_ARROW_CURSOR);
    cursors[Mouse_Cursor.IBeam]       = glfwCreateStandardCursor(GLFW_IBEAM_CURSOR);
    cursors[Mouse_Cursor.Crosshair]   = glfwCreateStandardCursor(GLFW_CROSSHAIR_CURSOR);
    cursors[Mouse_Cursor.Hand]        = glfwCreateStandardCursor(GLFW_POINTING_HAND_CURSOR);
    cursors[Mouse_Cursor.Resize_NS]   = glfwCreateStandardCursor(GLFW_RESIZE_NS_CURSOR);
    cursors[Mouse_Cursor.Resize_EW]   = glfwCreateStandardCursor(GLFW_RESIZE_EW_CURSOR);
    #if GLFW_VERSION_MAJOR >= 3 && GLFW_VERSION_MINOR >= 4 {
        cursors[Mouse_Cursor.Resize_NESW] = glfwCreateStandardCursor(GLFW_RESIZE_NWSE_CURSOR);
        cursors[Mouse_Cursor.Resize_NWSE] = glfwCreateStandardCursor(GLFW_RESIZE_NESW_CURSOR);
        cursors[Mouse_Cursor.Resize_All]  = glfwCreateStandardCursor(GLFW_RESIZE_ALL_CURSOR);
        cursors[Mouse_Cursor.Not_Allowed] = glfwCreateStandardCursor(GLFW_NOT_ALLOWED_CURSOR);
    }
}

glfw_error_callback :: (error: s32, description: *u8) #c_call {
    push_context window.ctx {
        print("GLFW error %: %\n", error, to_string(description));
    }
}

glfw_cursor_position_callback :: (glfw_win: *GLFWwindow, x: float64, y: float64) #c_call {
    mouse_pos.x = xx x;
    mouse_pos.y = xx y;
    push_context window.ctx {
        if window.callbacks.cursor_position != null  window.callbacks.cursor_position(x, y);
    }
}

glfw_window_size_callback :: (handle: *GLFWwindow, width: s32, height: s32) #c_call {
    window.size.x = xx width;
    window.size.y = xx height;
    window.size_i.x = width;
    window.size_i.y = height;
    push_context window.ctx {
        update_viewport(width, height);
    }
}

glfw_window_focus_callback :: (handle: *GLFWwindow, focused: s32) #c_call {
    window.focused = focused >= 1;
    push_context window.ctx {
        if window.callbacks.focus != null  window.callbacks.focus(window.focused);
    }
}

glfw_key_callback :: (glfw_win: *GLFWwindow, key: s32, scancode: s32, action: s32, mods: s32) #c_call {
    if key < 0  return;
    #if !Disable_ImGui  ImGui_Impl_KeyCallback(key, scancode, action, mods);
    input_state.key_cur[key] = action != GLFW_RELEASE;
    push_context window.ctx {
        if window.callbacks.key != null  window.callbacks.key(xx,no_check key, scancode, xx,no_check action, xx,no_check mods);
    }
}

glfw_mouse_callback :: (glfw_win: *GLFWwindow, button: s32, action: s32, mods: s32) #c_call {
    #if !Disable_ImGui  ImGui_Impl_MouseCallback(button, action, mods);
    input_state.mouse_cur[button] = action != GLFW_RELEASE;
    push_context window.ctx {
        if window.callbacks.mouse != null  window.callbacks.mouse(xx,no_check button, xx,no_check action, xx,no_check mods);
    }
}

glfw_text_callback :: (glfw_win: *GLFWwindow, codepoint: u32) #c_call {
    #if !Disable_ImGui  ImGui_Impl_TextCallback(codepoint);
    push_context window.ctx {
        if window.callbacks.text != null  window.callbacks.text(codepoint);
    }
}

glfw_scroll_callback :: (glfw_win: *GLFWwindow, x_offset: float64, y_offset: float64) #c_call {
    #if !Disable_ImGui  ImGui_Impl_ScrollCallback(x_offset, y_offset);
    push_context window.ctx {
        if window.callbacks.scroll != null  window.callbacks.scroll(x_offset, y_offset);
    }
}

glfw_drop_callback :: (glfw_win: *GLFWwindow, count: s32, paths: **u8) #c_call {
    push_context window.ctx {
        if window.callbacks.drop != null  window.callbacks.drop(count, paths);
    }
}
