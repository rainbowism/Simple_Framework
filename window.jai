Module_Types :: enum_flags {
    Render;
    Audio;
    ImGui;

    All :: Module_Types.Render | .Audio | .ImGui;
}

Window_Flags :: enum_flags {
    None;
    Maximized;
    Fullscreen;
    Centered;
    VSync;
}

init :: () -> SF_Result {
    glfwSetErrorCallback(glfw_error_callback);
    if !glfwInit() {
        return .Failed_To_Init_GLFW;
    }
	// #if OS == .WINDOWS {
    //     Win32 :: #import "Windows";
    //     Win32.SetProcessDPIAware();
    //     Win32.timeBeginPeriod(1);
	// }
    window.ctx = context;
    initialized = true;
    return .Ok;
}

create_window :: (title: string, width: s32, height: s32, flags := Window_Flags.None, modules_to_init: Module_Types) -> SF_Result {
    glfwDefaultWindowHints();
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_VISIBLE, 0);

    window.size.x = xx width;
    window.size.y = xx height;
    window.size.width  = width;
    window.size.height = height;
    window.name = title;

    // @Todo(sushi): do settings file stuff so i can get fullscreen mode
	window.handle = glfwCreateWindow(width, height, temp_c_string(title), null, null);
	if window.handle == null {
		return .Failed_To_Create_Window;
	}
	glfwMakeContextCurrent(window.handle);
	gl_load(*gl, glfwGetProcAddress);

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
    glfwSetWindowSizeCallback (window.handle, glfw_window_size_callback);
    glfwSetWindowFocusCallback(window.handle, glfw_window_focus_callback);
	glfwSetKeyCallback        (window.handle, glfw_key_callback);
	glfwSetMouseButtonCallback(window.handle, glfw_mouse_callback);
	glfwSetCharCallback       (window.handle, glfw_text_callback);
	glfwSetScrollCallback     (window.handle, glfw_scroll_callback);
    glfwSetCursorPosCallback  (window.handle, glfw_cursor_position_callback);

    set_vsync(flags & .VSync > 0);

    glEnable(GL_BLEND);
    glEnable(GL_CULL_FACE);
    glEnable(GL_DEPTH_TEST);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glFrontFace(GL_CCW);

    glfwShowWindow(window.handle);
    init_time();

    #if !DISABLE_RENDER { if modules_to_init & .Render  render_init(); }
    #if !DISABLE_AUDIO  { if modules_to_init & .Audio   audio_init();  }
    #if !DISABLE_IMGUI  { if modules_to_init & .ImGui   imgui_init();  }

    update_viewport(width, height);

    time.last = get_time();

    return .Ok;
}

should_exit :: () -> bool {
    reset_temporary_storage();

    #if !MANUALLY_SWAP_BUFFER {
        {
            gpu_scoped_task("Present", Colors8.Red);
            glfwSwapBuffers(window.handle);
        }
    }
    glfwPollEvents();

    exit := glfwWindowShouldClose(window.handle) == GLFW_TRUE;

    if window.size.width != window.size.last_width || window.size.height != window.size.last_height {
        update_viewport(window.size.width, window.size.height);
        window.size.last_width  = window.size.width;
        window.size.last_height = window.size.height;
    }

    {
        new_time := get_time();
        time.delta64 = new_time - time.last;
        if time.delta64 > MAX_DELTA_TIME  time.delta64 = MAX_DELTA_TIME;

        if !window.time.vsync && window.time.target_fps > 0 && time.delta64 > 0 {
            gpu_scoped_task("WaitForFence", Colors8.Light_Salmon);

            remaining_time := window.time.target_fps_inv - time.delta64;
            if remaining_time > 0 {
                usleep(cast(s64) (1_000_000.0 * remaining_time), new_time + remaining_time);
                time.delta64 = get_time() - time.last;
                time.last = get_time();
            } else {
                time.last = new_time;
            }
        } else {
            time.last = new_time;
        }

        time.delta = cast(float) time.delta64;

        using window.time;
        if (new_time - fps_last) > TRACK_FPS_STEP {
            fps_last = new_time;
            fps_average -= fps_buffer[fps_index];
            fps_buffer[fps_index] = time.delta64 * (1.0 / TRACK_FPS_SAMPLES);
            fps_average += fps_buffer[fps_index];
            fps_index = (fps_index + 1) % TRACK_FPS_SAMPLES;
        }
    }
    gpu_end_frame();

    return exit;
}

swap_buffers :: inline () {
    glfwSwapBuffers(window.handle);
}

exit :: inline () {
    glfwSetWindowShouldClose(window.handle, GLFW_TRUE);
}

center_window :: () {
    window_pos: Point2 = ---;
    glfwGetWindowPos(window.handle, *window_pos.x, *window_pos.y);
    window_pos.x += window.size.width  / 2;
    window_pos.y += window.size.height / 2;
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
            monitor_rect.x + ((monitor_rect.width  - window.size.width)  / 2),
            monitor_rect.y + ((monitor_rect.height - window.size.height) / 2)
        );
        return;
    }
}

