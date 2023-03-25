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
#import "Hash";
#import "Hash_Table";

#load "utils.jai";
#load "color.jai";
#load "window.jai";
#load "input.jai";
#load "profiler.jai";

#load "math/cephes.jai";
#load "math/transform.jai";
#load "math/utils.jai";
#load "math/matrix.jai";
#load "math/noise.jai";
#load "math/linalg.jai";

#load "math/collision/gjk.jai";
#load "math/collision/sat.jai";

#load "data/cache.jai";

#if !DISABLE_RENDER {
    #load "render/texture.jai";
    #load "render/font.jai";
    #load "render/msdf.jai";
    #load "render/render.jai";
    #load "render/shader.jai";
    #load "render/default_shader.jai";
    #load "render/render_layer.jai";
    #load "render/render_target.jai";
    #load "render/bloom.jai";
    #load "render/draw.jai";
    #load "render/particles.jai";
    #load "render/camera.jai";
}

#if !DISABLE_AUDIO {
    #load "audio/audio.jai";
    #load "audio/sound.jai";
}

#if !DISABLE_IMGUI {
    #load "imgui/imgui.jai";
    #load "imgui/profiler.jai";
}
