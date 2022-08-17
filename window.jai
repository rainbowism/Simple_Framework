WindowFlags :: enum_flags {
    None;
    Maximized;
    Fullscreen;
    Centered;
    VSync;
    FpsInTitle;
}

init :: () -> SF_Result {
    glfwSetErrorCallback(glfw_error_callback);
    if !glfwInit() {
        return .FailedToInitGLFW;
    }
	#if OS == .WINDOWS {
        Win32 :: #import "Windows";
		Win32.SetProcessDPIAware();
        Win32.timeBeginPeriod(1);
	}

    initialized = true;
    return .Ok;
}

create_window :: (title: string, width: s32, height: s32, flags := WindowFlags.None) -> SF_Result {
    glfwDefaultWindowHints();
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_VISIBLE, 0);

    window.size.width  = width;
    window.size.height = height;
    window.name = title;

    // @Todo(sushi): do settings file stuff so i can get fullscreen mode
	window.handle = glfwCreateWindow(width, height, temp_c_string(title), null, null);
	if window.handle == null {
		return .FailedToCreateWindow;
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
    if flags & .FpsInTitle {
        window.time.fps_in_title = true;
    }

    glfwSetWindowSizeCallback(window.handle, glfw_window_size);
    glfwSetInputMode(window.handle, GLFW_STICKY_MOUSE_BUTTONS, GLFW_TRUE);
    glfwSetInputMode(window.handle, GLFW_STICKY_KEYS, GLFW_TRUE);

    set_vsync(flags & .VSync > 0);

    glViewport(0, 0, xx width, xx height);

    glEnable(GL_BLEND);
    glEnable(GL_CULL_FACE);
    glDisable(GL_DEPTH_TEST);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glFrontFace(GL_CCW);

    glfwShowWindow(window.handle);
    init_time();

    window.time.last = get_time();

    return .Ok;
}

should_exit :: () -> bool {
    reset_temporary_storage();
    glfwSwapBuffers(window.handle);
    glfwPollEvents();

    exit := glfwWindowShouldClose(window.handle) == GLFW_TRUE;

    if window.size.width != window.size.last_width || window.size.height != window.size.last_height {
        glViewport(0, 0, xx window.size.width, xx window.size.height);
        window.size.last_width  = window.size.width;
        window.size.last_height = window.size.height;
    }

    new_time := get_time();
    window.time.delta = new_time - window.time.last;
    {
        using window.time;
        if (new_time - fps_last) > TRACK_FPS_STEP {
            fps_last = new_time;
            fps_average -= fps_buffer[fps_index];
            fps_buffer[fps_index] = delta / TRACK_FPS_SAMPLES;
            fps_average += fps_buffer[fps_index];
            fps_index = (fps_index + 1) % TRACK_FPS_SAMPLES;

            if fps_in_title && (fps_index % 20) == 0{
                new_title := tprint("% | FPS:%\0", window.name, 1.0 / fps_average);
                glfwSetWindowTitle(window.handle, new_title.data);
            }
        }
    }

    if !window.time.vsync && window.time.target_fps > 0 && window.time.delta > 0 {
        desired_sleep_time := max(
            (1_000_000.0 / window.time.target_fps)
          - (window.time.delta * 1_000_000.0), 0.0
        );
        if desired_sleep_time > 0 {
            usleep(cast(s64) desired_sleep_time, new_time + (1.0 / window.time.target_fps));
        }
    }
    window.time.last = new_time;

    return exit;
}

exit :: () {
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
    window.time.target_fps = value;
}

get_window_mode :: () -> WindowFlags {
    if get_fullscreen() {
        return .Fullscreen;
    }
    // else if get_windowed_fullscreen() {
    //     return .WindowedFullscreen;
    // }
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

clear :: inline (color: Color) {
    glClearColor(color.r, color.g, color.b, color.a);
    glClear(GL_COLOR_BUFFER_BIT);
}

clear :: inline (color: Color8) {
    clear(to_color(color));
}

#scope_module

initialized: bool;

TRACK_FPS_SAMPLES         :: 120;
TRACK_FPS_SAMPLE_DURATION :: 4.0;
TRACK_FPS_STEP            :: TRACK_FPS_SAMPLE_DURATION / TRACK_FPS_SAMPLES;

window: struct {
    handle: *GLFWwindow;
    name:   string;

    size: struct {
        width:       s32;
        height:      s32;
        last_width:  s32;
        last_height: s32;
    }

    time: struct {
        total: float64;
        last:  float64;
        delta: float64;

        vsync:        bool;
        target_fps:   float;

        fps_in_title: bool;
        fps_buffer:   [TRACK_FPS_SAMPLES] float64;
        fps_last:     float64;
        fps_index:    int;
        fps_average:  float64;
    }
}

#scope_file

glfw_error_callback :: (error: s32, description: *u8) #c_call {
    new_context: Context;
    push_context new_context {
        print("GLFW error %: %\n", error, to_string(description));
    }
}

glfw_window_size :: (handle: *GLFWwindow, width: s32, height: s32) #c_call {
    window.size.width  = width;
    window.size.height = height;
}

#import "Basic";
#import "Math";
#import "GL";
#import "glfw";
