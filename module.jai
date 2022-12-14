#module_parameters(
    DEBUG                := false,
    LOG_LEVEL            := Log_Level.INFO,
    LOG_FILE_PATH        := false,
    MANUALLY_SWAP_BUFFER := false,

    DISABLE_RENDER  := false,
    DISABLE_AUDIO   := false,
    DISABLE_IMGUI   := false,
    DISABLE_SIMD    := false,
    ENABLE_PROFILER := false
);

SF_Result :: enum {
    Ok;

    Failed_To_Init_GLFW;
    Failed_To_Create_Window;

    Failed_To_Init_Miniaudio;
}

#import "Math";
#import "Math_Ext";

#load "utils.jai";
#load "color.jai";
#load "window.jai";
#load "input.jai";
#load "profiler.jai";

#load "math/linalg.jai";
#load "math/matrix.jai";
#load "math/noise.jai";

#if !DISABLE_RENDER {
    #load "2d/texture.jai";
    #load "2d/font.jai";
    #load "2d/msdf.jai";
    #load "2d/render.jai";
    #load "2d/shader.jai";
    #load "2d/default_shader.jai";
    #load "2d/render_layer.jai";
    #load "2d/render_target.jai";
    #load "2d/bloom.jai";
    #load "2d/draw.jai";
    #load "2d/particles.jai";
    #load "2d/camera.jai";
}

#if !DISABLE_AUDIO {
    #load "audio/audio.jai";
    #load "audio/sound.jai";
}

#if !DISABLE_IMGUI {
    #load "imgui/imgui.jai";
    #load "imgui/profiler.jai";
}