get_window_size :: inline () -> Vector2 {
    return make_vector2(xx window.size.width, xx window.size.height);
}

get_vsync :: () -> bool {
    return window.time.vsync;
}

set_vsync :: (enable: bool) {
    window.time.vsync = enable;
    if enable {
        glfwSwapInterval(1);
    } else {
        glfwSwapInterval(0);
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

get_window_focused :: () -> bool {
    return window.focused;
}

set_window_focused :: () {
    glfwFocusWindow(window.handle);
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

draw_clear :: inline (color: Color, $only_depth := false) {
    glClearColor(color.r, color.g, color.b, color.a);
    #if only_depth {
        glClear(GL_DEPTH_BUFFER_BIT);
    } else {
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    }
}

draw_clear :: (color: Color8, $only_depth := false) #expand {
    draw_clear(to_color(color), only_depth);
}

draw_clear :: ($only_depth := false) #expand {
    draw_clear(window.clear_color, only_depth);
}

set_clear_color :: inline (color: Color) {
    window.clear_color = color;
}

wait_for_events :: () #expand {
    glfwWaitEvents();
}

wait_for_events :: (time: float) #expand {
    glfwWaitEventsTimeout(time);
}

post_empty_event :: () #expand {
    glfwPostEmptyEvent();
}

time: struct {
    total:   float64;
    last:    float64;
    delta64: float64;
    delta:   float;
}

#scope_module

update_viewport :: (width: s32, height: s32) {
    glViewport(0, 0, xx width, xx height);
    window.size.x = xx width;
    window.size.y = xx height;
    window.size.width  = width;
    window.size.height = height;
    #if !DISABLE_RENDER  push_screen_size(width, height);
}

initialized: bool;

MAX_DELTA_TIME :: 0.25;

TRACK_FPS_SAMPLES         :: 120;
TRACK_FPS_SAMPLE_DURATION :: 4.0;
TRACK_FPS_STEP            :: TRACK_FPS_SAMPLE_DURATION / TRACK_FPS_SAMPLES;

Key_Callback    :: #type (key: s32, scancode: s32, action: s32, mods: s32);
Mouse_Callback  :: #type (button: s32, action: s32, mods: s32);
Text_Callback   :: #type (codepoint: u32);
Scroll_Callback :: #type (x_offset: float64, y_offset: float64);

Window_Context :: struct {
    ctx:    Context;
    handle: *GLFWwindow;
    name:   string;

    focused: bool;
    size: struct {
        using #as base: Vector2;
        width:       s32;
        height:      s32;
        last_width:  s32;
        last_height: s32;
    }

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
        key: Key_Callback;
        mouse: Mouse_Callback;
        text: Text_Callback;
        scroll: Scroll_Callback;
    }

    clear_color: Color = Colors.Black;
}
window: Window_Context;

#scope_file

glfw_error_callback :: (error: s32, description: *u8) #c_call {
    push_context window.ctx {
        print("GLFW error %: %\n", error, to_string(description));
    }
}

glfw_window_size_callback :: (handle: *GLFWwindow, width: s32, height: s32) #c_call {
    window.size.width  = width;
    window.size.height = height;
    push_context window.ctx {
        update_viewport(width, height);
    }
}

glfw_window_focus_callback :: (handle: *GLFWwindow, focused: s32) #c_call {
    window.focused = focused >= 1;
}

glfw_key_callback :: (glfw_win: *GLFWwindow, key: s32, scancode: s32, action: s32, mods: s32) #c_call {
    if key < 0  return;
	#if !DISABLE_IMGUI  ImGui_Impl_KeyCallback(key, scancode, action, mods);
    input_state.key_cur[key] = action != GLFW_RELEASE;
    push_context window.ctx {
        if window.callbacks.key != null  window.callbacks.key(key, scancode, action, mods);
	}
}

glfw_mouse_callback :: (glfw_win: *GLFWwindow, button: s32, action: s32, mods: s32) #c_call {
	#if !DISABLE_IMGUI  ImGui_Impl_MouseCallback(button, action, mods);
    input_state.mouse_cur[button] = action != GLFW_RELEASE;
    push_context window.ctx {
        if window.callbacks.mouse != null  window.callbacks.mouse(button, action, mods);
	}
}

glfw_text_callback :: (glfw_win: *GLFWwindow, codepoint: u32) #c_call {
    #if !DISABLE_IMGUI  ImGui_Impl_TextCallback(codepoint);
    push_context window.ctx {
        if window.callbacks.text != null  window.callbacks.text(codepoint);
	}
}

glfw_scroll_callback :: (glfw_win: *GLFWwindow, x_offset: float64, y_offset: float64) #c_call {
    #if !DISABLE_IMGUI  ImGui_Impl_ScrollCallback(x_offset, y_offset);
    push_context window.ctx {
        if window.callbacks.scroll != null  window.callbacks.scroll(x_offset, y_offset);
	}
}

glfw_cursor_position_callback :: (glfw_win: *GLFWwindow, x: float64, y: float64) #c_call {
    mouse_pos.x = xx x;
    mouse_pos.y = xx y;
}

#import "Basic";
#import "Math";
#import "GL";
#import "glfw";
