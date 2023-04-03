#module_parameters(
    Debug                := false,
    Default_Log_Level    := Log_Level.Info,
    Log_File_Paths       := false,
    Manually_Swap_Buffer := false,

    Disable_Render  := false,
    Disable_Audio   := false,
    Disable_ImGui   := false,
    Disable_SIMD    := false,
    Enable_Profiler := false,

    Debug_Render := false,
    Render_Backend: enum {
        GLCore33;
        D3D11;
        Metal;
    } = .GLCore33,
    Uniform_Size := 2,
    Batch_Optimizer_Depth := 8
);

#assert Uniform_Size >= 2 "Uniform_Size must be at least 2 units wide!";

SF_Result :: enum {
    Ok;

    Failed_To_Init_GLFW;
    Failed_To_Create_Window;

    Failed_To_Init_Miniaudio;
}

#import "Basic";
#import "Math";
#import "File";
#import "Hash";
#import "Hash_Table";
#import "Pool";
#import "Unicode";
#if OS == .WINDOWS {
    #import "Windows";
    #import "glfw" (GLFW_EXPOSE_NATIVE_WIN32 = true);
} else {
    #import "glfw";
}
#if OS != .WINDOWS && Render_Backend == .D3D11 {
    #assert false "Can't use D3D11 on this platform.";
}
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

#if !Disable_Render {
    #if OS == .WINDOWS && Render_Backend == .D3D11 {
        #import "d3d11";
        #import "dxgi";
        #load "render/d3d11.jai";
    }
    #load "render/texture.jai";
    #load "render/font.jai";
    #load "render/msdf.jai";
    #load "render/render.jai";
    // #load "render/shader.jai";
    #load "render/default_shaders.jai";
    #load "render/render_target.jai";
    // #load "render/bloom.jai";
    // #load "render/particles.jai";
    #load "render/camera.jai";
}

#if !Disable_Audio {
    #load "audio/audio.jai";
    #load "audio/sound.jai";
}

#if !Disable_ImGui {
    #load "imgui/imgui.jai";
    #load "imgui/profiler.jai";
}
